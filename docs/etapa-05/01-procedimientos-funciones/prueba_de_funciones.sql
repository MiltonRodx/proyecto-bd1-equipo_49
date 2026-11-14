USE [X MOTORS];
GO

-- ============================================================
-- PRUEBA DE LAS FUNCIONES
-- ============================================================

-- 1. Precio con descuento
-- Moto de $5.000.000 con 10% de descuento
SELECT dbo.fn_precio_con_descuento(5000000, 10) AS PrecioConDescuento;


-- 2. Total de accesorios de una venta
-- Reemplazar 1 por un cod_venta que tenga accesorios
SELECT dbo.fn_total_accesorios_venta(1) AS TotalAccesorios;


-- 3. Total de una venta
-- Suma el precio de la moto + sus accesorios
SELECT dbo.fn_total_venta(5000000, 1) AS TotalVenta;


-- 4. Cotización vigente
-- Devuelve 1 si está vigente, 0 si venció
SELECT dbo.fn_cotizacion_vigente(1) AS CotizacionVigente;


-- 5. Stock disponible de un modelo
-- Reemplazar 1 por un id_modelo existente
SELECT dbo.fn_stock_disponible_modelo(1) AS StockDisponible;


-- 6. Descuento del cliente
-- Se calcula según el total de sus compras efectuadas
SELECT dbo.fn_descuento_cliente(12345678) AS DescuentoCliente;


-- 7. Resumen completo del cliente
-- Muestra cantidad de compras, monto acumulado y descuento
SELECT *
FROM dbo.fn_resumen_cliente(12345678);
