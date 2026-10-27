-- ============================================================================
-- ETAPA V - EVIDENCIA: PRUEBAS DE PROCEDIMIENTOS (TEMA 1)
-- Archivo: etapa_v/procedimientos_funciones/evidencias/02_procedimientos_pruebas.sql
-- Ejecutar despues de:
--   01_funciones.sql
--   02_procedimientos.sql
--   transacciones/01_sp_registrar_venta.sql
--   transacciones/02_sp_cambiar_estado_venta.sql
-- ============================================================================

SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;
GO

USE [X MOTORS];
GO

PRINT '=== Contexto de ejecucion ===';
SELECT
    CAST(@@VERSION AS VARCHAR(200)) AS version_motor,
    DB_NAME() AS base_de_datos,
    USER_NAME() AS usuario,
    SYSDATETIME() AS fecha_hora;
GO

-- ============================================================================
-- 1. sp_actualizar_precio_modelo: actualizacion y restauracion
-- ============================================================================
PRINT '=== sp_actualizar_precio_modelo: actualizacion y restauracion ===';
SELECT id_modelo, precio_lista AS precio_antes FROM dbo.modelo_motocicleta WHERE id_modelo = 1;

EXEC dbo.sp_actualizar_precio_modelo @id_modelo = 1, @nuevo_precio = 3950000.00;

SELECT id_modelo, precio_lista AS precio_despues FROM dbo.modelo_motocicleta WHERE id_modelo = 1;

EXEC dbo.sp_actualizar_precio_modelo @id_modelo = 1, @nuevo_precio = 3850000.00;

SELECT id_modelo, precio_lista AS precio_restaurado FROM dbo.modelo_motocicleta WHERE id_modelo = 1;
GO

-- ============================================================================
-- 2. sp_actualizar_precio_modelo: errores controlados
-- ============================================================================
PRINT '=== sp_actualizar_precio_modelo: modelo inexistente ===';
BEGIN TRY
    EXEC dbo.sp_actualizar_precio_modelo @id_modelo = 9999, @nuevo_precio = 100.00;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS error, CAST(ERROR_MESSAGE() AS VARCHAR(200)) AS mensaje;
END CATCH;
GO

PRINT '=== sp_actualizar_precio_modelo: precio invalido ===';
BEGIN TRY
    EXEC dbo.sp_actualizar_precio_modelo @id_modelo = 1, @nuevo_precio = -1.00;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS error, CAST(ERROR_MESSAGE() AS VARCHAR(200)) AS mensaje;
END CATCH;
GO

-- ============================================================================
-- 3. sp_reporte_ventas_periodo
-- ============================================================================
PRINT '=== sp_reporte_ventas_periodo: ventas efectuadas 2026 ===';
EXEC dbo.sp_reporte_ventas_periodo @fecha_desde = '2026-01-01', @fecha_hasta = '2026-12-31';
GO

PRINT '=== sp_reporte_ventas_periodo: rango invalido ===';
BEGIN TRY
    EXEC dbo.sp_reporte_ventas_periodo @fecha_desde = '2026-12-31', @fecha_hasta = '2026-01-01';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS error, CAST(ERROR_MESSAGE() AS VARCHAR(200)) AS mensaje;
END CATCH;
GO

-- ============================================================================
-- 4. sp_registrar_venta: venta demo con 10 % de descuento
--    Cliente 35123903 (2 ventas efectuadas, $24.945.950 -> 10 %)
--    Chasis HONCB500F003 (modelo 11, precio lista $8.500.000)
--    Accesorios 1 (Casco, $185.000) y 3 (Guantes, $42.000)
--    Resultado esperado:
--      precio_venta_moto = $7.650.000
--      monto_total       = $7.877.000
-- ============================================================================
PRINT '=== sp_registrar_venta: venta demo con 10 % de descuento ===';

DECLARE @cod_venta INT;

EXEC dbo.sp_registrar_venta
    @dni_cliente          = 35123903,
    @dni_vendedor         = 31222333,
    @numero_chasis        = 'HONCB500F003',
    @metodo_pago          = 'transferencia',
    @porcentaje_descuento = 10.00,
    @accesorios_json      = N'[{"id_accesorio":1,"cantidad":1},{"id_accesorio":3,"cantidad":1}]',
    @cod_venta            = @cod_venta OUTPUT;

