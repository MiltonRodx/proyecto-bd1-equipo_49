-- =====================================================================
-- X Motors - Etapa V - Tema 4: Seguridad (permisos de usuarios y roles)
-- Archivo: docs/etapa-05/04-seguridad/02_seguridad_logins_reales.sql
--
-- Objetivo: reproducir la demo del profesor de la consigna v2 con
--           LOGINS REALES (efimeros) sobre el modelo X Motors:
--
--   Parte 1 - Permisos a nivel de usuarios:
--     Prueba 1: INSERT directo en venta por usuario admin  -> OK
--     Prueba 2: INSERT directo en venta por usuario lector -> denegado (229)
--     Prueba 3: INSERT via procedimiento simple por lector -> OK (ownership chaining)
--   Parte 2 - Permisos a nivel de roles:
--     Prueba 4: SELECT modelo_motocicleta con rol    -> OK
--     Prueba 5: SELECT modelo_motocicleta sin rol    -> denegado (229)
--
-- Notas de diseno (IMPORTANTES):
--   1. Los logins/usuarios/rol de esta demo son DE PRUEBA y EFIMEROS:
--      se crean y se destruyen dentro de este mismo script. Las
--      contrasenas son placeholders de demo (nunca credenciales reales
--      ni de produccion), igual que en la consigna del profesor.
--      El modelo permanente de seguridad sigue siendo 01_seguridad.sql
--      (roles + usuarios WITHOUT LOGIN) para que el script sea
--      reproducible sin permisos de sysadmin.
--   2. Se usa un SP simple espejo para la Prueba 3 (sp_demo_insert_venta_simple,
--      con INSERT directo, sin SQL dinamico), igual al caso del profesor.
--      El SP real sp_RegistrarVentaCompleta hace el INSERT de venta via
--      sp_executesql y el ownership chaining NO cruza lotes dinamicos (ver
--      observacion honesta en investigacion.md): ese limite se documenta,
--      no se fuerza.
--   3. El INSERT permanente de la Prueba 3 queda solo temporalmente:
--      al final del script se ELIMINAN las filas demo de venta para
--      restaurar el lote de Etapa III. Las filas de auditoria_venta
--      quedan como evidencia (no se borran, convencion de la etapa).
--   4. Role de consulta temporario en Parte 2 para no tocar los roles
--      permanentes de 01_seguridad.sql (rol_xmotors_*).
--   5. Las pruebas se ejecutan con EXECUTE AS LOGIN (no AS USER): se
--      suplanta al login real, que es lo que hace una conexion de verdad.
--      Para mostrarlo en vivo tambien se puede abrir una conexion con
--      sqlcmd -S localhost -U usr_demo_xmotors_lector -P ... -C (en ese
--      caso hay que cerrarla antes de que el script haga DROP LOGIN).
--   6. Cada prueba guarda su resultado REAL (numero de error o OK) en la
--      tabla temporal #resultados; el resumen final compara esperado vs
--      obtenido. Asi un error ajeno a los permisos (por ejemplo, las
--      opciones SET del indice filtrado, error 1934) no se confunde con
--      una denegacion.
--   7. Se fijan las opciones SET que exige el indice filtrado
--      ux_venta_chasis_vigente antes de cualquier INSERT/DELETE en venta.
-- =====================================================================

USE [X MOTORS];
GO

SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;
GO

-- Resultados de las pruebas (tabla temporal de sesion; sobrevive a los GO).
IF OBJECT_ID('tempdb..#resultados') IS NOT NULL
    DROP TABLE #resultados;

CREATE TABLE #resultados (
    prueba      INT          NOT NULL,
    descripcion VARCHAR(80)  NOT NULL,
    usuario     VARCHAR(40)  NOT NULL,
    esperado    VARCHAR(10)  NOT NULL,   -- 'OK' o el numero de error esperado
    obtenido    VARCHAR(10)  NOT NULL
);
GO

-- -------------------------------------------------------------------
-- 0. Limpieza previa (idempotencia): objetos de una corrida anterior
-- -------------------------------------------------------------------
-- El chasis YAMMT03002 (modelo 12, stock 2) queda reservado para la
-- demo de seguridad y sin ventas en el lote del DML.
DELETE FROM dbo.venta WHERE numero_chasis = 'YAMMT03002';

