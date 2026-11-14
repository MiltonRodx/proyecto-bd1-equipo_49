-- ============================================================================
-- DEMOSTRACIÓN EN VIVO: VALIDACIÓN DE ROLES Y PERMISOS (X MOTORS)
-- ============================================================================

USE [X MOTORS];
GO

PRINT '====================================================================';
PRINT ' DEMO 1: VERIFICANDO PERMISOS DEL ROL CONSULTA (Solo lectura protegida)';
PRINT '====================================================================';
EXECUTE AS USER = 'usr_xmotors_consulta';
BEGIN
    PRINT 'Usuario actual: ' + USER_NAME();
    
    -- Intento 1: Consultar una tabla de negocio permitida (Debe tener éxito)
    PRINT '-> Intentando consultar modelo_motocicleta (Debe permitir):';
    SELECT TOP 3 id_modelo, nombre_modelo, precio_lista FROM dbo.modelo_motocicleta;

    -- Intento 2: Intentar leer una tabla técnica de auditoría (Debe dar error por DENY)
    PRINT '-> Intentando consultar auditoria_venta (Debe denegar por seguridad):';
    BEGIN TRY
        SELECT * FROM dbo.auditoria_venta;
    END TRY
    BEGIN CATCH
        PRINT '¡BLOQUEADO CON ÉXITO! Mensaje: ' + ERROR_MESSAGE();
    END CATCH;
END;
REVERT;
GO


PRINT '';
PRINT '====================================================================';
PRINT ' DEMO 2: VERIFICANDO PERMISOS DEL ROL VENDEDOR (Cero DML directo)';
PRINT '====================================================================';
EXECUTE AS USER = 'usr_xmotors_vendedor';
BEGIN
    PRINT 'Usuario actual: ' + USER_NAME();

    -- Intento 1: Consultar catálogos para trabajar (Debe tener éxito)
    PRINT '-> Consultando catálogo de motos permitidas:';
    SELECT TOP 2 id_modelo, nombre_modelo FROM dbo.modelo_motocicleta;

    -- Intento 2: Intentar hacer un INSERT directo a una tabla (Debe ser denegado por el DENY/Falta de permiso)
    PRINT '-> Intentando hacer INSERT directo a cliente (Debe fallar - principio de mínimo privilegio):';
    BEGIN TRY
        INSERT INTO dbo.cliente (dni_cliente, estado) VALUES (11111111, 'interesado');
    END TRY
    BEGIN CATCH
        PRINT '¡ACCESO DENEGADO CORRECTAMENTE! El vendedor solo opera vía Procedimientos Almacenados. Mensaje: ' + ERROR_MESSAGE();
    END CATCH;
END;
REVERT;
GO


PRINT '';
PRINT '====================================================================';
PRINT ' DEMO 3: VERIFICANDO MATRIZ DE PERMISOS AUTOMÁTICA (HAS_PERMS_BY_NAME)';
PRINT '====================================================================';
-- Esta consulta es genial para mostrar en pantalla una tabla resumen instantánea
SELECT 
    'usr_xmotors_vendedor' AS usuario_evaluado,
    HAS_PERMS_BY_NAME('dbo.venta', 'OBJECT', 'SELECT') AS puede_leer_ventas,
    HAS_PERMS_BY_NAME('dbo.venta', 'OBJECT', 'INSERT') AS puede_insertar_ventas,
    HAS_PERMS_BY_NAME('dbo.sp_RegistrarVentaCompleta', 'OBJECT', 'EXECUTE') AS puede_ejecutar_sp_venta;

SELECT 
    'usr_xmotors_consulta' AS usuario_evaluado,
    HAS_PERMS_BY_NAME('dbo.modelo_motocicleta', 'OBJECT', 'SELECT') AS puede_leer_modelos,
    HAS_PERMS_BY_NAME('dbo.historial_de_precio', 'OBJECT', 'SELECT') AS puede_leer_historial;
GO