SELECT @cod_venta AS cod_venta_generado;

SELECT
    cod_venta,
    fecha,
    metodo_pago,
    precio_venta_moto,
    monto_total,
    estado,
    dni_cliente,
    dni_vendedor,
    numero_chasis
FROM dbo.venta
WHERE cod_venta = @cod_venta;

SELECT
    d.cod_venta,
    d.id_accesorio,
    a.descripcion,
    d.cantidad,
    d.precio_pactado,
    CAST(d.cantidad * d.precio_pactado AS DECIMAL(12,2)) AS subtotal
FROM dbo.detalle_venta_accesorio AS d
JOIN dbo.accesorio AS a ON a.id_accesorio = d.id_accesorio
WHERE d.cod_venta = @cod_venta;

SELECT id_modelo, stock_disponible AS stock_modelo_11 FROM dbo.modelo_motocicleta WHERE id_modelo = 11;

SELECT id_accesorio, stock AS stock_accesorio FROM dbo.accesorio WHERE id_accesorio IN (1, 3);

SELECT dni_cliente, estado AS estado_cliente FROM dbo.cliente WHERE dni_cliente = 35123903;

-- Control de factura de Etapa IV: precio_venta_moto + accesorios = monto_total
SELECT
    v.cod_venta,
    v.precio_venta_moto,
    ISNULL(SUM(CAST(d.cantidad * d.precio_pactado AS DECIMAL(12,2))), 0) AS total_accesorios,
    CAST(v.precio_venta_moto + ISNULL(SUM(CAST(d.cantidad * d.precio_pactado AS DECIMAL(12,2))), 0) AS DECIMAL(12,2)) AS total_calculado,
    v.monto_total AS total_guardado,
    CASE
        WHEN CAST(v.precio_venta_moto + ISNULL(SUM(CAST(d.cantidad * d.precio_pactado AS DECIMAL(12,2))), 0) AS DECIMAL(12,2)) = v.monto_total
        THEN 'OK'
        ELSE 'DIFERENCIA'
    END AS control
FROM dbo.venta AS v
LEFT JOIN dbo.detalle_venta_accesorio AS d ON d.cod_venta = v.cod_venta
WHERE v.cod_venta = @cod_venta
GROUP BY v.cod_venta, v.precio_venta_moto, v.monto_total;

-- ============================================================================
-- 5. sp_cambiar_estado_venta: cancelacion y reintegro de stock
-- ============================================================================
PRINT '=== sp_cambiar_estado_venta: cancelacion y reintegro ===';

EXEC dbo.sp_cambiar_estado_venta @cod_venta = @cod_venta, @nuevo_estado = 'cancelada';

SELECT cod_venta, estado, monto_total FROM dbo.venta WHERE cod_venta = @cod_venta;
SELECT id_modelo, stock_disponible AS stock_modelo_11_reintegrado FROM dbo.modelo_motocicleta WHERE id_modelo = 11;
SELECT id_accesorio, stock AS stock_accesorio_reintegrado FROM dbo.accesorio WHERE id_accesorio IN (1, 3);

-- ============================================================================
-- 6. Doble cancelacion: debe fallar con 50013 y no reintegrar dos veces
-- ============================================================================
PRINT '=== sp_cambiar_estado_venta: doble cancelacion (error esperado 50013) ===';
BEGIN TRY
    EXEC dbo.sp_cambiar_estado_venta @cod_venta = @cod_venta, @nuevo_estado = 'reembolsada';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS error, CAST(ERROR_MESSAGE() AS VARCHAR(200)) AS mensaje;
END CATCH;

SELECT id_modelo, stock_disponible AS stock_modelo_11_final FROM dbo.modelo_motocicleta WHERE id_modelo = 11;
SELECT id_accesorio, stock AS stock_accesorio_final FROM dbo.accesorio WHERE id_accesorio IN (1, 3);

-- ============================================================================
-- 7. Limpieza: eliminar la venta demo cancelada para dejar el lote como estaba.
--    El stock ya fue reintegrado por la cancelacion.
-- ============================================================================
PRINT '=== Limpieza de la venta demo ===';
DELETE FROM dbo.detalle_venta_accesorio WHERE cod_venta = @cod_venta;
DELETE FROM dbo.venta WHERE cod_venta = @cod_venta;