IF OBJECT_ID('dbo.sp_demo_insert_venta_simple', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_demo_insert_venta_simple;
GO

IF DATABASE_PRINCIPAL_ID('usr_demo_xmotors_lector') IS NOT NULL
    DROP USER usr_demo_xmotors_lector;
IF DATABASE_PRINCIPAL_ID('usr_demo_xmotors_admin') IS NOT NULL
    DROP USER usr_demo_xmotors_admin;
IF DATABASE_PRINCIPAL_ID('usr_demo_xmotors_rol') IS NOT NULL
    DROP USER usr_demo_xmotors_rol;
IF DATABASE_PRINCIPAL_ID('usr_demo_xmotors_norol') IS NOT NULL
    DROP USER usr_demo_xmotors_norol;

-- El rol se dropea despues de sus miembros (los usuarios de arriba).
IF DATABASE_PRINCIPAL_ID('rol_demo_consulta_modelos') IS NOT NULL
    DROP ROLE rol_demo_consulta_modelos;
GO

IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'usr_demo_xmotors_admin')
    DROP LOGIN usr_demo_xmotors_admin;
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'usr_demo_xmotors_lector')
    DROP LOGIN usr_demo_xmotors_lector;
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'usr_demo_xmotors_rol')
    DROP LOGIN usr_demo_xmotors_rol;
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'usr_demo_xmotors_norol')
    DROP LOGIN usr_demo_xmotors_norol;
GO

-- ===================================================================
-- PARTE 1: PERMISOS A NIVEL DE USUARIOS
-- ===================================================================
PRINT '==================================================';
PRINT 'PARTE 1 - PERMISOS A NIVEL DE USUARIOS';
PRINT '==================================================';

-- -------------------------------------------------------------------
-- 1.1 Creacion de logins (servidor) y usuarios (base de datos)
--     LOGIN: identidad para conectarse al servidor.
--     USER : identidad dentro de X MOTORS, mapeada a un login.
-- -------------------------------------------------------------------
CREATE LOGIN usr_demo_xmotors_admin
    WITH PASSWORD = 'DemoAdmin123*', CHECK_POLICY = OFF;
CREATE LOGIN usr_demo_xmotors_lector
    WITH PASSWORD = 'DemoLector123*', CHECK_POLICY = OFF;
GO

CREATE USER usr_demo_xmotors_admin
    FOR LOGIN usr_demo_xmotors_admin;
CREATE USER usr_demo_xmotors_lector
    FOR LOGIN usr_demo_xmotors_lector;
GO

-- -------------------------------------------------------------------
-- 1.2 Asignacion de permisos
-- -------------------------------------------------------------------
-- Usuario administrador: rol fijo db_owner
ALTER ROLE db_owner
    ADD MEMBER usr_demo_xmotors_admin;
GO

-- Usuario con permisos limitados: lectura de venta
GRANT SELECT
    ON OBJECT::dbo.venta
    TO usr_demo_xmotors_lector;
GO

-- -------------------------------------------------------------------
-- 1.3 Procedimiento demo simple (sin SQL dinamico) para la Prueba 3.
--     Espejo del dbo.sp_RegistrarVentaSimple del ejemplo del profesor.
--     Usa un chasis de prueba reservado de Etapa V (YAMMT03002).
-- -------------------------------------------------------------------
CREATE PROCEDURE dbo.sp_demo_insert_venta_simple
    @fecha         DATE,
    @metodo        VARCHAR(50),
    @monto         DECIMAL(12,2),
    @chasis        VARCHAR(100),
    @dni_cliente   INT,
    @dni_vendedor  INT
AS
BEGIN
    SET NOCOUNT ON;

    -- Opciones requeridas por el indice filtrado ux_venta_chasis_vigente
    -- (no dependen de como venga configurada la sesion que llama).
    SET ANSI_PADDING ON;
    SET ANSI_WARNINGS ON;
    SET ARITHABORT ON;
    SET CONCAT_NULL_YIELDS_NULL ON;
    SET NUMERIC_ROUNDABORT OFF;

    INSERT INTO dbo.venta
        (fecha, metodo_pago, precio_venta_moto, monto_total, estado,
         dni_cliente, dni_vendedor, numero_chasis)
    VALUES
        (@fecha, @metodo, @monto, @monto, 'efectuada',
         @dni_cliente, @dni_vendedor, @chasis);
END
GO

-- -------------------------------------------------------------------
-- 1.4 Permiso de ejecucion sobre el procedimiento demo simple
-- -------------------------------------------------------------------
GRANT EXECUTE
    ON OBJECT::dbo.sp_demo_insert_venta_simple
    TO usr_demo_xmotors_lector;
GO

-- ===================================================================
-- PRUEBA 1: INSERT directo sobre venta con usuario ADMINISTRADOR
-- Esperado: operacion exitosa (se hace dentro de TRAN + ROLLBACK para
-- no confirmar filas demo en el lote real de Etapa III).
-- ===================================================================
PRINT '';
PRINT 'PRUEBA 1 - INSERT directo sobre venta con usuario_admin';
PRINT 'Resultado esperado: operacion exitosa';

