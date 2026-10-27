-- ============================================================================
-- ETAPA V - EVIDENCIA: CONSULTAS DE MEDICION DE INDICES (ANEXO B)
-- Archivo: etapa_v/procedimientos_funciones/evidencias/04_indices_consultas.sql
--
-- Se ejecuta DOS veces sobre la misma sesion:
--   1. ANTES  : con los 10 indices NO existentes (se borran con IF EXISTS).
--   2. DESPUES: una vez ejecutado 04_indices.sql.
-- Compara lecturas logicas (SET STATISTICS IO) y tiempos (SET STATISTICS TIME).
-- Cada consulta justifica uno de los indices del anexo.
-- ============================================================================

SET NOCOUNT ON;
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
GO

USE [X MOTORS];
GO

PRINT '=== Indice 1: ix_venta_fecha_estado (ventas por periodo y estado) ===';
SELECT
    v.dni_vendedor,
    COUNT(*) AS cantidad_ventas,
    CAST(SUM(v.monto_total) AS DECIMAL(14,2)) AS monto_total
FROM dbo.venta AS v
WHERE v.fecha >= '2026-01-01'
  AND v.fecha <= '2026-12-31'
  AND v.estado = 'efectuada'
GROUP BY v.dni_vendedor
ORDER BY monto_total DESC;
GO

PRINT '=== Indice 2: ix_venta_cliente_fecha (historial de un cliente) ===';
SELECT
    v.cod_venta, v.fecha, v.estado, v.precio_venta_moto, v.monto_total
FROM dbo.venta AS v
WHERE v.dni_cliente = 35123903
ORDER BY v.fecha DESC;
GO

PRINT '=== Indice 3: ix_venta_vendedor_fecha (ranking de un vendedor) ===';
SELECT
    COUNT(*) AS ventas, CAST(SUM(v.monto_total) AS DECIMAL(14,2)) AS monto
FROM dbo.venta AS v
WHERE v.dni_vendedor = 31222333
  AND v.estado = 'efectuada';
GO

PRINT '=== Indice 4: ix_detalle_venta_accesorio_accesorio (accesorios mas vendidos) ===';
SELECT TOP (5)
    d.id_accesorio,
    a.descripcion,
    SUM(d.cantidad) AS unidades,
    CAST(SUM(d.cantidad * d.precio_pactado) AS DECIMAL(14,2)) AS facturacion
FROM dbo.detalle_venta_accesorio AS d
JOIN dbo.accesorio AS a ON a.id_accesorio = d.id_accesorio
GROUP BY d.id_accesorio, a.descripcion
ORDER BY unidades DESC;
GO

PRINT '=== Indices 5 y 6: ix_cotizacion_* (cotizaciones por cliente y vencidas) ===';
SELECT
    c.id_cotizacion, c.fecha_emision, c.fecha_vencimiento, c.precio_cotizado
FROM dbo.cotizacion AS c
WHERE c.dni_cliente = 35123903
ORDER BY c.fecha_vencimiento DESC;

SELECT COUNT(*) AS vencidas
FROM dbo.cotizacion AS c
WHERE c.fecha_vencimiento < CAST(SYSDATETIME() AS DATE);
GO

PRINT '=== Indice 7: ix_historial_precio_modelo_fecha (evolucion de precios) ===';
SELECT TOP (5)
    h.fecha_modificacion, h.precio_anterior, h.precio_nuevo
FROM dbo.historial_de_precio AS h
WHERE h.id_modelo = 1
ORDER BY h.fecha_modificacion DESC;
GO

PRINT '=== Indice 8: ix_motocicleta_modelo (stock fisico por modelo) ===';
SELECT
    m.numero_chasis, m.numero_motor
FROM dbo.motocicleta AS m
JOIN dbo.modelo_motocicleta AS mo ON mo.id_modelo = m.id_modelo
WHERE m.id_modelo = 11
  AND m.numero_chasis NOT IN (
      SELECT v.numero_chasis FROM dbo.venta AS v WHERE v.estado = 'efectuada'
  );
GO

PRINT '=== Indices 9 y 10: ix_provision_* (proveedores por producto) ===';
SELECT
    ac.id_accesorio,
    ac.descripcion,
    COUNT(DISTINCT pa.cuit_proveedor) AS proveedores
FROM dbo.accesorio AS ac
LEFT JOIN dbo.provision_accesorio AS pa
    ON pa.id_accesorio = ac.id_accesorio
WHERE ac.id_accesorio IN (1, 2, 3)
GROUP BY ac.id_accesorio, ac.descripcion
ORDER BY ac.id_accesorio;
GO