SELECT
    (SELECT COUNT(*) FROM dbo.venta WHERE cod_venta = @cod_venta) AS venta_demo_restante,
    (SELECT stock_disponible FROM dbo.modelo_motocicleta WHERE id_modelo = 11) AS stock_modelo_11_limpio;
GO

-- ============================================================================
-- 8. Casos negativos de sp_registrar_venta
-- ============================================================================
PRINT '=== sp_registrar_venta: chasis ya vendido (error esperado 50005) ===';
BEGIN TRY
    DECLARE @cod_negocio INT;
    EXEC dbo.sp_registrar_venta
        @dni_cliente          = 35123903,
        @dni_vendedor         = 31222333,
        @numero_chasis        = 'HONCB500F001',
        @metodo_pago          = 'efectivo',
        @porcentaje_descuento = 0.00,
        @cod_venta            = @cod_negocio OUTPUT;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS error, CAST(ERROR_MESSAGE() AS VARCHAR(200)) AS mensaje;
END CATCH;
GO

PRINT '=== sp_registrar_venta: modelo sin stock (error esperado 50004) ===';
BEGIN TRY
    DECLARE @cod_negocio INT;
    EXEC dbo.sp_registrar_venta
        @dni_cliente          = 28345672,
        @dni_vendedor         = 29876543,
        @numero_chasis        = '9C2HON00000000003',
        @metodo_pago          = 'efectivo',
        @porcentaje_descuento = 0.00,
        @cod_venta            = @cod_negocio OUTPUT;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS error, CAST(ERROR_MESSAGE() AS VARCHAR(200)) AS mensaje;
END CATCH;
GO

PRINT '=== sp_registrar_venta: accesorio sin stock suficiente (error esperado 50008) ===';
BEGIN TRY
    DECLARE @cod_negocio INT;
    EXEC dbo.sp_registrar_venta
        @dni_cliente          = 35123903,
        @dni_vendedor         = 31222333,
        @numero_chasis        = 'HONCB500F002',
        @metodo_pago          = 'efectivo',
        @porcentaje_descuento = 0.00,
        @accesorios_json      = N'[{"id_accesorio":1,"cantidad":9999}]',
        @cod_venta            = @cod_negocio OUTPUT;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS error, CAST(ERROR_MESSAGE() AS VARCHAR(200)) AS mensaje;
END CATCH;
GO

-- ============================================================================
-- 9. Regresiones de las validaciones corregidas
-- ============================================================================
PRINT '=== sp_registrar_venta: metodo de pago NULL (error esperado 50011) ===';
BEGIN TRY
    DECLARE @cod_negocio INT;
    EXEC dbo.sp_registrar_venta
        @dni_cliente          = 35123903,
        @dni_vendedor         = 31222333,
        @numero_chasis        = 'HONCB500F003',
        @metodo_pago          = NULL,
        @porcentaje_descuento = 0.00,
        @cod_venta            = @cod_negocio OUTPUT;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS error, CAST(ERROR_MESSAGE() AS VARCHAR(200)) AS mensaje;
END CATCH;
GO

PRINT '=== sp_registrar_venta: precio de accesorio negativo (error esperado 50018) ===';
BEGIN TRY
    DECLARE @cod_negocio INT;
    EXEC dbo.sp_registrar_venta
        @dni_cliente          = 35123903,
        @dni_vendedor         = 31222333,
        @numero_chasis        = 'HONCB500F003',
        @metodo_pago          = 'efectivo',
        @porcentaje_descuento = 0.00,
        @accesorios_json      = N'[{"id_accesorio":1,"cantidad":1,"precio_pactado":-1}]',
        @cod_venta            = @cod_negocio OUTPUT;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS error, CAST(ERROR_MESSAGE() AS VARCHAR(200)) AS mensaje;
END CATCH;
GO

