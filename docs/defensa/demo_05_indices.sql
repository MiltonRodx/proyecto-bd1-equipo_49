-- ============================================================================
-- DEMO 5: INDICES Y OPTIMIZACION (X Motors)
-- COMO EJECUTAR EN DBEAVER: Ctrl+A (seleccionar todo) y Ctrl+Enter.
-- NO usar Alt+X: corta el script en pedazos y las variables se pierden.
-- Solo hace SELECTs: nunca modifica datos. Es re-ejecutable.
-- Requiere: DDL + DML + docs/etapa-05/05-indices/01_indices.sql ejecutado
--           (crea los indices de cobertura sobre venta).
--
-- QUE ES (leer en voz alta):
--   Un indice es una estructura ordenada (un arbol B) que el motor usa para
--   encontrar las filas sin recorrer la tabla entera. Un indice clustered es
--   el orden fisico de la tabla; los nonclustered apuntan a las filas.
--
-- QUE PROBLEMA RESUELVE EN X MOTORS (leer en voz alta):
--   Los reportes filtran venta por fecha+estado o por cliente: sin indice el
--   motor escanea la tabla entera; con el indice, lee solo lo que necesita.
--   Con pocas filas la diferencia se ve poco; con 1.000.000 de filas (prueba
--   de escala del tema) hay milisegundos contra segundos.
--
-- RESULTADOS (pestañas, en orden):
--   1 indices que existen sobre venta | 2 comparacion SIN indice vs CON indice
--
-- COMO SE COMPARA: el mismo reporte dos veces.
--   WITH (INDEX(0))          -> fuerza recorrer la tabla entera (sin indice)
--   WITH (INDEX(nombre_ix))  -> fuerza usar nuestro indice
--   Se mide en "lecturas logicas" (paginas leidas): menos lecturas = menos
--   trabajo = mas rapido. Los milisegundos son orientativos.
-- ============================================================================

USE [X MOTORS];

SET NOCOUNT ON;

-- Guarda: si no ejecutaste 01_indices.sql, avisar y cortar.
IF INDEXPROPERTY(OBJECT_ID('dbo.venta'), 'ix_venta_fecha_estado', 'IndexID') IS NULL
   OR INDEXPROPERTY(OBJECT_ID('dbo.venta'), 'ix_venta_cliente_fecha', 'IndexID') IS NULL
BEGIN
    SELECT 'Faltan los indices: ejecuta primero docs/etapa-05/05-indices/01_indices.sql' AS aviso;
    RETURN;
END;

DECLARE @filas_venta INT = (SELECT COUNT(*) FROM dbo.venta);
DECLARE @r0 BIGINT, @r1 BIGINT;
DECLARE @t0 DATETIME2(7), @t1 DATETIME2(7);
DECLARE @n INT, @filas INT;
DECLARE @m DECIMAL(18,2);
DECLARE @cod INT, @f DATE, @mo DECIMAL(18,2);

DECLARE @res TABLE (
    orden            INT IDENTITY(1,1),
    reporte          VARCHAR(40),
    variante         VARCHAR(30),
    filas_en_venta   INT,
    filas_resultado  INT,
    lecturas_logicas BIGINT,
    tiempo_ms        DECIMAL(10,2)
);

-- ============================================================================
-- 1. ANTES: que indices hay sobre venta (clave = por que columnas ordena;
--    incluye = columnas extra guardadas en el indice para no ir a la tabla)
-- ============================================================================
SELECT '1. INDICES SOBRE venta' AS paso,
       i.name AS index_name, i.type_desc,
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
-- 2. EJECUCION - REPORTE 1: ventas efectuadas del periodo
--    (usa ix_venta_fecha_estado: fecha + estado)
-- ============================================================================

-- 2a. SIN indice: recorre toda la tabla
SET @r0 = (SELECT logical_reads FROM sys.dm_exec_requests WHERE session_id = @@SPID);
SET @t0 = SYSDATETIME();
SELECT @n = COUNT(*), @m = SUM(v.monto_total)
FROM dbo.venta AS v WITH (INDEX(0))
WHERE v.fecha BETWEEN '2026-01-01' AND '2026-12-31'
  AND v.estado = 'efectuada';
SET @filas = @n;
SET @t1 = SYSDATETIME();
SET @r1 = (SELECT logical_reads FROM sys.dm_exec_requests WHERE session_id = @@SPID);
INSERT @res (reporte, variante, filas_en_venta, filas_resultado, lecturas_logicas, tiempo_ms)
VALUES ('Reporte del periodo', 'SIN indice (scan)', @filas_venta, @filas,
        @r1 - @r0, DATEDIFF(MICROSECOND, @t0, @t1) / 1000.0);

