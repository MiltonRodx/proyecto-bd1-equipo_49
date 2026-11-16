-- ============================================================================
-- DEMO 4: PERMISOS Y SEGURIDAD (X Motors)
-- COMO EJECUTAR EN DBEAVER: Ctrl+A (seleccionar todo) y Ctrl+Enter.
-- NO usar Alt+X: corta el script en pedazos y las variables se pierden.
-- No deja datos sucios: los intentos de escritura van dentro de una
-- transaccion con ROLLBACK. Es re-ejecutable.
-- Requiere: DDL + DML + docs/etapa-05/04-seguridad/01_seguridad.sql ejecutado
--           (crea los roles rol_xmotors_* y los usuarios usr_xmotors_*).
--
-- QUE ES (leer en voz alta):
--   El sistema de permisos define QUE puede hacer cada usuario sobre la base:
--   GRANT da permiso, DENY lo prohibe (y DENY gana siempre). Los permisos se
--   agrupan en ROLES por funcion, y el usuario los hereda al ser miembro.
--
-- QUE PROBLEMA RESUELVE EN X MOTORS (leer en voz alta):
--   Minimo privilegio: un consultor solo puede LEER (y no ve la auditoria ni
--   el historial de precios), y un vendedor NO puede escribir tablas a mano:
--   solo puede operar a traves de los procedimientos, donde estan las reglas.
--
-- RESULTADOS (pestañas, en orden):
--   1 roles y sus miembros | 2 intentos de cada usuario (permitido / DENY)
--   3 matriz de permisos   | 4 estado final (vuelvo a ser yo, 0 transacciones)
--
-- EXECUTE AS USER = simula ser otro usuario sin cerrar la conexion.
-- REVERT          = vuelvo a ser yo.
-- ============================================================================

USE [X MOTORS];

SET NOCOUNT ON;

-- Guarda: si no ejecutaste 01_seguridad.sql, avisar y cortar.
IF DATABASE_PRINCIPAL_ID('usr_xmotors_consulta') IS NULL
   OR DATABASE_PRINCIPAL_ID('usr_xmotors_vendedor') IS NULL
   OR DATABASE_PRINCIPAL_ID('usr_xmotors_admin') IS NULL
BEGIN
    SELECT 'Faltan usuarios de prueba: ejecuta primero docs/etapa-05/04-seguridad/01_seguridad.sql' AS aviso;
    RETURN;
END;

DECLARE @sv  INT;            -- permiso SELECT sobre venta
DECLARE @sa  INT;            -- permiso SELECT sobre auditoria_venta
DECLARE @ev  INT;            -- permiso EXECUTE sobre sp_RegistrarVentaCompleta
DECLARE @n   INT;
DECLARE @cod INT;
DECLARE @err INT;
DECLARE @msg NVARCHAR(300);

-- Tablas para los resumenes. Se llenan DESPUES de REVERT: los usuarios de
-- prueba no escriben en tempdb, asi que los valores viajan en variables.
IF OBJECT_ID('tempdb..#permisos') IS NOT NULL DROP TABLE #permisos;
IF OBJECT_ID('tempdb..#intentos') IS NOT NULL DROP TABLE #intentos;

CREATE TABLE #permisos (
    orden            INT IDENTITY(1,1),
    usuario          VARCHAR(30),
    select_venta     INT,
    select_auditoria INT,
    ejecutar_venta   INT
);
CREATE TABLE #intentos (
    orden     INT IDENTITY(1,1),
    usuario   VARCHAR(30),
    intento   VARCHAR(70),
    esperado  VARCHAR(60),
    error_num INT,
    mensaje   NVARCHAR(300)
);