PRINT '=== sp_registrar_venta: descuento mayor al permitido (error esperado 50009) ===';
BEGIN TRY
    DECLARE @cod_negocio INT;
    EXEC dbo.sp_registrar_venta
        @dni_cliente          = 35123903,
        @dni_vendedor         = 31222333,
        @numero_chasis        = 'HONCB500F003',
        @metodo_pago          = 'efectivo',
        @porcentaje_descuento = 11.00,
        @cod_venta            = @cod_negocio OUTPUT;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS error, CAST(ERROR_MESSAGE() AS VARCHAR(200)) AS mensaje;
END CATCH;
GO

-- ============================================================================
-- 10. Descuento automatico por historial y venta sin accesorios
--     Cliente 35123903: 10 %. Se omite @porcentaje_descuento.
--     Resultado esperado: precio_venta_moto = monto_total = $7.650.000
-- ============================================================================
PRINT '=== sp_registrar_venta: descuento automatico sin accesorios ===';
DECLARE @cod_auto INT;

EXEC dbo.sp_registrar_venta
    @dni_cliente          = 35123903,
    @dni_vendedor         = 31222333,
    @numero_chasis        = 'HONCB500F003',
    @metodo_pago          = 'efectivo',
    @accesorios_json      = NULL,
    @cod_venta            = @cod_auto OUTPUT;

SELECT
    cod_venta,
    precio_venta_moto,
    monto_total,
    CASE
        WHEN precio_venta_moto = 7650000.00 AND monto_total = 7650000.00
        THEN 'OK'
        ELSE 'DIFERENCIA'
    END AS control_descuento_automatico
FROM dbo.venta
WHERE cod_venta = @cod_auto;

EXEC dbo.sp_cambiar_estado_venta @cod_venta = @cod_auto, @nuevo_estado = 'cancelada';
DELETE FROM dbo.detalle_venta_accesorio WHERE cod_venta = @cod_auto;
DELETE FROM dbo.venta WHERE cod_venta = @cod_auto;
GO

-- ============================================================================
-- 11. Opciones SET hostiles: el procedimiento debe fijar las opciones que
--     exige el indice filtrado y completar la venta sin error 1934.
-- ============================================================================
PRINT '=== sp_registrar_venta: opciones SET hostiles (indice filtrado) ===';
DECLARE @cod_set INT;
DECLARE @cancel_ok BIT = 0;

SET ARITHABORT OFF;
SET ANSI_WARNINGS OFF;
SET CONCAT_NULL_YIELDS_NULL OFF;
SET NUMERIC_ROUNDABORT ON;

BEGIN TRY
    EXEC dbo.sp_registrar_venta
        @dni_cliente          = 35123903,
        @dni_vendedor         = 31222333,
        @numero_chasis        = 'HONCB500F003',
        @metodo_pago          = 'efectivo',
        @accesorios_json      = NULL,
        @cod_venta            = @cod_set OUTPUT;

    SELECT 'VENTA OK CON OPCIONES HOSTILES' AS resultado;

    IF @cod_set IS NOT NULL
    BEGIN
        EXEC dbo.sp_cambiar_estado_venta @cod_venta = @cod_set, @nuevo_estado = 'cancelada';
        SELECT 'CANCEL OK CON OPCIONES HOSTILES' AS resultado;
        SET @cancel_ok = 1;
    END
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS error, CAST(ERROR_MESSAGE() AS VARCHAR(200)) AS mensaje;
END CATCH;

SET ARITHABORT ON;
SET ANSI_WARNINGS ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;

IF @cod_set IS NOT NULL AND @cancel_ok = 1
BEGIN
    DELETE FROM dbo.detalle_venta_accesorio WHERE cod_venta = @cod_set;
    DELETE FROM dbo.venta WHERE cod_venta = @cod_set;
END
GO

PRINT '=== Estado final: sin ventas nuevas y stock intacto ===';
SELECT
    (SELECT COUNT(*) FROM dbo.venta WHERE numero_chasis IN ('HONCB500F003', 'HONCB500F002')) AS ventas_nuevas_restantes,
    (SELECT stock_disponible FROM dbo.modelo_motocicleta WHERE id_modelo = 11) AS stock_modelo_11,
    (SELECT stock FROM dbo.accesorio WHERE id_accesorio = 1) AS stock_accesorio_1,
    (SELECT stock FROM dbo.accesorio WHERE id_accesorio = 3) AS stock_accesorio_3;
GO

PRINT '=== Fin de las pruebas de procedimientos ===';
GO
