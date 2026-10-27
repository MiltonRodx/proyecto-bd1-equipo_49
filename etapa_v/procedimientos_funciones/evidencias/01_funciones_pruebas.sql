-- ============================================================================
-- ETAPA V - EVIDENCIA: PRUEBAS DE FUNCIONES (TEMA 1)
-- Archivo: etapa_v/procedimientos_funciones/evidencias/01_funciones_pruebas.sql
-- Ejecutar despues de 01_funciones.sql.
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
    USER_NAME() AS usuario,
    SYSDATETIME() AS fecha_hora;
GO

PRINT '=== fn_precio_con_descuento: 10 %, 5 %, 0 % y casos invalidos ===';
SELECT
    dbo.fn_precio_con_descuento(8500000.00, 10.00) AS precio_con_10,
    dbo.fn_precio_con_descuento(8500000.00,  5.00) AS precio_con_5,
    dbo.fn_precio_con_descuento(8500000.00,  0.00) AS precio_sin_descuento,
    dbo.fn_precio_con_descuento(   -1.00, 10.00) AS precio_negativo,
    dbo.fn_precio_con_descuento(8500000.00, 101.00) AS porcentaje_invalido;
GO

PRINT '=== fn_descuento_cliente: umbrales 10 %, 5 %, 0 % y cliente inexistente ===';
SELECT
    dbo.fn_descuento_cliente(35123903) AS descuento_35123903,
    dbo.fn_descuento_cliente(30456781) AS descuento_30456781,
    dbo.fn_descuento_cliente(28345672) AS descuento_28345672,
    dbo.fn_descuento_cliente(99999999) AS descuento_cliente_inexistente;
GO

PRINT '=== fn_resumen_cliente: cantidad de compras, monto acumulado y descuento ===';
SELECT * FROM dbo.fn_resumen_cliente(35123903);
SELECT * FROM dbo.fn_resumen_cliente(30456781);
SELECT * FROM dbo.fn_resumen_cliente(28345672);
GO

PRINT '=== fn_total_accesorios_venta y fn_total_venta ===';
SELECT
    dbo.fn_total_accesorios_venta(1)    AS accesorios_venta_1,
    dbo.fn_total_accesorios_venta(10)   AS accesorios_venta_sin_detalle,
    dbo.fn_total_accesorios_venta(9999) AS accesorios_venta_inexistente,
    dbo.fn_total_venta(3650000.00, 1)    AS total_venta_1,
    dbo.fn_total_venta(3650000.00, 9999) AS total_venta_inexistente;
GO

PRINT '=== fn_stock_disponible_modelo ===';
SELECT
    dbo.fn_stock_disponible_modelo(11)   AS stock_modelo_11,
    dbo.fn_stock_disponible_modelo(2)    AS stock_modelo_2,
    dbo.fn_stock_disponible_modelo(9999) AS stock_modelo_inexistente;
GO

PRINT '=== fn_cotizacion_vigente: vencidas y inexistente ===';
SELECT
    dbo.fn_cotizacion_vigente(1)    AS cotizacion_1,
    dbo.fn_cotizacion_vigente(10)   AS cotizacion_10,
    dbo.fn_cotizacion_vigente(9999) AS cotizacion_inexistente;
GO

PRINT '=== fn_cotizacion_vigente: cotizacion temporal vigente (se revierte) ===';
BEGIN TRAN;

INSERT INTO dbo.cotizacion (
    fecha_emision,
    fecha_vencimiento,
    precio_cotizado,
    dni_cliente,
    id_modelo
)
VALUES (
    CAST(GETDATE() AS DATE),
    DATEADD(day, 7, CAST(GETDATE() AS DATE)),
    8500000.00,
    35123903,
    11
);

DECLARE @id_cotizacion INT = CAST(SCOPE_IDENTITY() AS INT);

SELECT
    @id_cotizacion AS id_cotizacion_temporal,
    dbo.fn_cotizacion_vigente(@id_cotizacion) AS vigente;

ROLLBACK;
GO

PRINT '=== Fin de las pruebas de funciones ===';
GO