DECLARE @err INT = NULL;

EXECUTE AS LOGIN = 'usr_demo_xmotors_admin';
BEGIN TRY
    BEGIN TRANSACTION;
    INSERT INTO dbo.venta
        (fecha, metodo_pago, precio_venta_moto, monto_total, estado,
         dni_cliente, dni_vendedor, numero_chasis)
    VALUES
        (CAST(SYSDATETIME() AS DATE), 'efectivo', 15000000.00, 15000000.00,
         'efectuada', 30456781, 31222333, 'YAMMT03002');
    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    SET @err = ERROR_NUMBER();
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
END CATCH;
REVERT;

-- Se registra DESPUES del REVERT: los usuarios de prueba no tienen por
-- que poder escribir en tempdb.
INSERT INTO #resultados
VALUES (1, 'INSERT directo en venta', 'admin (db_owner)', 'OK',
        COALESCE(CAST(@err AS VARCHAR(10)), 'OK'));
GO

-- ===================================================================
-- PRUEBA 2: INSERT directo sobre venta con usuario LECTOR
-- Esperado: denegado por falta de permisos (229)
-- ===================================================================
PRINT '';
PRINT 'PRUEBA 2 - INSERT directo sobre venta con usuario_lector';
PRINT 'Resultado esperado: denegado por falta de permisos (error 229)';

DECLARE @err INT = NULL;

EXECUTE AS LOGIN = 'usr_demo_xmotors_lector';
BEGIN TRY
    INSERT INTO dbo.venta
        (fecha, metodo_pago, precio_venta_moto, monto_total, estado,
         dni_cliente, dni_vendedor, numero_chasis)
    VALUES
        (CAST(SYSDATETIME() AS DATE), 'efectivo', 15000000.00, 15000000.00,
         'efectuada', 30456781, 31222333, 'YAMMT03002');
END TRY
BEGIN CATCH
    SET @err = ERROR_NUMBER();
END CATCH;
REVERT;

INSERT INTO #resultados
VALUES (2, 'INSERT directo en venta', 'lector', '229',
        COALESCE(CAST(@err AS VARCHAR(10)), 'OK'));
GO

-- ===================================================================
-- PRUEBA 3: INSERT via PROCEDIMIENTO con usuario LECTOR
-- Esperado: exito por GRANT EXECUTE + ownership chaining
-- (sin SQL dinamico: el INSERT es del propietario dbo del SP).
-- ===================================================================
PRINT '';
PRINT 'PRUEBA 3 - EXEC dbo.sp_demo_insert_venta_simple con usuario_lector';
PRINT 'Resultado esperado: exito por GRANT EXECUTE (ownership chaining)';

DECLARE @err INT = NULL;
DECLARE @hoy DATE = CAST(SYSDATETIME() AS DATE);

EXECUTE AS LOGIN = 'usr_demo_xmotors_lector';
BEGIN TRY
    EXEC dbo.sp_demo_insert_venta_simple
        @fecha        = @hoy,
        @metodo       = 'efectivo',
        @monto        = 15000000.00,
        @chasis       = 'YAMMT03002',
        @dni_cliente  = 30456781,
        @dni_vendedor = 31222333;
END TRY
BEGIN CATCH
    SET @err = ERROR_NUMBER();
END CATCH;
REVERT;

INSERT INTO #resultados
VALUES (3, 'EXEC SP demo (INSERT en venta)', 'lector', 'OK',
        COALESCE(CAST(@err AS VARCHAR(10)), 'OK'));
GO

-- ===================================================================
-- PARTE 2: PERMISOS A NIVEL DE ROLES
-- ===================================================================
PRINT '';
PRINT '==================================================';
PRINT 'PARTE 2 - PERMISOS A NIVEL DE ROLES';
PRINT '==================================================';

CREATE LOGIN usr_demo_xmotors_rol
    WITH PASSWORD = 'DemoRol1*', CHECK_POLICY = OFF;
CREATE LOGIN usr_demo_xmotors_norol
    WITH PASSWORD = 'DemoRol2*', CHECK_POLICY = OFF;
GO

CREATE USER usr_demo_xmotors_rol
    FOR LOGIN usr_demo_xmotors_rol;
CREATE USER usr_demo_xmotors_norol
    FOR LOGIN usr_demo_xmotors_norol;
GO

CREATE ROLE rol_demo_consulta_modelos;
GO

GRANT SELECT
    ON OBJECT::dbo.modelo_motocicleta
    TO rol_demo_consulta_modelos;