BEGIN TRY

    -- ========================================================================
    -- 1. ANTES: los roles creados y que usuario es miembro de cada uno
    -- ========================================================================
    SELECT '1. ROLES Y MIEMBROS' AS paso,
           r.name AS rol,
           m.name AS usuario_miembro
    FROM sys.database_principals r
    LEFT JOIN sys.database_role_members rm ON rm.role_principal_id = r.principal_id
    LEFT JOIN sys.database_principals  m  ON m.principal_id = rm.member_principal_id
    WHERE r.type = 'R' AND r.name LIKE 'rol_xmotors%'
    ORDER BY r.name;

    -- ========================================================================
    -- 2. CASO CONSULTOR (solo lectura)
    -- ========================================================================

    -- 2a. Lee ventas -> permitido (GRANT SELECT)
    SET @err = NULL;  SET @msg = N'OK (permitido)';
    EXECUTE AS USER = 'usr_xmotors_consulta';
    BEGIN TRY
        SELECT @n = COUNT(*) FROM dbo.venta;
        SET @msg = N'OK: ve ' + CAST(@n AS NVARCHAR(10)) + N' ventas';
    END TRY
    BEGIN CATCH
        SET @err = ERROR_NUMBER();  SET @msg = LEFT(ERROR_MESSAGE(), 300);
    END CATCH;
    REVERT;
    INSERT #intentos (usuario, intento, esperado, error_num, mensaje)
    VALUES ('consulta', 'SELECT sobre venta', 'permitido', @err, @msg);

    -- 2b. Lee la auditoria -> DENY SELECT (error 229)
    SET @err = NULL;  SET @msg = N'OK (permitido)';
    EXECUTE AS USER = 'usr_xmotors_consulta';
    BEGIN TRY
        SELECT @n = COUNT(*) FROM dbo.auditoria_venta;
    END TRY
    BEGIN CATCH
        SET @err = ERROR_NUMBER();  SET @msg = LEFT(ERROR_MESSAGE(), 300);
    END CATCH;
    REVERT;
    INSERT #intentos (usuario, intento, esperado, error_num, mensaje)
    VALUES ('consulta', 'SELECT sobre auditoria_venta', 'DENY -> error 229', @err, @msg);

    -- 2c. Ejecuta el SP de ventas -> DENY EXECUTE (error 229)
    --     (transaccion de resguardo: si por error se permitiera, no queda nada)
    SET @err = NULL;  SET @msg = N'OK (permitido)';
    EXECUTE AS USER = 'usr_xmotors_consulta';
    BEGIN TRY
        BEGIN TRANSACTION;
        EXEC dbo.sp_RegistrarVentaCompleta
             @dni_cliente = 42111222, @dni_vendedor = 31222333,
             @numero_chasis = '9C2HON00000000002', @metodo_pago = 'efectivo',
             @cod_venta = @cod OUTPUT;
        ROLLBACK TRANSACTION;
    END TRY
    BEGIN CATCH
        SET @err = ERROR_NUMBER();  SET @msg = LEFT(ERROR_MESSAGE(), 300);
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    END CATCH;
    REVERT;
    INSERT #intentos (usuario, intento, esperado, error_num, mensaje)
    VALUES ('consulta', 'EXEC sp_RegistrarVentaCompleta', 'DENY -> error 229', @err, @msg);

    -- Permisos medidos EN el consultor
    EXECUTE AS USER = 'usr_xmotors_consulta';
    SET @sv = HAS_PERMS_BY_NAME('dbo.venta', 'OBJECT', 'SELECT');
    SET @sa = HAS_PERMS_BY_NAME('dbo.auditoria_venta', 'OBJECT', 'SELECT');
    SET @ev = HAS_PERMS_BY_NAME('dbo.sp_RegistrarVentaCompleta', 'OBJECT', 'EXECUTE');
    REVERT;
    INSERT #permisos (usuario, select_venta, select_auditoria, ejecutar_venta)
    VALUES ('consulta', @sv, @sa, @ev);

    -- ========================================================================
    -- 3. CASO VENDEDOR (escribe solo via procedimientos)
    -- ========================================================================

    -- 3a. INSERT directo en venta -> DENY INSERT (error 229)
    --     (transaccion de resguardo: si por error se permitiera, no queda nada)
    SET @err = NULL;  SET @msg = N'OK (permitido)';
    EXECUTE AS USER = 'usr_xmotors_vendedor';
    BEGIN TRY
        BEGIN TRANSACTION;
        INSERT INTO dbo.venta (fecha, metodo_pago, precio_venta_moto, monto_total,
                               estado, dni_cliente, dni_vendedor, numero_chasis)
        VALUES (CAST(GETDATE() AS DATE), 'efectivo', 1000.00, 1000.00,
                'efectuada', 42111222, 31222333, '9C2HON00000000002');
        ROLLBACK TRANSACTION;
    END TRY
    BEGIN CATCH
        SET @err = ERROR_NUMBER();  SET @msg = LEFT(ERROR_MESSAGE(), 300);
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    END CATCH;
    REVERT;
    INSERT #intentos (usuario, intento, esperado, error_num, mensaje)
    VALUES ('vendedor', 'INSERT directo en venta', 'DENY -> error 229', @err, @msg);

    -- 3b. EXEC de un SP -> el permiso esta OK; el NEGOCIO rechaza (50012).
    --     Uso @cod_venta = -1 a proposito para no tocar datos reales.
    SET @err = NULL;  SET @msg = N'OK (permitido)';
    EXECUTE AS USER = 'usr_xmotors_vendedor';
    BEGIN TRY
        EXEC dbo.sp_cambiar_estado_venta @cod_venta = -1, @nuevo_estado = 'cancelada';
    END TRY
    BEGIN CATCH
        SET @err = ERROR_NUMBER();  SET @msg = LEFT(ERROR_MESSAGE(), 300);
    END CATCH;
    REVERT;
    INSERT #intentos (usuario, intento, esperado, error_num, mensaje)
    VALUES ('vendedor', 'EXEC sp_cambiar_estado_venta (venta -1)',
            'permiso OK; negocio rechaza 50012', @err, @msg);

    -- Permisos medidos EN el vendedor
    EXECUTE AS USER = 'usr_xmotors_vendedor';
    SET @sv = HAS_PERMS_BY_NAME('dbo.venta', 'OBJECT', 'SELECT');
    SET @sa = HAS_PERMS_BY_NAME('dbo.auditoria_venta', 'OBJECT', 'SELECT');
    SET @ev = HAS_PERMS_BY_NAME('dbo.sp_RegistrarVentaCompleta', 'OBJECT', 'EXECUTE');
    REVERT;
    INSERT #permisos (usuario, select_venta, select_auditoria, ejecutar_venta)
    VALUES ('vendedor', @sv, @sa, @ev);

    -- ========================================================================
    -- 4. ADMIN: permisos medidos EN el admin (GRANT de esquema completo)
    -- ========================================================================
    EXECUTE AS USER = 'usr_xmotors_admin';
    SET @sv = HAS_PERMS_BY_NAME('dbo.venta', 'OBJECT', 'SELECT');
    SET @sa = HAS_PERMS_BY_NAME('dbo.auditoria_venta', 'OBJECT', 'SELECT');
    SET @ev = HAS_PERMS_BY_NAME('dbo.sp_RegistrarVentaCompleta', 'OBJECT', 'EXECUTE');
    REVERT;
    INSERT #permisos (usuario, select_venta, select_auditoria, ejecutar_venta)
    VALUES ('admin', @sv, @sa, @ev);

    -- ========================================================================
    -- DESPUES: resultados para leer de corrido en la defensa
    -- ========================================================================
    SELECT '2. INTENTOS' AS paso, usuario, intento, esperado, error_num, mensaje
    FROM #intentos
    ORDER BY orden;

    -- Esperado:
    --   consulta : lee venta SI | ve auditoria NO | ejecuta SP de ventas NO
    --   vendedor : lee venta SI | ve auditoria NO | ejecuta SP de ventas SI
    --   admin    : todo SI
    SELECT '3. MATRIZ DE PERMISOS' AS paso, usuario,
           CASE WHEN select_venta     = 1 THEN 'SI' ELSE 'NO' END AS lee_venta,
           CASE WHEN select_auditoria = 1 THEN 'SI' ELSE 'NO' END AS ve_auditoria,
           CASE WHEN ejecutar_venta   = 1 THEN 'SI' ELSE 'NO' END AS ejecuta_sp_ventas
    FROM #permisos
    ORDER BY orden;

    DROP TABLE #permisos;
    DROP TABLE #intentos;

END TRY
BEGIN CATCH
    -- Proteccion: si algo fallo con un usuario "puesto", volver a ser yo.
    REVERT;
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;

SELECT '4. ESTADO FINAL' AS paso,
       USER_NAME() AS usuario_actual,
       @@TRANCOUNT AS transacciones_abiertas;