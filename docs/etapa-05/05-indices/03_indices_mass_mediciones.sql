-- =====================================================================
-- X Motors - Etapa V - Tema 5: Optimizacion de consultas (indices)
-- Archivo: docs/etapa-05/05-indices/03_indices_mass_mediciones.sql
--
-- Objetivo: ejecutar sobre dbo.venta_historica_prueba (mas de 1.000.000
--           de filas, poblada por 02_indices_mass_load.sql) los tres
--           escenarios de medicion de la consigna v2:
--
--             1) sin indice            -> Table Scan
--             2) indice agrupado fecha -> Clustered Index Seek
--             3) indice con cobertura  -> Index Seek (sin lookup)
--
--           Para cada escenario se registran:
--             - plan de ejecucion (SET SHOWPLAN_TEXT ON)
--             - lecturas logicas   (SET STATISTICS IO ON)
--             - tiempo CPU / total (SET STATISTICS TIME ON)
--
-- Base: [X MOTORS]
-- Uso:  sqlcmd -S <server> -d "X MOTORS" -i 03_indices_mass_mediciones.sql
--
-- Nota: la consulta de medicion se envuelto en COUNT_BIG(*)/SUM(importe)
--       para que la salida del registro sea compacta (la consigna supone
--       documentar metricas, no volcar millones de filas); el plan de
--       acceso (SELECT con SHOWPLAN_TEXT) SI es la consulta literal con
--       la lista de columnas del guia y muestra el mismo patron de
--       Scan/Seek que se pretende demostrar.
-- =====================================================================

SET NOCOUNT ON;

USE [X MOTORS];
GO

-- -------------------------------------------------------------------
-- 0. Asegurar punto de partida limpio: sin ningun indice de usuario
-- -------------------------------------------------------------------
DROP INDEX IF EXISTS ix_venta_historica_prueba_fecha
ON dbo.venta_historica_prueba;

DROP INDEX IF EXISTS ix_venta_historica_prueba_cobertura
ON dbo.venta_historica_prueba;
GO

SELECT COUNT(*) AS idx_previos
FROM sys.indexes
WHERE object_id = OBJECT_ID('dbo.venta_historica_prueba')
  AND is_primary_key = 0
  AND index_id > 0;
GO

SET STATISTICS TIME ON;
SET STATISTICS IO ON;
GO

-- ===================================================================
-- ESCENARIO 1: SIN INDICE
-- Esperado: operacion principal = Table Scan
-- ===================================================================
PRINT '=== ESCENARIO 1: SIN INDICE (heap) ===';
GO

SET SHOWPLAN_TEXT ON;
GO

SELECT id_venta, fecha_venta, importe
FROM dbo.venta_historica_prueba
WHERE fecha_venta BETWEEN '2023-01-01' AND '2023-03-31';
GO

SET SHOWPLAN_TEXT OFF;
GO

SELECT COUNT_BIG(*) AS filas_filtradas,
       CAST(SUM(importe) AS DECIMAL(14,2)) AS importe_total
FROM dbo.venta_historica_prueba
WHERE fecha_venta BETWEEN '2023-01-01' AND '2023-03-31';
GO

-- ===================================================================
-- ESCENARIO 2: INDICE AGRUPADO POR FECHA
-- Esperado: operacion principal = Clustered Index Seek (+ Lookup)
-- ===================================================================
PRINT '=== ESCENARIO 2: INDICE AGRUPADO POR FECHA ===';

CREATE CLUSTERED INDEX ix_venta_historica_prueba_fecha
ON dbo.venta_historica_prueba (fecha_venta);
GO

SET SHOWPLAN_TEXT ON;
GO

SELECT id_venta, fecha_venta, importe
FROM dbo.venta_historica_prueba
WHERE fecha_venta BETWEEN '2023-01-01' AND '2023-03-31';
GO

SET SHOWPLAN_TEXT OFF;
GO

SELECT COUNT_BIG(*) AS filas_filtradas,
       CAST(SUM(importe) AS DECIMAL(14,2)) AS importe_total
FROM dbo.venta_historica_prueba
WHERE fecha_venta BETWEEN '2023-01-01' AND '2023-03-31';
GO

-- ===================================================================
-- ESCENARIO 3: INDICE CON COBERTURA
-- Esperado: operacion principal = Index Seek, sin acceder a la tabla
-- ===================================================================
PRINT '=== ESCENARIO 3: INDICE CON COBERTURA (INCLUDE) ===';

DROP INDEX IF EXISTS ix_venta_historica_prueba_fecha
ON dbo.venta_historica_prueba;
GO

CREATE NONCLUSTERED INDEX ix_venta_historica_prueba_cobertura
ON dbo.venta_historica_prueba (fecha_venta)
INCLUDE (importe);
GO

SET SHOWPLAN_TEXT ON;
GO

SELECT fecha_venta, importe
FROM dbo.venta_historica_prueba
WHERE fecha_venta BETWEEN '2023-01-01' AND '2023-03-31';
GO

SET SHOWPLAN_TEXT OFF;
GO

SELECT COUNT_BIG(*) AS filas_filtradas,
       CAST(SUM(importe) AS DECIMAL(14,2)) AS importe_total
FROM dbo.venta_historica_prueba
WHERE fecha_venta BETWEEN '2023-01-01' AND '2023-03-31';
GO

-- ===================================================================
-- 4. Estado final: los indices activos de la tabla de pruebas
-- ===================================================================
PRINT '=== ESTADO FINAL ===';

SELECT name, type_desc, is_unique
FROM sys.indexes
WHERE object_id = OBJECT_ID('dbo.venta_historica_prueba')
  AND is_primary_key = 0
  AND index_id > 0
ORDER BY name;
GO

SELECT COUNT(*) AS cantidad_registros
FROM dbo.venta_historica_prueba;
GO
