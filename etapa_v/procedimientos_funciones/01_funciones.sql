-- ============================================================================
-- ETAPA V - TEMA 1: PROCEDIMIENTOS Y FUNCIONES ALMACENADAS
-- Archivo: etapa_v/procedimientos_funciones/01_funciones.sql
-- Sistema: X Motors - Base de Datos I - Grupo 49 - FaCENA (UNNE)
-- Motor: SQL Server Express (validado en SQL Server 2025 Express)
--
-- Este script crea las funciones de apoyo del tema 1. No modifica datos.
-- Orden de ejecucion: despues del DDL y del DML de las etapas anteriores.
-- ============================================================================

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

USE [X MOTORS];
GO

-- ============================================================================
-- 1. fn_precio_con_descuento
--    Aplica un porcentaje de descuento al precio de la moto.
--    Regla de oro: el descuento se aplica sobre precio_venta_moto,
--    NUNCA sobre monto_total.
--    Devuelve NULL si el precio es negativo o el porcentaje no esta en 0..100.
-- ============================================================================
CREATE OR ALTER FUNCTION dbo.fn_precio_con_descuento (
    @precio_venta_moto DECIMAL(12,2),
    @porcentaje        DECIMAL(5,2)
) RETURNS DECIMAL(12,2)
AS
BEGIN
    IF @precio_venta_moto IS NULL OR @porcentaje IS NULL
        RETURN NULL;

    IF @precio_venta_moto < 0 OR @porcentaje < 0 OR @porcentaje > 100
        RETURN NULL;

    RETURN CAST(@precio_venta_moto * (1.0 - (@porcentaje / 100.0)) AS DECIMAL(12,2));
END;
GO

-- ============================================================================
-- 2. fn_total_accesorios_venta
--    Suma cantidad * precio_pactado de los accesorios de una venta.
--    Devuelve 0.00 si la venta existe pero no tiene accesorios.
--    Devuelve NULL si la venta no existe.
-- ============================================================================
CREATE OR ALTER FUNCTION dbo.fn_total_accesorios_venta (
    @cod_venta INT
) RETURNS DECIMAL(12,2)
AS
BEGIN
    IF NOT EXISTS (SELECT 1 FROM dbo.venta WHERE cod_venta = @cod_venta)
        RETURN NULL;

    RETURN ISNULL(
        (
            SELECT SUM(CAST(cantidad * precio_pactado AS DECIMAL(12,2)))
            FROM dbo.detalle_venta_accesorio
            WHERE cod_venta = @cod_venta
        ),
        0.00
    );
END;
GO

-- ============================================================================
-- 3. fn_total_venta
--    Calcula precio_venta_moto + total de accesorios.
--    Es la formula de control de venta.monto_total (RN6 / RN11).
-- ============================================================================
CREATE OR ALTER FUNCTION dbo.fn_total_venta (
    @precio_venta_moto DECIMAL(12,2),
    @cod_venta         INT
) RETURNS DECIMAL(12,2)
AS
BEGIN
    DECLARE @total_accesorios DECIMAL(12,2) = dbo.fn_total_accesorios_venta(@cod_venta);

    IF @precio_venta_moto IS NULL
       OR @precio_venta_moto < 0
       OR @total_accesorios IS NULL
        RETURN NULL;

    RETURN CAST(@precio_venta_moto + @total_accesorios AS DECIMAL(12,2));
END;
GO

-- ============================================================================
-- 4. fn_cotizacion_vigente
--    Implementa RN12: una cotizacion vale 7 dias corridos desde su emision.
--    Devuelve 1 si sigue vigente, 0 si vencio y NULL si no existe.
-- ============================================================================
CREATE OR ALTER FUNCTION dbo.fn_cotizacion_vigente (
    @id_cotizacion INT
) RETURNS BIT
AS
BEGIN
    DECLARE @fecha_vencimiento DATE;

    SELECT @fecha_vencimiento = fecha_vencimiento
    FROM dbo.cotizacion
    WHERE id_cotizacion = @id_cotizacion;

    IF @fecha_vencimiento IS NULL
        RETURN NULL;

    RETURN CASE
        WHEN CAST(GETDATE() AS DATE) <= @fecha_vencimiento THEN 1
        ELSE 0
    END;
END;
GO

-- ============================================================================
-- 5. fn_stock_disponible_modelo
--    Devuelve el stock disponible de un modelo.
--    Devuelve NULL si el modelo no existe.
--    No recalcula stock: lee la columna mantenida por los procedimientos.
-- ============================================================================
CREATE OR ALTER FUNCTION dbo.fn_stock_disponible_modelo (
    @id_modelo INT
) RETURNS INT
AS
BEGIN
    DECLARE @stock INT;

    SELECT @stock = stock_disponible
    FROM dbo.modelo_motocicleta
    WHERE id_modelo = @id_modelo;

    RETURN @stock;
END;
GO

-- ============================================================================
-- 6. fn_descuento_cliente
--    Regla de descuento por historial de compras:
--      mas de $10.000.000 efectuados -> 10 %
--      mas de  $5.000.000 efectuados ->  5 %
--      resto                          ->  0 %
--    Solo suman las ventas en estado 'efectuada'.
--    Devuelve NULL si el cliente no existe.
-- ============================================================================
CREATE OR ALTER FUNCTION dbo.fn_descuento_cliente (
    @dni_cliente INT
) RETURNS DECIMAL(5,2)
AS
BEGIN
    IF NOT EXISTS (SELECT 1 FROM dbo.cliente WHERE dni_cliente = @dni_cliente)
        RETURN NULL;

    DECLARE @monto_acumulado DECIMAL(14,2);

    SELECT @monto_acumulado = ISNULL(SUM(monto_total), 0.00)
    FROM dbo.venta
    WHERE dni_cliente = @dni_cliente
      AND estado = 'efectuada';

    RETURN CASE
        WHEN @monto_acumulado > 10000000.00 THEN CAST(10.00 AS DECIMAL(5,2))
        WHEN @monto_acumulado >  5000000.00 THEN CAST( 5.00 AS DECIMAL(5,2))
        ELSE CAST(0.00 AS DECIMAL(5,2))
    END;
END;
GO

-- ============================================================================
-- 7. fn_resumen_cliente
--    Funcion inline table-valued: cantidad de compras efectuadas,
--    monto acumulado y descuento que le corresponde al cliente.
-- ============================================================================
CREATE OR ALTER FUNCTION dbo.fn_resumen_cliente (
    @dni_cliente INT
) RETURNS TABLE
AS
RETURN
(
    SELECT
        r.dni_cliente,
        r.cantidad_ventas,
        r.monto_acumulado,
        dbo.fn_descuento_cliente(r.dni_cliente) AS descuento
    FROM
    (
        SELECT
            c.dni_cliente,
            COUNT(v.cod_venta) AS cantidad_ventas,
            CAST(ISNULL(SUM(v.monto_total), 0.00) AS DECIMAL(14,2)) AS monto_acumulado
        FROM dbo.cliente AS c
        LEFT JOIN dbo.venta AS v
            ON v.dni_cliente = c.dni_cliente
           AND v.estado = 'efectuada'
        WHERE c.dni_cliente = @dni_cliente
        GROUP BY c.dni_cliente
    ) AS r
);
GO

PRINT '01_funciones.sql ejecutado: 7 funciones creadas en [X MOTORS].';
GO
