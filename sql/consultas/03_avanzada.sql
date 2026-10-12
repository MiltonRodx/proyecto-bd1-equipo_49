-- ============================================================================
-- ETAPA IV - 03 CONSULTAS AVANZADAS (JOINs + HAVING / SUBCONSULTAS) - REPARADO
-- Sistema: X Motors - Grupo 49. Motor: SQL Server. Base [X MOTORS] cargada.
-- Descripcion: Dos consultas de analisis de negocio con >=3 JOINs cada una.
--   1. Clientes recurrentes (HAVING) - Fidelizacion / VIP
--   2. Cotizaciones vencidas sin concretar (NOT EXISTS) - Oportunidades perdidas RN12
-- FIX: Consulta 3 usaba vd.legajo (no existe en vendedor) -> eliminado.
--      HAVING >= 1 -> >= 2 (coherente con el comentario "al menos 2 ventas").
-- ============================================================================

USE [X MOTORS];
GO


-- ============================================================================
-- CONSULTA 1: CLIENTES RECURRENTES (FIDELIZACION / VIP)
-- Regla de negocio: RN4 (historial de multiples compras por cliente)
-- Objetivo: Identificar clientes que compraron mas de 1 moto (ventas efectuadas)
-- Metricas: cantidad de motos, monto total, ticket promedio, primera/ultima compra
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
-- Regla de negocio: RN12 (cotizacion 7 dias) + RN5 (estado cliente)
-- Objetivo: Detectar cotizaciones expiradas donde el cliente NO compro ese modelo
-- Metricas: dias desde vencimiento, modelo cotizado, estado actual del cliente
-- Uso: Accion comercial - contactar cliente "interesado" o "en proceso de compra"
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
WHERE cot.fecha_vencimiento < GETDATE()  -- cotizacion vencida
  AND c.estado IN ('interesado', 'en proceso de compra')  -- cliente aun no comprador
  AND NOT EXISTS (
      -- Subconsulta correlacionada: verifica si el cliente YA compro ese modelo
      SELECT 1
      FROM venta AS v
      JOIN motocicleta AS m ON m.numero_chasis = v.numero_chasis
      WHERE v.dni_cliente = c.dni_cliente
        AND v.estado = 'efectuada'
        AND m.id_modelo = cot.id_modelo
  )
ORDER BY dias_desde_vencimiento DESC, cot.precio_cotizado DESC;
GO

-- ============================================================================
-- CONSULTA 3: VENDEDORES ESTRELLA CON VENTAS DE ACCESORIOS
-- Objetivo: Detectar vendedores que hayan concretado al menos 2 ventas 'efectuadas'
-- que incluyan de forma obligatoria ventas de accesorios adicionales.
-- ============================================================================
SELECT
    pv.dni AS dni_vendedor,
    pv.nombre + ' ' + pv.apellido AS vendedor,
    COUNT(DISTINCT v.cod_venta) AS ventas_con_accesorios,
    SUM(dva.cantidad * dva.precio_pactado) AS total_recaudado_accesorios
FROM persona AS pv
JOIN vendedor AS vd ON vd.dni_vendedor = pv.dni
JOIN venta AS v ON v.dni_vendedor = vd.dni_vendedor AND v.estado = 'efectuada'
JOIN detalle_venta_accesorio AS dva ON dva.cod_venta = v.cod_venta
GROUP BY pv.dni, pv.nombre, pv.apellido
HAVING COUNT(DISTINCT v.cod_venta) >= 2
ORDER BY ventas_con_accesorios DESC, total_recaudado_accesorios DESC;
GO


-- ============================================================================
-- CONSULTA 4: MOTOS FISICAS SIN HISTORIAL COMERCIAL (STOCK ESTANCADO)
-- Objetivo: Listar aquellas motocicletas fisicas dadas de alta en stock que
-- NOT EXISTS: No registren ninguna cotizacion previa ni tampoco ninguna venta.
-- ============================================================================
SELECT
    m.numero_chasis,
    m.numero_motor,
    mo.marca,
    mo.nombre_modelo,
    mo.precio_lista
FROM motocicleta AS m
JOIN modelo_motocicleta AS mo ON mo.id_modelo = m.id_modelo
WHERE NOT EXISTS (
        -- Verifica que la moto nunca haya sido cotizada
        SELECT 1
        FROM cotizacion AS cot
        WHERE cot.id_modelo = m.id_modelo
    )
  AND NOT EXISTS (
        -- Verifica que la moto nunca haya sido vendida
        SELECT 1
        FROM venta AS v
        WHERE v.numero_chasis = m.numero_chasis
    )
ORDER BY mo.marca, mo.nombre_modelo;
GO