GO

ALTER ROLE rol_demo_consulta_modelos
    ADD MEMBER usr_demo_xmotors_rol;
GO

-- ===================================================================
-- PRUEBA 4: SELECT modelo_motocicleta con USUARIO CON ROL
-- Esperado: consulta exitosa
-- ===================================================================
PRINT '';
PRINT 'PRUEBA 4 - SELECT modelo_motocicleta con usuario con rol';
PRINT 'Resultado esperado: consulta exitosa';

DECLARE @err INT = NULL;

EXECUTE AS LOGIN = 'usr_demo_xmotors_rol';
BEGIN TRY
    SELECT TOP (2)
        id_modelo,
        CAST(nombre_modelo AS VARCHAR(60)) AS nombre_modelo,
        precio_lista
    FROM dbo.modelo_motocicleta
    ORDER BY id_modelo;
END TRY
BEGIN CATCH
    SET @err = ERROR_NUMBER();
END CATCH;
REVERT;

INSERT INTO #resultados
VALUES (4, 'SELECT modelo_motocicleta', 'con rol', 'OK',
        COALESCE(CAST(@err AS VARCHAR(10)), 'OK'));
GO

-- ===================================================================
-- PRUEBA 5: SELECT modelo_motocicleta con USUARIO SIN ROL
-- Esperado: denegado por falta de permisos (229)
-- ===================================================================
PRINT '';
PRINT 'PRUEBA 5 - SELECT modelo_motocicleta con usuario sin rol';
PRINT 'Resultado esperado: denegado por falta de permisos (error 229)';

DECLARE @err INT = NULL;

EXECUTE AS LOGIN = 'usr_demo_xmotors_norol';
BEGIN TRY
    SELECT TOP (2)
        id_modelo,
        CAST(nombre_modelo AS VARCHAR(60)) AS nombre_modelo,
        precio_lista
    FROM dbo.modelo_motocicleta
    ORDER BY id_modelo;
END TRY
BEGIN CATCH
    SET @err = ERROR_NUMBER();
END CATCH;
REVERT;

INSERT INTO #resultados
VALUES (5, 'SELECT modelo_motocicleta', 'sin rol', '229',
        COALESCE(CAST(@err AS VARCHAR(10)), 'OK'));
GO

-- ===================================================================
-- RESUMEN: esperado vs obtenido (valores reales de cada prueba)
-- Si 'obtenido' muestra un numero distinto del esperado (por ejemplo
-- 1934), el problema no es de permisos: revisar las opciones SET.
-- ===================================================================
PRINT '';
PRINT '==================================================';
PRINT 'RESUMEN - TABLA DE PRUEBAS (resultado esperado vs obtenido)';
PRINT '==================================================';

SELECT
    prueba,
    descripcion,
    usuario,
    esperado,
    obtenido,
    CASE WHEN esperado = obtenido THEN 'OK' ELSE 'FALLA' END AS resultado
FROM #resultados
ORDER BY prueba;
GO

-- ===================================================================
-- LIMPIEZA: se destruye todo lo creado por esta demo
-- -------------------------------------------------------------------
-- 1. Se eliminan las filas demo confirmadas por la Prueba 3 (el chasis
--    YAMMT03002 queda reservado para pruebas y sin ventas del lote DML).
-- 2. NO se borra auditoria_venta: queda como evidencia (INSERT/DELETE).
--    Las filas generadas por el INSERT via SP y su DELETE quedan en
--    auditoria_venta; es la constancia de la demo.
-- 3. Se dropean SP, usuarios, rol y logins (usuarios antes que el rol).
-- ===================================================================
DELETE FROM dbo.venta
WHERE numero_chasis = 'YAMMT03002';
GO

DROP PROCEDURE dbo.sp_demo_insert_venta_simple;

DROP USER usr_demo_xmotors_lector;
DROP USER usr_demo_xmotors_admin;
DROP USER usr_demo_xmotors_rol;
DROP USER usr_demo_xmotors_norol;

DROP ROLE rol_demo_consulta_modelos;
GO

DROP LOGIN usr_demo_xmotors_admin;
DROP LOGIN usr_demo_xmotors_lector;
DROP LOGIN usr_demo_xmotors_rol;
DROP LOGIN usr_demo_xmotors_norol;
GO

SELECT
    DB_NAME() AS base_final,
    (SELECT COUNT(*) FROM dbo.venta) AS total_ventas,
    (SELECT COUNT(*) FROM dbo.auditoria_venta) AS filas_auditoria;
GO

IF OBJECT_ID('tempdb..#resultados') IS NOT NULL
    DROP TABLE #resultados;
GO