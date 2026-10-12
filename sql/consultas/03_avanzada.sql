-- ============================================================================
-- ETAPA IV - 03 CONSULTAS AVANZADAS (JOINs + HAVING / SUBCONSULTAS)
-- Sistema: X Motors - Grupo 49. Motor: SQL Server. Base [X MOTORS] cargada.
-- Descripción: Dos consultas de análisis de negocio con ≥3 JOINs cada una.
--   1. Clientes recurrentes (HAVING) - Fidelización / VIP
--   2. Cotizaciones vencidas sin concretar (NOT EXISTS) - Oportunidades perdidas RN12
-- ============================================================================

USE [X MOTORS];
GO


-- ============================================================================
-- CONSULTA 1: CLIENTES RECURRENTES (FIDELIZACIÓN / VIP)
-- Regla de negocio: RN4 (historial de múltiples compras por cliente)
-- Objetivo: Identificar clientes que compraron más de 1 moto (ventas efectuadas)
-- Métricas: cantidad de motos, monto total, ticket promedio, primera/última compra
-- ============================================================================
SELECT 
    pc.dni AS dni_cliente,
    pc.nombre + ' ' + pc.apellido AS cliente,
    pc.email,
    pc.telefono,
    c.estado AS estado_cliente,
    COUNT(v.cod_venta) AS total_motos_compradas,
    SUM(v.monto_total) AS monto_total_historico,
    CAST(SUM(v.monto_total) / COUNT(v.cod_venta) AS DECIMAL(12,2)) AS ticket_promedio,
    MIN(v.fecha) AS primera_compra,
    MAX(v.fecha) AS ultima_compra
FROM persona AS pc
JOIN cliente AS c ON c.dni_cliente = pc.dni
JOIN venta AS v ON v.dni_cliente = c.dni_cliente AND v.estado = 'efectuada'
JOIN motocicleta AS m ON m.numero_chasis = v.numero_chasis
JOIN modelo_motocicleta AS mo ON mo.id_modelo = m.id_modelo
GROUP BY pc.dni, pc.nombre, pc.apellido, pc.email, pc.telefono, c.estado
HAVING COUNT(v.cod_venta) > 1
ORDER BY total_motos_compradas DESC, monto_total_historico DESC;
GO


-- ============================================================================
-- CONSULTA 2: COTIZACIONES VENCIDAS SIN CONCRETAR (OPORTUNIDADES PERDIDAS)
-- Regla de negocio: RN12 (cotización 7 días) + RN5 (estado cliente)
-- Objetivo: Detectar cotizaciones expiradas donde el cliente NO compró ese modelo
-- Métricas: días desde vencimiento, modelo cotizado, estado actual del cliente
-- Uso: Acción comercial - contactar cliente "interesado" o "en proceso de compra"
-- ============================================================================
SELECT 
    pc.dni AS dni_cliente,
    pc.nombre + ' ' + pc.apellido AS cliente,
    pc.email,
    pc.telefono,
    c.estado AS estado_actual_cliente,
    cot.id_cotizacion,
    cot.fecha_emision,
    cot.fecha_vencimiento,
    DATEDIFF(DAY, cot.fecha_vencimiento, GETDATE()) AS dias_desde_vencimiento,
    mo.marca + ' ' + mo.nombre_modelo AS modelo_cotizado,
    cot.precio_cotizado,
    mo.precio_lista AS precio_lista_actual,
    CAST(mo.precio_lista - cot.precio_cotizado AS DECIMAL(12,2)) AS diferencia_precio
FROM persona AS pc
JOIN cliente AS c ON c.dni_cliente = pc.dni
JOIN cotizacion AS cot ON cot.dni_cliente = c.dni_cliente
JOIN modelo_motocicleta AS mo ON mo.id_modelo = cot.id_modelo
WHERE cot.fecha_vencimiento < GETDATE()  -- cotización vencida
  AND c.estado IN ('interesado', 'en proceso de compra')  -- cliente aún no comprador
  AND NOT EXISTS (
      -- Subconsulta correlacionada: verifica si el cliente YA compró ese modelo
      SELECT 1
      FROM venta AS v
      JOIN motocicleta AS m ON m.numero_chasis = v.numero_chasis
      WHERE v.dni_cliente = c.dni_cliente
        AND v.estado = 'efectuada'
        AND m.id_modelo = cot.id_modelo
  )
ORDER BY dias_desde_vencimiento DESC, cot.precio_cotizado DESC;
GO