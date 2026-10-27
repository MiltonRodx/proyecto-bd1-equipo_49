-- ============================================================================
-- ETAPA V - EVIDENCIA: PRUEBAS DE TRIGGERS DE AUDITORIA (TEMA 3)
-- Archivo: etapa_v/triggers_auditoria/evidencias/01_pruebas_triggers.sql
-- Ejecutar despues de:
--   01_tablas_auditoria.sql
--   02_trg_historial_precio_modelo.sql
--   03_trg_auditoria_venta.sql
--   04_trg_auditoria_cliente_estado.sql
-- Los registros de auditoria NO se borran: son la evidencia de la prueba.
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
-- 1. trg_historial_precio_modelo: precio del modelo 1 sube y se restaura
-- ============================================================================
PRINT '=== HISTORIAL 1. Estado inicial ===';
SELECT COUNT(*) AS historial_total_antes FROM dbo.historial_de_precio;
SELECT id_modelo, precio_lista FROM dbo.modelo_motocicleta WHERE id_modelo = 1;
GO

PRINT '=== HISTORIAL 2. sp_actualizar_precio_modelo: 3.850.000 -> 3.950.000 ===';
EXEC dbo.sp_actualizar_precio_modelo @id_modelo = 1, @nuevo_precio = 3950000.00;

SELECT TOP (2)
    id_historial, id_modelo, precio_anterior, precio_nuevo, fecha_modificacion
FROM dbo.historial_de_precio
ORDER BY id_historial DESC;

PRINT '=== HISTORIAL 3. Restauracion: 3.950.000 -> 3.850.000 ===';
EXEC dbo.sp_actualizar_precio_modelo @id_modelo = 1, @nuevo_precio = 3850000.00;

SELECT COUNT(*) AS historial_total_despues FROM dbo.historial_de_precio;
SELECT id_modelo, precio_lista AS precio_restaurado FROM dbo.modelo_motocicleta WHERE id_modelo = 1;
GO

-- ============================================================================
-- 2. trg_auditoria_venta: venta demo con chasis KAWZ400001 (modelo 14)
--    Cliente 40234567 (descuento 0 % explicito), vendedor 32109876,
--    accesorio 2 x 1 (Casco abierto, $98.000).
--    precio_venta_moto = 10.500.000, monto_total = 10.598.000.
-- ============================================================================
PRINT '=== AUDITORIA VENTA 1. Estado inicial ===';
SELECT COUNT(*) AS auditoria_venta_antes FROM dbo.auditoria_venta;
GO

PRINT '=== AUDITORIA VENTA 2. sp_registrar_venta (INSERT en venta) ===';
DECLARE @cod_venta INT;

EXEC dbo.sp_registrar_venta
    @dni_cliente          = 40234567,
    @dni_vendedor         = 32109876,
    @numero_chasis        = 'KAWZ400001',
    @metodo_pago          = 'efectivo',
    @porcentaje_descuento = 0.00,
    @accesorios_json      = N'[{"id_accesorio":2,"cantidad":1}]',
    @cod_venta            = @cod_venta OUTPUT;

SELECT @cod_venta AS cod_venta_generado;

SELECT
    cod_venta,
    numero_chasis,
    precio_venta_moto,
    monto_total,
    estado
FROM dbo.venta
WHERE cod_venta = @cod_venta;

SELECT
    id_auditoria,
    cod_venta,
    accion,
    estado_anterior,
    estado_nuevo,
    monto_anterior,
    monto_nuevo,
    usuario,
    fecha_hora
FROM dbo.auditoria_venta
WHERE cod_venta = @cod_venta
ORDER BY id_auditoria;
GO

PRINT '=== AUDITORIA VENTA 3. Cancelacion de la venta demo (UPDATE en venta) ===';
DECLARE @cod_venta INT;

SELECT @cod_venta = cod_venta
FROM dbo.venta
WHERE numero_chasis = 'KAWZ400001'
  AND estado = 'efectuada';

EXEC dbo.sp_cambiar_estado_venta @cod_venta = @cod_venta, @nuevo_estado = 'cancelada';

SELECT
    cod_venta,
    estado,
    monto_total
FROM dbo.venta
WHERE cod_venta = @cod_venta;

SELECT
    id_auditoria,
    cod_venta,
    accion,
    estado_anterior,
    estado_nuevo,
    monto_anterior,
    monto_nuevo,
    usuario,
    fecha_hora