-- 2b. CON indice
SET @r0 = (SELECT logical_reads FROM sys.dm_exec_requests WHERE session_id = @@SPID);
SET @t0 = SYSDATETIME();
SELECT @n = COUNT(*), @m = SUM(v.monto_total)
FROM dbo.venta AS v WITH (INDEX(ix_venta_fecha_estado))
WHERE v.fecha BETWEEN '2026-01-01' AND '2026-12-31'
  AND v.estado = 'efectuada';
SET @filas = @n;
SET @t1 = SYSDATETIME();
SET @r1 = (SELECT logical_reads FROM sys.dm_exec_requests WHERE session_id = @@SPID);
INSERT @res (reporte, variante, filas_en_venta, filas_resultado, lecturas_logicas, tiempo_ms)
VALUES ('Reporte del periodo', 'CON indice', @filas_venta, @filas,
        @r1 - @r0, DATEDIFF(MICROSECOND, @t0, @t1) / 1000.0);

-- ============================================================================
-- 2. EJECUCION - REPORTE 2: historial de compras de un cliente
--    (usa ix_venta_cliente_fecha: cliente + fecha; ademas evita el ORDER BY)
-- ============================================================================

-- 2c. SIN indice
SET @r0 = (SELECT logical_reads FROM sys.dm_exec_requests WHERE session_id = @@SPID);
SET @t0 = SYSDATETIME();
SELECT @cod = cod_venta, @f = fecha, @mo = monto_total
FROM dbo.venta WITH (INDEX(0))
WHERE dni_cliente = 30456781
ORDER BY fecha;
SET @filas = @@ROWCOUNT;
SET @t1 = SYSDATETIME();
SET @r1 = (SELECT logical_reads FROM sys.dm_exec_requests WHERE session_id = @@SPID);
INSERT @res (reporte, variante, filas_en_venta, filas_resultado, lecturas_logicas, tiempo_ms)
VALUES ('Historial de un cliente', 'SIN indice (scan)', @filas_venta, @filas,
        @r1 - @r0, DATEDIFF(MICROSECOND, @t0, @t1) / 1000.0);

-- 2d. CON indice
SET @r0 = (SELECT logical_reads FROM sys.dm_exec_requests WHERE session_id = @@SPID);
SET @t0 = SYSDATETIME();
SELECT @cod = cod_venta, @f = fecha, @mo = monto_total
FROM dbo.venta WITH (INDEX(ix_venta_cliente_fecha))
WHERE dni_cliente = 30456781
ORDER BY fecha;
SET @filas = @@ROWCOUNT;
SET @t1 = SYSDATETIME();
SET @r1 = (SELECT logical_reads FROM sys.dm_exec_requests WHERE session_id = @@SPID);
INSERT @res (reporte, variante, filas_en_venta, filas_resultado, lecturas_logicas, tiempo_ms)
VALUES ('Historial de un cliente', 'CON indice', @filas_venta, @filas,
        @r1 - @r0, DATEDIFF(MICROSECOND, @t0, @t1) / 1000.0);

-- ============================================================================
-- 3. DESPUES: la comparacion (para leer de corrido en la defensa)
--    - filas_resultado IGUAL en las dos variantes = mismo resultado.
--    - lecturas_logicas: con indice tiene que ser MENOR o igual.
--    - Si filas_en_venta es chico (decenas/cientos), la diferencia es poca:
--      el indice se nota de verdad con volumen (prueba de 1.000.000 filas).
-- ============================================================================
SELECT '2. COMPARACION' AS paso,
       reporte, variante, filas_en_venta, filas_resultado,
       lecturas_logicas, tiempo_ms
FROM @res
ORDER BY orden;

-- ============================================================================
-- OPCIONAL (para ver en pantalla, sin tocar este script):
--   Seleccionar SOLO una de las consultas de arriba y pedir el plan de
--   ejecucion (en DBeaver: Ctrl+Shift+E, "Explain Execution Plan").
--   Con el indice se ve "Index Seek"; sin el, un "Scan" de toda la tabla.
--   Lecturas oficiales (si la columna lecturas da 0): SET STATISTICS IO ON;
--   y mirar el panel Output (Ctrl+Shift+O).
-- ============================================================================