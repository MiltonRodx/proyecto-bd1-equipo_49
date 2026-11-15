-- ============================================================================
-- DEMO 5: INDICES Y OPTIMIZACION (Etapa V - Tema 5)
-- Archivo: docs/defensa/demo_05_indices.sql
-- Ejecutar COMPLETO (F5). Solo hace SELECTs: nunca modifica datos.
-- Requiere: DDL + DML + docs/etapa-05/05-indices/01_indices.sql ejecutado
--           (crea los 10 indices de cobertura).
--
-- QUÉ ES (para leer en voz alta):
--   Un indice es una estructura ordenada (un arbol B) que el motor usa para
--   encontrar las filas sin recorrer la tabla entera. Un indice clustered es
--   el orden fisico de la tabla; los nonclustered apuntan a las filas.
--
-- QUÉ PROBLEMA RESUELVE EN X MOTORS:
--   Los reportes filtran venta por fecha+estado o por cliente: sin indice el
--   motor escanea la tabla entera; con el indice, lee solo lo que necesita.
--   Con el lote chico la diferencia se ve poco, pero con 1.000.000 de filas
--   (prueba de escala del tema) hay milisegundos contra segundos.
-- ============================================================================

USE [X MOTORS];
GO

SET NOCOUNT ON;

-- ============================================================================
-- BLOQUE ANTES: que indices hay sobre venta (mira la columna index_name)
-- ============================================================================
SELECT i.name AS index_name, i.type_desc,
       STUFF((SELECT ', ' + c.name
              FROM sys.index_columns ic
              JOIN sys.columns c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
              WHERE ic.object_id = i.object_id AND ic.index_id = i.index_id
                AND ic.is_included_column = 0
              ORDER BY ic.key_ordinal
              FOR XML PATH('')), 1, 2, '') AS clave,
       STUFF((SELECT ', ' + c.name
              FROM sys.index_columns ic
              JOIN sys.columns c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
              WHERE ic.object_id = i.object_id AND ic.index_id = i.index_id
                AND ic.is_included_column = 1
              ORDER BY ic.index_column_id
              FOR XML PATH('')), 1, 2, '') AS incluye
FROM sys.indexes i
WHERE i.object_id = OBJECT_ID('dbo.venta') AND i.name IS NOT NULL;

-- ============================================================================
-- BLOQUE EJECUCION: el mismo reporte de ventas, con y sin indice.
-- STATISTICS IO muestra los "logical reads" en la pestana Mensajes:
-- menos lecturas = menos trabajo = mas rapido.
-- ============================================================================
SET STATISTICS IO ON;

-- 1) Reporte agregado del periodo (usa ix_venta_fecha_estado: fecha + estado)
SELECT COUNT(*) AS ventas, CAST(SUM(v.monto_total) AS DECIMAL(14,2)) AS facturado
FROM dbo.venta AS v
WHERE v.fecha BETWEEN '2026-01-01' AND '2026-12-31'
  AND v.estado = 'efectuada';

-- 2) Historial de compras de un cliente (usa ix_venta_cliente_fecha)
SELECT cod_venta, fecha, monto_total
FROM dbo.venta
WHERE dni_cliente = 30456781
ORDER BY fecha;

SET STATISTICS IO OFF;

-- ============================================================================
-- BLOQUE DESPUES: forzar el uso del indice para comparar lecturas.
-- Con pocas filas el optimizador puede elegir el scan (es mas barato leer
-- 30 filas a mano que abrir un indice); con millones de filas elige el
-- indice solo. El hint INDEX() deja ver la diferencia ya.
-- ============================================================================
SELECT COUNT(*) AS ventas, CAST(SUM(v.monto_total) AS DECIMAL(14,2)) AS facturado
FROM dbo.venta AS v WITH (INDEX(ix_venta_fecha_estado))
WHERE v.fecha BETWEEN '2026-01-01' AND '2026-12-31'
  AND v.estado = 'efectuada';
GO

-- ============================================================================
-- PARA VER EN PANTALLA (opcional, 1 linea):
-- Ctrl+M (Incluir plan de ejecucion real) y re-ejecutar: en el plan se ve
--   Index Seek (usa el indice)  vs  Table Scan (recorre todo).
-- ============================================================================
PRINT 'DEMO 5 terminado: sin datos sucios. Se puede volver a ejecutar.';
GO
