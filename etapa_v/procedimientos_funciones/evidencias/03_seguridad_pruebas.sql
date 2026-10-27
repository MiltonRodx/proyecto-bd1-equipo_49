-- ============================================================================
-- ETAPA V - EVIDENCIA: PRUEBAS DE SEGURIDAD (ANEXO A)
-- Archivo: etapa_v/procedimientos_funciones/evidencias/03_seguridad_pruebas.sql
-- Ejecutar despues de 03_seguridad.sql.
-- Cada prueba usa EXECUTE AS USER ... REVERT. Los errores esperados se capturan
-- con TRY/CATCH para que el script siga avanzando y sirva de evidencia.
-- ============================================================================

SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

USE [X MOTORS];
GO

PRINT '=== Contexto de ejecucion ===';
SELECT
    CAST(@@VERSION AS VARCHAR(200)) AS version_motor,
    DB_NAME() AS base_de_datos,
    USER_NAME() AS usuario_de_bd,
    SYSDATETIME() AS fecha_hora;
GO

-- ============================================================================
-- 0. Inventario de roles, usuarios y permisos
-- ============================================================================
PRINT '=== Seguridad 0. Principales y permisos ===';
SELECT
    dp.name AS principal,
    dp.type_desc,
    dp.authentication_type_desc
FROM sys.database_principals AS dp
WHERE dp.name LIKE 'rol_xmotors%' OR dp.name LIKE 'usr_xmotors%'
ORDER BY dp.name;

SELECT
    r.name AS rol,
    m.name AS miembro
FROM sys.database_role_members AS drm
JOIN sys.database_principals AS r ON r.principal_id = drm.role_principal_id
JOIN sys.database_principals AS m ON m.principal_id = drm.member_principal_id
WHERE r.name LIKE 'rol_xmotors%';

SELECT
    USER_NAME() AS usuario_actual_cn,
    COUNT(*) AS permisos_concedidos_a_roles
FROM sys.database_permissions
WHERE grantee_principal_id IN (
    USER_ID('rol_xmotors_admin'),
    USER_ID('rol_xmotors_vendedor'),
    USER_ID('rol_xmotors_consulta')
);
GO

-- ============================================================================
-- 1. usr_xmotors_vendedor: SELECT de catalogo permitido
-- ============================================================================
PRINT '=== Seguridad 1. Vendedor: SELECT de catalogo (permitido) ===';
EXECUTE AS USER = 'usr_xmotors_vendedor';

SELECT TOP (3)
    id_modelo, nombre_modelo, marca, precio_lista, stock_disponible
FROM dbo.modelo_motocicleta
ORDER BY id_modelo;

SELECT USER_NAME() AS contexto;
REVERT;
GO

-- ============================================================================
-- 2. usr_xmotors_vendedor: INSERT directo en venta (DENEGADO)
-- ============================================================================
PRINT '=== Seguridad 2. Vendedor: INSERT directo en venta (negado, esperado 229) ===';
EXECUTE AS USER = 'usr_xmotors_vendedor';
BEGIN TRY
    INSERT INTO dbo.venta (
        fecha, metodo_pago, precio_venta_moto, monto_total,
        estado, dni_cliente, dni_vendedor, numero_chasis
    )
    VALUES (
        CAST(SYSDATETIME() AS DATE), 'efectivo', 1, 1,
        'efectuada', 28345672, 31222333, 'TEST-SEC'
    );
    PRINT 'ERROR: el insert directo NO debia permitirse.';
END TRY
BEGIN CATCH
    SELECT
        ERROR_NUMBER() AS error,
        CAST(ERROR_MESSAGE() AS VARCHAR(200)) AS mensaje;
END CATCH;
REVERT;
GO

-- ============================================================================
-- 3. usr_xmotors_vendedor: UPDATE directo (DENEGADO) y SELECT de auditoria (DENEGADO)
-- ============================================================================
PRINT '=== Seguridad 3. Vendedor: UPDATE directo (negado) y auditoria (negada) ===';
EXECUTE AS USER = 'usr_xmotors_vendedor';
BEGIN TRY
    UPDATE dbo.cliente SET estado = 'comprador' WHERE dni_cliente = 28345672;
    PRINT 'ERROR: el update directo NO debia permitirse.';
END TRY
BEGIN CATCH
    SELECT
        ERROR_NUMBER() AS error,
        CAST(ERROR_MESSAGE() AS VARCHAR(200)) AS mensaje;
END CATCH;

BEGIN TRY
    SELECT COUNT(*) AS filas_auditoria_venta FROM dbo.auditoria_venta;
    PRINT 'ERROR: leer la auditoria NO debia permitirse.';
