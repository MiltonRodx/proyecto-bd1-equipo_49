-- ============================================================================
-- ETAPA IV - 01 FACTURA / DETALLE DE VENTA (VERSIÓN OPTIMIZADA Y DOCUMENTADA)
-- Sistema: X Motors - Grupo 49. Motor: SQL Server. Base [X MOTORS] cargada.
-- Descripción: Simula la emisión de una factura completa dividida en tres partes:
--   1. Encabezado de la venta (Datos de la transacción, cliente, vendedor y moto).
--   2. Detalle de accesorios (Ítems adicionales vinculados a la venta).
--   3. Verificación de integridad financiera (Auditoría cruzada de montos).
-- ============================================================================

-- Seleccionamos explícitamente la base de datos de trabajo para evitar errores de contexto
USE [X MOTORS];
GO

-- Declaramos una variable de tipo entero para almacenar el código de venta a consultar.
-- Facilita las pruebas cambiando únicamente este valor (Ej: 5 con accesorios, 4 cancelada, etc.)
DECLARE @cod_venta INT = 5;


-- ============================================================================
-- BLOQUE 1: ENCABEZADO DE LA FACTURA
-- ============================================================================
-- Este bloque recopila la información general de la operación comercial uniendo
-- las tablas transaccionales con las entidades de negocio y personas.
SELECT
  v.cod_venta,                        -- Identificador único de la venta
  v.fecha,                            -- Fecha y hora en que se realizó la operación
  v.estado,                           -- Estado actual de la venta (Ej: Efectuada, Cancelada)
  v.metodo_pago,                      -- Medio de pago utilizado por el cliente
  
  -- Concatenamos el nombre y apellido de la persona asociada al DNI del cliente
  pc.nombre + ' ' + pc.apellido AS cliente,
  
  -- Concatenamos el nombre y apellido de la persona asociada al DNI del vendedor
  pv.nombre + ' ' + pv.apellido AS vendedor,
  
  mo.marca,                           -- Marca de la motocicleta vendida
  mo.nombre_modelo AS modelo,         -- Nombre comercial del modelo
  m.numero_chasis,                    -- Identificador físico único de chasis (Dominio/Chasis)
  m.numero_motor,                     -- Número identificatorio del motor de la moto
  v.precio_venta_moto,                -- Precio pactado de la motocicleta base
  v.monto_total                       -- Monto total registrado de la transacción
FROM venta AS v
  -- Vinculamos la venta con su respectivo cliente a través del DNI
  JOIN cliente AS c ON c.dni_cliente = v.dni_cliente
  -- Unimos con la tabla general 'persona' para obtener los datos de identidad del cliente
  JOIN persona AS pc ON pc.dni = c.dni_cliente
  -- Vinculamos la venta con el vendedor que la concretó
  JOIN vendedor AS vd ON vd.dni_vendedor = v.dni_vendedor
  -- Unimos con la tabla general 'persona' para obtener los datos de identidad del vendedor
  JOIN persona AS pv ON pv.dni = vd.dni_vendedor
  -- Vinculamos la moto asociada a la venta mediante su número de chasis
  JOIN motocicleta AS m ON m.numero_chasis = v.numero_chasis
  -- Obtenemos las especificaciones del modelo de la moto
  JOIN modelo_motocicleta AS mo ON mo.id_modelo = m.id_modelo
WHERE v.cod_venta = @cod_venta;     -- Filtramos estrictamente por el código de venta configurado


-- ============================================================================
-- BLOQUE 2: LÍNEAS DE DETALLE (ACCESORIOS)
-- ============================================================================
-- Devuelve un renglón por cada accesorio adquirido. Si la venta no posee accesorios
-- (cumpliendo con la Regla de Negocio RN10), este conjunto de resultados se retorne vacío.
SELECT
  a.id_accesorio,                     -- Código del accesorio
  a.descripcion,                      -- Detalle o nombre del accesorio
  a.categoria,                        -- Categoría a la que pertenece el accesorio
  d.cantidad,                         -- Cantidad de unidades adquiridas de ese accesorio
  d.precio_pactado,                   -- Precio unitario acordado al momento de la venta
  
  -- Calculamos el subtotal de la línea casteando explícitamente a DECIMAL(12,2) 
  -- para mantener precisión monetaria exacta en la multiplicación.
  CAST(d.cantidad * d.precio_pactado AS DECIMAL(12,2)) AS subtotal_linea
FROM detalle_venta_accesorio AS d
  -- Unimos con el catálogo de accesorios para extraer sus descripciones y categorías
  JOIN accesorio AS a ON a.id_accesorio = d.id_accesorio
WHERE d.cod_venta = @cod_venta        -- Filtramos por la venta en curso
ORDER BY a.descripcion;               -- Ordenamos alfabéticamente los accesorios por claridad visual


-- ============================================================================
-- BLOQUE 3: VERIFICACIÓN Y AUDITORÍA FINANCIERA (CON CTE)
-- ============================================================================
-- Utilizamos una Expresión de Tabla Común (CTE) para aislar temporalmente el cálculo
-- de la sumatoria de los accesorios de la venta seleccionada.
WITH AccesoriosCalculados AS (
  SELECT 
    d.cod_venta,
    -- Multiplicamos cantidad por precio pactado, sumamos todas las líneas de accesorios,
    -- y si el resultado es NULL (porque no tiene accesorios), devolvemos 0 de manera segura con ISNULL.
    ISNULL(SUM(CAST(d.cantidad * d.precio_pactado AS DECIMAL(12,2))), 0) AS total_accesorios
  FROM detalle_venta_accesorio AS d
  WHERE d.cod_venta = @cod_venta
  GROUP BY d.cod_venta
)
SELECT
  v.cod_venta,
  v.precio_venta_moto,
  
  -- Si la CTE no devuelve filas para esta venta (ventas sin accesorios), 
  -- aseguramos que muestre 0 con un ISNULL adicional como reaseguro.
  ISNULL(ac.total_accesorios, 0) AS total_accesorios,
  
  -- Sumamos el valor de la moto más el total de los accesorios calculados, 
  -- forzando el tipo DECIMAL(12,2) para estandarizar decimales.
  CAST(v.precio_venta_moto + ISNULL(ac.total_accesorios, 0) AS DECIMAL(12,2)) AS total_calculado,
  
  v.monto_total AS total_guardado,    -- El valor histórico registrado en la cabecera de la tabla venta
  
  -- Estructura condicional CASE para auditoría automática:
  -- Compara estrictamente si el valor calculado coincide con el monto total persistido.
  -- Si son idénticos devuelve 'OK', de lo contrario arroja 'DIFERENCIA'.
  CASE 
    WHEN CAST(v.precio_venta_moto + ISNULL(ac.total_accesorios, 0) AS DECIMAL(12,2)) = v.monto_total
      THEN 'OK' 
    ELSE 'DIFERENCIA (Revisar inconsistencia de montos)' 
  END AS control_integridad
FROM venta AS v
  -- Realizamos un LEFT JOIN con la CTE para contemplar incluso aquellas ventas que no posean accesorios
  LEFT JOIN AccesoriosCalculados AS ac ON ac.cod_venta = v.cod_venta
WHERE v.cod_venta = @cod_venta;
GO