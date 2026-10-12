-- ============================================================================
-- ETAPA IV - 01 FACTURA / DETALLE DE VENTA (VERSIÓN SIMPLE PARA EXPOSICIÓN)
-- Sistema: X Motors. Motor: SQL Server.
-- ============================================================================

USE [X MOTORS];
GO

-- Definimos la variable con el código de venta que queremos consultar
DECLARE @cod_venta INT = 5;

-- 1. ENCABEZADO: Datos generales de la venta, cliente, vendedor y moto
SELECT
  v.cod_venta,
  v.fecha,
  v.estado,
  v.metodo_pago,
  pc.nombre + ' ' + pc.apellido AS cliente,
  pv.nombre + ' ' + pv.apellido AS vendedor,
  mo.marca,
  mo.nombre_modelo AS modelo,
  m.numero_chasis,
  m.numero_motor,
  v.precio_venta_moto,
  v.monto_total
FROM venta AS v
  JOIN cliente AS c ON c.dni_cliente = v.dni_cliente
  JOIN persona AS pc ON pc.dni = c.dni_cliente
  JOIN vendedor AS vd ON vd.dni_vendedor = v.dni_vendedor
  JOIN persona AS pv ON pv.dni = vd.dni_vendedor
  JOIN motocicleta AS m ON m.numero_chasis = v.numero_chasis
  JOIN modelo_motocicleta AS mo ON mo.id_modelo = m.id_modelo
WHERE v.cod_venta = @cod_venta;

-- 2. DETALLE: Listado de accesorios comprados (si no tiene, no devuelve filas - RN10)
SELECT
  a.id_accesorio,
  a.descripcion,
  a.categoria,
  d.cantidad,
  d.precio_pactado,
  CAST(d.cantidad * d.precio_pactado AS DECIMAL(12,2)) AS subtotal_linea
FROM detalle_venta_accesorio AS d
  JOIN accesorio AS a ON a.id_accesorio = d.id_accesorio
WHERE d.cod_venta = @cod_venta
ORDER BY a.descripcion;

-- 3. VERIFICACIÓN: Comprueba que la moto + accesorios sumen exactamente el monto total guardado
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
FROM venta AS v
  LEFT JOIN detalle_venta_accesorio AS d ON d.cod_venta = v.cod_venta
WHERE v.cod_venta = @cod_venta
GROUP BY v.cod_venta, v.precio_venta_moto, v.monto_total;
GO