END TRY
BEGIN CATCH
    SELECT
        ERROR_NUMBER() AS error,
        CAST(ERROR_MESSAGE() AS VARCHAR(200)) AS mensaje;
END CATCH;
REVERT;
GO

-- ============================================================================
-- 4. usr_xmotors_vendedor: procedimiento de reporte permitido (ownership chain)
-- ============================================================================
PRINT '=== Seguridad 4. Vendedor: EXEC sp_reporte_ventas_periodo (permitido) ===';
EXECUTE AS USER = 'usr_xmotors_vendedor';
EXEC dbo.sp_reporte_ventas_periodo @fecha_desde = '2026-01-01', @fecha_hasta = '2026-12-31';
SELECT USER_NAME() AS contexto;
REVERT;
GO

-- ============================================================================
-- 5. usr_xmotors_consulta: lectura de negocio permitida
-- ============================================================================
PRINT '=== Seguridad 5. Consulta: lectura de negocio (permitida) ===';
EXECUTE AS USER = 'usr_xmotors_consulta';

SELECT TOP (3)
    v.cod_venta, v.fecha, v.estado, v.monto_total
FROM dbo.venta AS v
ORDER BY v.cod_venta DESC;

SELECT USER_NAME() AS contexto;
REVERT;
GO

-- ============================================================================
-- 6. usr_xmotors_consulta: auditoria (DENEGADA) e historial (NEGADO)
-- ============================================================================
PRINT '=== Seguridad 6. Consulta: auditoria e historial (negados, esperado 230) ===';
EXECUTE AS USER = 'usr_xmotors_consulta';
BEGIN TRY
    SELECT * FROM dbo.auditoria_venta;
    PRINT 'ERROR: leer la auditoria NO debia permitirse.';
END TRY
BEGIN CATCH
    SELECT
        ERROR_NUMBER() AS error,
        CAST(ERROR_MESSAGE() AS VARCHAR(200)) AS mensaje;
END CATCH;

BEGIN TRY
    SELECT * FROM dbo.historial_de_precio;
    PRINT 'ERROR: leer el historial de precios NO debia permitirse.';
END TRY
BEGIN CATCH
    SELECT
        ERROR_NUMBER() AS error,
        CAST(ERROR_MESSAGE() AS VARCHAR(200)) AS mensaje;
END CATCH;
REVERT;
GO

-- ============================================================================
-- 7. usr_xmotors_consulta: EXEC de sp_registrar_venta (DENEGADO, esperado 229)
-- ============================================================================
PRINT '=== Seguridad 7. Consulta: EXEC sp_registrar_venta (negado) ===';
EXECUTE AS USER = 'usr_xmotors_consulta';
BEGIN TRY
    DECLARE @cod_venta INT;
    EXEC dbo.sp_registrar_venta
        @dni_cliente = 28345672,
        @dni_vendedor = 29876543,
        @numero_chasis = 'HONCB500F002',
        @metodo_pago = 'efectivo',
        @porcentaje_descuento = 0.00,
        @cod_venta = @cod_venta OUTPUT;
    PRINT 'ERROR: el EXEC NO debia permitirse.';
END TRY
BEGIN CATCH
    SELECT
        ERROR_NUMBER() AS error,
        CAST(ERROR_MESSAGE() AS VARCHAR(200)) AS mensaje;
END CATCH;
REVERT;
GO

-- ============================================================================
-- 8. usr_xmotors_admin: administracion completa
-- ============================================================================
PRINT '=== Seguridad 8. Admin: lectura y EXEC de administracion (permitidos) ===';
EXECUTE AS USER = 'usr_xmotors_admin';

SELECT COUNT(*) AS total_ventas FROM dbo.venta;
SELECT COUNT(*) AS total_auditoria FROM dbo.auditoria_venta;

-- sp_actualizar_precio_modelo con el mismo precio: no cambia nada y confirma
-- el permiso EXEC sin alterar datos.
EXEC dbo.sp_actualizar_precio_modelo @id_modelo = 1, @nuevo_precio = 3850000.00;

SELECT USER_NAME() AS contexto;
REVERT;
GO

-- ============================================================================
-- 9. Control final: sin datos de prueba de seguridad
-- ============================================================================
PRINT '=== Seguridad 9. Estado final ===';
SELECT
    (SELECT COUNT(*) FROM dbo.venta WHERE numero_chasis = 'TEST-SEC') AS ventas_prueba_restantes,
    (SELECT estado FROM dbo.cliente WHERE dni_cliente = 28345672) AS cliente_28345672_intacto,
    (SELECT precio_lista FROM dbo.modelo_motocicleta WHERE id_modelo = 1) AS precio_modelo_1;
GO

PRINT '=== Fin de las pruebas de seguridad ===';
GO
