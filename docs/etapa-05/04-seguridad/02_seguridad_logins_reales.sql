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
--   2. Se usa un SP simple esp para la Prueba 3 (sp_demo_insert_venta_simple,
--      con INSERT directo, sin SQL dinamico), igual al caso del profesor.
--      El SP real sp_registrar_venta hace el INSERT via sp_executesql y el
--      ownership chaining NO cruza lotes dinamicos (ver observacion honesta
--      en investigacion.md): ese limite se documenta, no se fuerza.
--   3. El INSERT permanente de la Prueba 3 queda solo temporalmente:
--      al final del script se ELIMINAN las filas demo de venta para
--      restaurar el lote de Etapa III. Las filas de auditoria_producto
--      quedan como evidencia (no se borran, convencion de la etapa).
--   4. Role de consulta temporario en Parte 2 para no tocar los roles
--      permanentes de 01_seguridad.sql (rol_xmotors_*).
-- =====================================================================

SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

-- -------------------------------------------------------------------
-- 0. Limpieza previa (idempotencia): objects de una corrida anterior
-- -------------------------------------------------------------------
-- El chasis YAMMT03002 (modelo 12, stock 2) queda reservado para la
-- demo de seguridad y sin ventas en el lote del DML.
DELETE FROM dbo.venta WHERE numero_chasis = 'YAMMT03002';

IF OBJECT_ID('dbo.sp_demo_insert_venta_simple', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_demo_insert_venta_simple;
GO

IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'usr_demo_xmotors_lector')
    DROP USER usr_demo_xmotors_lector;
IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'usr_demo_xmotors_admin')
    DROP USER usr_demo_xmotors_admin;
IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'usr_demo_xmotors_rol')
    DROP USER usr_demo_xmotors_rol;
IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'usr_demo_xmotors_norol')
    DROP USER usr_demo_xmotors_norol;

IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'rol_demo_consulta_modelos')
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
-- 1.1 Creacion de login y usuarios (estilo del profesor)
-- -------------------------------------------------------------------
CREATE LOGIN usr_demo_xmotors_admin
    WITH PASSWORD = 'DemoAdmin123*', CHECK_POLICY = OFF;
CREATE LOGIN usr_demo_xmotors_lector
    WITH PASSWORD = 'DemoLector123*', CHECK_POLICY = OFF;
GO

USE [X MOTORS];
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

EXECUTE AS USER = 'usr_demo_xmotors_admin';
BEGIN TRY
    BEGIN TRANSACTION;
    INSERT INTO dbo.venta
        (fecha, metodo_pago, precio_venta_moto, monto_total, estado,
         dni_cliente, dni_vendedor, numero_chasis)
    VALUES
        (CAST(SYSDATETIME() AS DATE), 'efectivo', 15000000.00, 15000000.00,
         'efectuada', 30456781, 31222333, 'YAMMT03002');
    PRINT 'Resultado: EXITOSO (INSERT permitido para db_owner)';
    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    PRINT 'Resultado: DENEGADO';
    PRINT 'Error: ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ' - ' + ERROR_MESSAGE();
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
END CATCH;
REVERT;
GO

-- ===================================================================
-- PRUEBA 2: INSERT directo sobre venta con usuario LECTOR
-- Esperado: denegado por falta de permisos (229)
-- ===================================================================
PRINT '';
PRINT 'PRUEBA 2 - INSERT directo sobre venta con usuario_lector';
PRINT 'Resultado esperado: denegado por falta de permisos (error 229)';

EXECUTE AS USER = 'usr_demo_xmotors_lector';
BEGIN TRY
    INSERT INTO dbo.venta
        (fecha, metodo_pago, precio_venta_moto, monto_total, estado,
         dni_cliente, dni_vendedor, numero_chasis)
    VALUES
        (CAST(SYSDATETIME() AS DATE), 'efectivo', 15000000.00, 15000000.00,
         'efectuada', 30456781, 31222333, 'YAMMT03002');
    PRINT 'Resultado: INESPERADO (el INSERT no debia ser permitido)';
END TRY
BEGIN CATCH
    PRINT 'Resultado: DENEGADO';
    PRINT 'Error: ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ' - ' + ERROR_MESSAGE();
END CATCH;
REVERT;
GO

-- ===================================================================
-- PRUEBA 3: INSERT via PROCEDIMIENTO con usuario LECTOR
-- Esperado: exito por GRANT EXECUTE + ownership chaining
-- (sin SQL dinamico: el INSERT es del propietario dbo del SP).
-- ===================================================================
PRINT '';
PRINT 'PRUEBA 3 - EXEC dbo.sp_demo_insert_venta_simple con usuario_lector';
PRINT 'Resultado esperado: exito por GRANT EXECUTE (ownership chaining)';

