USE [X MOTORS];
GO

-- ============================================================
-- PRUEBA DE PROCEDIMIENTOS ALMACENADOS
-- ============================================================

-- 1. Actualizar precio de un modelo
-- Cambia el precio de lista del modelo indicado.
-- Usar un id_modelo que exista.
EXEC dbo.sp_actualizar_precio_modelo
    @id_modelo = 1,
    @nuevo_precio = 5000000;


-- 2. Reporte de ventas
-- Muestra las ventas efectuadas y las agrupa por vendedor.
-- Si no pasamos fechas, muestra todo el historial.
EXEC dbo.sp_reporte_ventas_periodo;


-- También podemos indicar un período:
-- EXEC dbo.sp_reporte_ventas_periodo
--     @fecha_desde = '2026-01-01',
--     @fecha_hasta = '2026-12-31';


-- 3. Generar una cotización
-- El procedimiento calcula el descuento del cliente
-- y genera una cotización con vencimiento a 7 días.
DECLARE @id_cotizacion INT;

EXEC dbo.sp_generar_cotizacion
    @dni_cliente = 30111222,
    @id_modelo = 1,
    @id_cotizacion = @id_cotizacion OUTPUT;

-- Mostramos el ID generado
SELECT @id_cotizacion AS IdCotizacion;


-- 4. Registrar una venta completa
-- Registra la venta, accesorios, descuento y actualiza stock
-- dentro de una única transacción.
DECLARE @cod_venta INT;

EXEC dbo.sp_RegistrarVentaCompleta
    @dni_cliente = 30111222,
    @dni_vendedor = 28999888,
    @numero_chasis = 'CHASIS-001',
    @metodo_pago = 'efectivo',
    @accesorios_json = N'[{"id_accesorio":3,"cantidad":1}]',
    @cod_venta = @cod_venta OUTPUT;

-- Mostramos el código de la venta creada
SELECT @cod_venta AS CodigoVenta;
