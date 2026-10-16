USE [X MOTORS];
GO

-- ============================================================================
-- REPORTE AGREGADO 1: VENTAS POR VENDEDOR
-- Incluye: vendedor, total ventas efectuadas, monto total facturado, ticket promedio
-- Filtros opcionales: @fecha_desde, @fecha_hasta (NULL = sin filtro)
-- ============================================================================
DECLARE @fecha_desde DATE = NULL;  -- Ej: '2026-01-01'
DECLARE @fecha_hasta DATE = NULL;  -- Ej: '2026-12-31'

SELECT 
    p.dni AS dni_vendedor,
    p.nombre + ' ' + p.apellido AS vendedor,
    COUNT(v.cod_venta) AS total_ventas_efectuadas,
    SUM(v.monto_total) AS monto_total_facturado,
    CASE WHEN COUNT(v.cod_venta) > 0 
         THEN SUM(v.monto_total) / COUNT(v.cod_venta) 
         ELSE 0 END AS ticket_promedio
FROM vendedor ven
JOIN persona p ON ven.dni_vendedor = p.dni
LEFT JOIN venta v ON ven.dni_vendedor = v.dni_vendedor 
    AND v.estado = 'efectuada'
    AND (@fecha_desde IS NULL OR v.fecha >= @fecha_desde)
    AND (@fecha_hasta IS NULL OR v.fecha <= @fecha_hasta)
GROUP BY p.dni, p.nombre, p.apellido
ORDER BY monto_total_facturado DESC;
GO


-- ============================================================================
-- REPORTE AGREGADO 2: VENTAS POR MODELO
-- Incluye: modelo, marca, unidades vendidas, monto total, precio promedio, stock actual
-- Filtros opcionales: @fecha_desde, @fecha_hasta (NULL = sin filtro)
-- ============================================================================
DECLARE @fecha_desde DATE = NULL;
DECLARE @fecha_hasta DATE = NULL;

SELECT 
    m.id_modelo,
    m.marca,
    m.nombre_modelo,
    COUNT(v.cod_venta) AS unidades_vendidas,
    SUM(v.precio_venta_moto) AS monto_total_motos,
    CASE WHEN COUNT(v.cod_venta) > 0 
         THEN SUM(v.precio_venta_moto) / COUNT(v.cod_venta) 
         ELSE 0 END AS precio_promedio_venta,
    m.stock_disponible AS stock_actual
FROM modelo_motocicleta m
LEFT JOIN motocicleta mot ON m.id_modelo = mot.id_modelo
LEFT JOIN venta v ON mot.numero_chasis = v.numero_chasis 
    AND v.estado = 'efectuada'
    AND (@fecha_desde IS NULL OR v.fecha >= @fecha_desde)
    AND (@fecha_hasta IS NULL OR v.fecha <= @fecha_hasta)
GROUP BY m.id_modelo, m.marca, m.nombre_modelo, m.stock_disponible
ORDER BY unidades_vendidas DESC, monto_total_motos DESC;
GO


-- ============================================================================
-- REPORTE AGREGADO 3: ACCESORIOS MÁS VENDIDOS
-- Incluye: accesorio, categoría, cantidad total vendida, ingreso total, precio promedio pactado, stock actual
-- Filtros opcionales: @fecha_desde, @fecha_hasta (NULL = sin filtro)
-- ============================================================================
DECLARE @fecha_desde DATE = NULL;
DECLARE @fecha_hasta DATE = NULL;

SELECT 
    a.id_accesorio,
    a.descripcion,
    a.categoria,
    SUM(dva.cantidad) AS cantidad_total_vendida,
    SUM(dva.cantidad * dva.precio_pactado) AS ingreso_total_accesorio,
    CASE WHEN SUM(dva.cantidad) > 0 
         THEN SUM(dva.cantidad * dva.precio_pactado) / SUM(dva.cantidad) 
         ELSE 0 END AS precio_promedio_pactado,
    a.stock AS stock_actual
FROM accesorio a
LEFT JOIN detalle_venta_accesorio dva ON a.id_accesorio = dva.id_accesorio
LEFT JOIN venta v ON dva.cod_venta = v.cod_venta 
    AND v.estado = 'efectuada'
    AND (@fecha_desde IS NULL OR v.fecha >= @fecha_desde)
    AND (@fecha_hasta IS NULL OR v.fecha <= @fecha_hasta)
GROUP BY a.id_accesorio, a.descripcion, a.categoria, a.stock
ORDER BY cantidad_total_vendida DESC, ingreso_total_accesorio DESC;
GO

-- ============================================================================
-- REPORTE AGREGADO 4: VENTAS POR MÉTODO DE PAGO
-- Incluye: método de pago, cantidad de ventas, monto total ingresado, porcentaje estimado
-- Filtros opcionales: @fecha_desde, @fecha_hasta (NULL = sin filtro)
-- ============================================================================
DECLARE @fecha_desde DATE = NULL;
DECLARE @fecha_hasta DATE = NULL;

SELECT 
    v.metodo_pago,
    COUNT(v.cod_venta) AS total_ventas,
    SUM(v.monto_total) AS monto_total_recaudado,
    CASE WHEN COUNT(v.cod_venta) > 0 
         THEN SUM(v.monto_total) / COUNT(v.cod_venta) 
         ELSE 0 END AS ticket_promedio_medio_pago
FROM venta v
WHERE v.estado = 'efectuada'
    AND (@fecha_desde IS NULL OR v.fecha >= @fecha_desde)
    AND (@fecha_hasta IS NULL OR v.fecha <= @fecha_hasta)