FROM dbo.auditoria_venta
WHERE cod_venta = @cod_venta
ORDER BY id_auditoria;

-- Reintegro de stock verificado por la cancelacion.
SELECT id_modelo, stock_disponible AS stock_modelo_14 FROM dbo.modelo_motocicleta WHERE id_modelo = 14;
SELECT id_accesorio, stock AS stock_accesorio_2 FROM dbo.accesorio WHERE id_accesorio = 2;
GO

PRINT '=== AUDITORIA VENTA 4. Limpieza de la venta demo (DELETE en venta) ===';
DECLARE @cod_venta INT;

SELECT @cod_venta = cod_venta
FROM dbo.venta
WHERE numero_chasis = 'KAWZ400001'
  AND estado = 'cancelada';

DELETE FROM dbo.detalle_venta_accesorio WHERE cod_venta = @cod_venta;
DELETE FROM dbo.venta WHERE cod_venta = @cod_venta;

SELECT
    id_auditoria,
    cod_venta,
    accion,
    estado_anterior,
    estado_nuevo,
    monto_anterior,
    monto_nuevo,
    usuario,
    fecha_hora
FROM dbo.auditoria_venta
WHERE cod_venta = @cod_venta
ORDER BY id_auditoria;

SELECT
    (SELECT COUNT(*) FROM dbo.venta WHERE numero_chasis = 'KAWZ400001') AS ventas_restantes_demo,
    (SELECT COUNT(*) FROM dbo.auditoria_venta WHERE cod_venta = @cod_venta) AS registros_auditoria_demo;
GO

-- ============================================================================
-- 3. trg_auditoria_cliente_estado: cliente 42111222 (Nicolas Duarte)
--    interesado -> comprador -> interesado
-- ============================================================================
PRINT '=== AUDITORIA CLIENTE 1. Estado inicial ===';
SELECT COUNT(*) AS auditoria_cliente_antes FROM dbo.auditoria_cliente;
SELECT dni_cliente, estado FROM dbo.cliente WHERE dni_cliente = 42111222;
GO

PRINT '=== AUDITORIA CLIENTE 2. interesado -> comprador ===';
UPDATE dbo.cliente
SET estado = 'comprador'
WHERE dni_cliente = 42111222;

SELECT
    id_auditoria,
    dni_cliente,
    estado_anterior,
    estado_nuevo,
    usuario,
    fecha_hora
FROM dbo.auditoria_cliente
WHERE dni_cliente = 42111222
ORDER BY id_auditoria;
GO

PRINT '=== AUDITORIA CLIENTE 3. UPDATE que NO cambia el estado ===';
UPDATE dbo.cliente
SET estado = 'comprador'
WHERE dni_cliente = 42111222;

SELECT COUNT(*) AS registros_tras_update_sin_cambio
FROM dbo.auditoria_cliente
WHERE dni_cliente = 42111222;
GO

PRINT '=== AUDITORIA CLIENTE 4. Restauracion: comprador -> interesado ===';
UPDATE dbo.cliente
SET estado = 'interesado'
WHERE dni_cliente = 42111222;

SELECT
    COUNT(*) AS auditoria_cliente_registros_demo,
    (SELECT estado FROM dbo.cliente WHERE dni_cliente = 42111222) AS estado_restaurado
FROM dbo.auditoria_cliente
WHERE dni_cliente = 42111222;
GO

-- ============================================================================
-- 4. Estado final
-- ============================================================================
PRINT '=== Estado final de la base ===';
SELECT
    (SELECT COUNT(*) FROM dbo.historial_de_precio) AS historial_total,
    (SELECT COUNT(*) FROM dbo.auditoria_venta) AS auditoria_venta_total,
    (SELECT COUNT(*) FROM dbo.auditoria_cliente) AS auditoria_cliente_total,
    (SELECT stock_disponible FROM dbo.modelo_motocicleta WHERE id_modelo = 14) AS stock_modelo_14,
    (SELECT stock FROM dbo.accesorio WHERE id_accesorio = 2) AS stock_accesorio_2,
    (SELECT precio_lista FROM dbo.modelo_motocicleta WHERE id_modelo = 1) AS precio_modelo_1;

SELECT name, type_desc
FROM sys.objects
WHERE schema_id = SCHEMA_ID('dbo')
  AND (type = 'TR'
       OR name IN ('auditoria_venta', 'auditoria_cliente'))
ORDER BY type_desc, name;
GO

PRINT '=== Fin de las pruebas de triggers ===';
GO