EXECUTE AS USER = 'usr_demo_xmotors_lector';
DECLARE @hoy DATE = CAST(SYSDATETIME() AS DATE);
BEGIN TRY
    EXEC dbo.sp_demo_insert_venta_simple
        @fecha        = @hoy,
        @metodo       = 'efectivo',
        @monto        = 15000000.00,
        @chasis       = 'YAMMT03002',
        @dni_cliente  = 30456781,
        @dni_vendedor = 31222333;
    PRINT 'Resultado: EXITOSO (el usuario no puede INSERT directo, pero si via SP con GRANT EXECUTE)';
END TRY
BEGIN CATCH
    PRINT 'Resultado: FALLO INESPERADO';
    PRINT 'Error: ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ' - ' + ERROR_MESSAGE();
END CATCH;
REVERT;
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

EXECUTE AS USER = 'usr_demo_xmotors_rol';
BEGIN TRY
    SELECT TOP (2)
        id_modelo,
        CAST(nombre_modelo AS VARCHAR(60)) AS nombre_modelo,
        precio_lista
    FROM dbo.modelo_motocicleta
    ORDER BY id_modelo;
    PRINT 'Resultado: EXITOSO (permiso via rol_demo_consulta_modelos)';
END TRY
BEGIN CATCH
    PRINT 'Resultado: DENEGADO (inesperado)';
    PRINT 'Error: ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ' - ' + ERROR_MESSAGE();
END CATCH;
REVERT;
GO

-- ===================================================================
-- PRUEBA 5: SELECT modelo_motocicleta con USUARIO SIN ROL
-- Esperado: denegado por falta de permisos (229)
-- ===================================================================
PRINT '';
PRINT 'PRUEBA 5 - SELECT modelo_motocicleta con usuario sin rol';
PRINT 'Resultado esperado: denegado por falta de permisos (error 229)';

EXECUTE AS USER = 'usr_demo_xmotors_norol';
BEGIN TRY
    SELECT TOP (2)
        id_modelo,
        CAST(nombre_modelo AS VARCHAR(60)) AS nombre_modelo,
        precio_lista
    FROM dbo.modelo_motocicleta
    ORDER BY id_modelo;
    PRINT 'Resultado: INESPERADO (el SELECT no debia ser permitido)';
END TRY
BEGIN CATCH
    PRINT 'Resultado: DENEGADO';
    PRINT 'Error: ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ' - ' + ERROR_MESSAGE();
END CATCH;
REVERT;
GO

-- ===================================================================
-- RESUMEN (tabla comparativa del profesor)
-- ===================================================================
PRINT '';
PRINT '==================================================';
PRINT 'RESUMEN - TABLA DE PRUEBAS (resultado esperado vs obtenido)';
PRINT '==================================================';
PRINT '1. INSERT directo venta  | usr_admin  | esperado: OK         | obtenido: (ver arriba)';
PRINT '2. INSERT directo venta  | usr_lector | esperado: 229        | obtenido: (ver arriba)';
PRINT '3. EXEC SP demo          | usr_lector | esperado: OK         | obtenido: (ver arriba)';
PRINT '4. SELECT modelos        | usr con rol| esperado: OK         | obtenido: (ver arriba)';
PRINT '5. SELECT modelos        | usr sin rol| esperado: 229        | obtenido: (ver arriba)';
GO

-- ===================================================================
-- LIMPIEZA: se destruye todo lo creado por esta demo
-- -------------------------------------------------------------------
-- 1. Se eliminan las filas demo confirmadas por la Prueba 3 (el chasis
--    YAMMT03002 queda reservado para pruebas y sin ventas del lote DML).
-- 2. NO se borra auditoria_venta: queda como evidencia (INSERT/DELETE).
--    Las filas generadas por el INSERT via SP y su DELETE quedan en
--    auditoria_venta; es la constancia de la demo.
-- 3. Se dropean SP, rol, usuarios y logins.
-- ===================================================================
DELETE FROM dbo.venta
WHERE numero_chasis = 'YAMMT03002';
GO

DROP PROCEDURE dbo.sp_demo_insert_venta_simple;

DROP USER usr_demo_xmotors_lector;
DROP USER usr_demo_xmotors_admin;
DROP USER usr_demo_xmotors_rol;
DROP USER usr_demo_xmotors_norol;

-- El rol se dropea recien despues de suspender a sus miembros
DROP ROLE rol_demo_consulta_modelos;
GO

USE master;
GO

DROP LOGIN usr_demo_xmotors_admin;
DROP LOGIN usr_demo_xmotors_lector;
DROP LOGIN usr_demo_xmotors_rol;
DROP LOGIN usr_demo_xmotors_norol;
GO

USE [X MOTORS];
GO

SELECT
    DB_NAME() AS base_final,
    (SELECT COUNT(*) FROM dbo.venta) AS total_ventas,
    (SELECT COUNT(*) FROM dbo.auditoria_venta) AS filas_auditoria;
GO