GROUP BY v.metodo_pago
ORDER BY monto_total_recaudado DESC;
GO

-- ============================================================================
-- REPORTE AGREGADO 5: TOP CLIENTES (RANKING DE COMPRAS)
-- Incluye: DNI, nombre y apellido del cliente, cantidad de motos compradas, dinero total gastado
-- Filtros opcionales: @fecha_desde, @fecha_hasta (NULL = sin filtro)
-- ============================================================================
DECLARE @fecha_desde DATE = NULL;
DECLARE @fecha_hasta DATE = NULL;

SELECT 
    c.dni_cliente,
    p.nombre + ' ' + p.apellido AS cliente,
    COUNT(v.cod_venta) AS motos_compradas,
    SUM(v.monto_total) AS inversion_total
FROM cliente c
JOIN persona p ON c.dni_cliente = p.dni
JOIN venta v ON c.dni_cliente = v.dni_cliente
WHERE v.estado = 'efectuada'
    AND (@fecha_desde IS NULL OR v.fecha >= @fecha_desde)
    AND (@fecha_hasta IS NULL OR v.fecha <= @fecha_hasta)
GROUP BY c.dni_cliente, p.nombre, p.apellido
ORDER BY inversion_total DESC, motos_compradas DESC;
GO

-- ============================================================================
-- REPORTE AGREGADO 6: EFECTIVIDAD DE COTIZACIONES POR MODELO
-- Incluye: modelo, cantidad de cotizaciones emitidas, cotizaciones concretadas y tasa de conversión %
-- Filtros opcionales: @fecha_desde, @fecha_hasta (NULL = sin filtro)
-- ============================================================================
DECLARE @fecha_desde DATE = NULL;  -- Ej: '2026-01-01'
DECLARE @fecha_hasta DATE = NULL;  -- Ej: '2026-12-31'

SELECT 
    mo.id_modelo,
    mo.marca,
    mo.nombre_modelo,
    COUNT(cot.id_cotizacion) AS total_cotizaciones_emitidas,
    COUNT(v.cod_venta) AS cotizaciones_concretadas_venta,
    CASE 
        WHEN COUNT(cot.id_cotizacion) > 0 
        THEN CAST((CAST(COUNT(v.cod_venta) AS FLOAT) / COUNT(cot.id_cotizacion)) * 100 AS DECIMAL(5,2))
        ELSE 0 
    END AS tasa_conversion_porcentaje
FROM modelo_motocicleta mo
LEFT JOIN cotizacion cot ON mo.id_modelo = cot.id_modelo
    AND (@fecha_desde IS NULL OR cot.fecha_emision >= @fecha_desde)
    AND (@fecha_hasta IS NULL OR cot.fecha_emision <= @fecha_hasta)
-- Relacionamos para ver si esa misma cotización derivó en una venta del cliente para ese modelo
LEFT JOIN venta v ON v.dni_cliente = cot.dni_cliente 
    AND v.estado = 'efectuada'
    AND EXISTS (
        SELECT 1 FROM motocicleta m 
        WHERE m.numero_chasis = v.numero_chasis AND m.id_modelo = cot.id_modelo
    )
GROUP BY mo.id_modelo, mo.marca, mo.nombre_modelo
ORDER BY tasa_conversion_porcentaje DESC, total_cotizaciones_emitidas DESC;
GO

-- ============================================================================
-- REPORTE AGREGADO 7: VENTAS POR UBICACIÓN GEOGRÁFICA (PROVINCIA / CIUDAD)
-- Incluye: provincia, ciudad, cantidad de operaciones, monto total facturado y ticket promedio
-- Filtros opcionales: @fecha_desde, @fecha_hasta (NULL = sin filtro)
-- ============================================================================
DECLARE @fecha_desde DATE = NULL;
DECLARE @fecha_hasta DATE = NULL;

SELECT 
    dc.provincia,
    dc.ciudad,
    COUNT(v.cod_venta) AS total_ventas,
    SUM(v.monto_total) AS monto_total_facturado,
    CASE 
        WHEN COUNT(v.cod_venta) > 0 
        THEN SUM(v.monto_total) / COUNT(v.cod_venta) 
        ELSE 0 
    END AS ticket_promedio
FROM direccion_cliente dc
JOIN cliente c ON dc.dni_cliente = c.dni_cliente
JOIN venta v ON c.dni_cliente = v.dni_cliente
WHERE v.estado = 'efectuada'
    AND (@fecha_desde IS NULL OR v.fecha >= @fecha_desde)
    AND (@fecha_hasta IS NULL OR v.fecha <= @fecha_hasta)
GROUP BY dc.provincia, dc.ciudad
ORDER BY monto_total_facturado DESC, total_ventas DESC;
GO

-- ============================================================================
-- REPORTE AGREGADO 8: STOCK FÍSICO DISPONIBLE Y TIEMPO EN INVENTARIO
-- Incluye: chasis, motor, marca, modelo, precio de lista y días de permanencia en stock
-- ============================================================================
SELECT 
    m.numero_chasis,
    m.numero_motor,
    mo.marca,
    mo.nombre_modelo,
    mo.cilindrada,
    mo.precio_lista
FROM motocicleta m
JOIN modelo_motocicleta mo ON m.id_modelo = mo.id_modelo
WHERE NOT EXISTS (
    -- Filtra solo las motos que NO tienen una venta en estado 'efectuada'
    SELECT 1 
    FROM venta v 
    WHERE v.numero_chasis = m.numero_chasis 
      AND v.estado = 'efectuada'
)
ORDER BY mo.precio_lista DESC;
GO
