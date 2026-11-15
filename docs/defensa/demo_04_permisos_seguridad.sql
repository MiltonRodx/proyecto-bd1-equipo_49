-- ============================================================================
-- DEMO 4: PERMISOS Y SEGURIDAD (Etapa V - Tema 4)
-- Archivo: docs/defensa/demo_04_permisos_seguridad.sql
-- Ejecutar COMPLETO (F5). No modifica datos de negocio: es 100% re-ejecutable.
-- Requiere: DDL + DML + docs/etapa-05/04-seguridad/01_seguridad.sql ejecutado
--           (crea los roles rol_xmotors_* y los usuarios de prueba usr_xmotors_*).
--
-- QUÉ ES (para leer en voz alta):
--   El sistema de permisos define QUE puede hacer cada usuario sobre la base:
--   GRANT da permiso, DENY lo prohibe (y DENY gana siempre). Los permisos se
--   agrupan en ROLES por funcion, y el usuario los hereda al ser miembro.
--
-- QUÉ PROBLEMA RESUELVE EN X MOTORS:
--   Minimo privilegio: un consultor solo puede LEER (y no ve la auditoria ni
--   el historial de precios), y un vendedor NO puede escribir tablas a mano:
--   solo puede operar a traves de los procedimientos, donde estan las reglas.
-- ============================================================================

USE [X MOTORS];
GO

SET NOCOUNT ON;

-- Guarda: si no ejecutaste 01_seguridad.sql, avisar y cortar.
IF DATABASE_PRINCIPAL_ID('usr_xmotors_consulta') IS NULL
BEGIN
    PRINT 'Faltan usuarios: ejecuta primero docs/etapa-05/04-seguridad/01_seguridad.sql';
    RETURN;
END;
GO

-- Tabla para el resumen final (se llena DESPUES de REVERT: los usuarios
-- de prueba no escriben en tempdb; los valores viajan en variables).
IF OBJECT_ID('tempdb..#permisos') IS NOT NULL DROP TABLE #permisos;
CREATE TABLE #permisos (
    usuario         VARCHAR(30),
    select_venta    VARCHAR(4),
    select_auditoria VARCHAR(4),
    ejecutar_venta  VARCHAR(4)
);
GO

-- ============================================================================
-- BLOQUE ANTES: los tres roles y sus permisos (resumen)
-- ============================================================================
SELECT name AS rol_creado FROM sys.database_principals WHERE name LIKE 'rol_xmotors%';

DECLARE @select_venta    INT,
        @select_auditoria INT,
        @ejecutar_venta   INT;

-- ============================================================================
-- BLOQUE EJECUCION 1: CASO CONSULTOR (solo lectura).
-- EXECUTE AS USER simula ser otro usuario sin cerrar la conexion.
-- ============================================================================
EXECUTE AS USER = 'usr_xmotors_consulta';
SET @select_venta    = HAS_PERMS_BY_NAME('dbo.venta', 'OBJECT', 'SELECT');
SET @select_auditoria = HAS_PERMS_BY_NAME('dbo.auditoria_venta', 'OBJECT', 'SELECT');
SET @ejecutar_venta  = HAS_PERMS_BY_NAME('dbo.sp_RegistrarVentaCompleta', 'OBJECT', 'EXECUTE');
BEGIN TRY
    SELECT USER_NAME() AS soy_usuario;
    SELECT COUNT(*) AS consultor_lee_ventas FROM dbo.venta;                  -- OK (GRANT SELECT)
    SELECT TOP (1) * FROM dbo.auditoria_venta;                               -- DENY SELECT -> error 229
END TRY
BEGIN CATCH
    SELECT USER_NAME() AS soy_usuario, ERROR_NUMBER() AS error_229_esperado,
           ERROR_MESSAGE() AS mensaje;
END CATCH;
REVERT;
INSERT #permisos VALUES ('consulta', @select_venta, @select_auditoria, @ejecutar_venta);

EXECUTE AS USER = 'usr_xmotors_consulta';
DECLARE @cod INT;
BEGIN TRY
    EXEC dbo.sp_RegistrarVentaCompleta
         @dni_cliente = 42111222, @dni_vendedor = 31222333,
         @numero_chasis = '9C2HON00000000002', @metodo_pago = 'efectivo',
         @cod_venta = @cod OUTPUT;                                           -- DENY EXECUTE -> 229
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS error_229_esperado, ERROR_MESSAGE() AS mensaje;
END CATCH;
REVERT;

-- ============================================================================
-- BLOQUE EJECUCION 2: CASO VENDEDOR (escribe solo via procedimientos).
-- ============================================================================
EXECUTE AS USER = 'usr_xmotors_vendedor';
SET @select_venta    = HAS_PERMS_BY_NAME('dbo.venta', 'OBJECT', 'SELECT');
SET @select_auditoria = HAS_PERMS_BY_NAME('dbo.auditoria_venta', 'OBJECT', 'SELECT');
SET @ejecutar_venta  = HAS_PERMS_BY_NAME('dbo.sp_RegistrarVentaCompleta', 'OBJECT', 'EXECUTE');
BEGIN TRY
    INSERT INTO dbo.venta (fecha, metodo_pago, precio_venta_moto, monto_total,
                           estado, dni_cliente, dni_vendedor, numero_chasis)
    VALUES (CAST(GETDATE() AS DATE), 'efectivo', 1000.00, 1000.00,
            'efectuada', 42111222, 31222333, '9C2HON00000000002');           -- DENY INSERT -> 229
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS error_229_esperado, ERROR_MESSAGE() AS mensaje;
END CATCH;
REVERT;
INSERT #permisos VALUES ('vendedor', @select_venta, @select_auditoria, @ejecutar_venta);

EXECUTE AS USER = 'usr_xmotors_vendedor';
BEGIN TRY
    EXEC dbo.sp_cambiar_estado_venta @cod_venta = -1, @nuevo_estado = 'cancelada';
    -- Permiso de EJECUCION: OK. El negocio rechaza: error 50012 venta inexistente
    -- (usamos @cod_venta = -1 a proposito para no tocar datos reales).
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS error_50012_esperado, ERROR_MESSAGE() AS mensaje;
END CATCH;
REVERT;

EXECUTE AS USER = 'usr_xmotors_admin';
SET @select_venta    = HAS_PERMS_BY_NAME('dbo.venta', 'OBJECT', 'SELECT');
SET @select_auditoria = HAS_PERMS_BY_NAME('dbo.auditoria_venta', 'OBJECT', 'SELECT');
SET @ejecutar_venta  = HAS_PERMS_BY_NAME('dbo.sp_RegistrarVentaCompleta', 'OBJECT', 'EXECUTE');
REVERT;
INSERT #permisos VALUES ('admin', @select_venta, @select_auditoria, @ejecutar_venta);

-- ============================================================================
-- BLOQUE DESPUES: resumen de permisos (medidos EN CADA USUARIO):
--   consulta : lee venta, NO ve auditoria, NO ejecuta el SP de ventas
--   vendedor : lee venta, NO ve auditoria, SI ejecuta el SP de ventas
--   admin    : todo (GRANT de esquema completo)
-- ============================================================================
SELECT usuario,
       CAST(select_venta AS VARCHAR(4))     AS select_venta,
       CAST(select_auditoria AS VARCHAR(4)) AS select_auditoria,
       CAST(ejecutar_venta AS VARCHAR(4))   AS ejecutar_venta
FROM #permisos;
GO

PRINT 'DEMO 4 terminado: sin datos sucios. Se puede volver a ejecutar.';
GO
