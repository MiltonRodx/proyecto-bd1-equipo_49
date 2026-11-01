-- =====================================================================
-- X Motors - Etapa V - Tema 5: Optimizacion de consultas (indices)
-- Archivo: docs/etapa-05/05-indices/02_indices_mass_load.sql
--
-- Objetivo: crear la tabla de pruebas venta_historica_prueba y poblarla
--           con 1.000.000 de registros en una sola sentencia (carga
--           masiva por script, sin inserciones a mano), siguiendo la
--           consigna v2 del profesor (caso de VentaHistorica escalado
--           al negocio X Motors).
--
-- Base: [X MOTORS]
-- Uso:  sqlcmd -S <server> -d "X MOTORS" -i 02_indices_mass_load.sql
--
-- Idempotente: si la tabla de pruebas ya existe se dropea y se recrea.
-- La tabla es desechable: NO forma parte del modelo de negocio y no se
-- integra con el DDL/DML de las etapas anteriores.
-- =====================================================================

SET NOCOUNT ON; -- para que no devuelva 'N rows affected' el sqlserver

USE [X MOTORS];
GO

-- -------------------------------------------------------------------
-- 0. Limpieza previa (idempotencia)
-- -------------------------------------------------------------------
IF OBJECT_ID('dbo.venta_historica_prueba', 'U') IS NOT NULL
    DROP TABLE dbo.venta_historica_prueba;
GO

-- -------------------------------------------------------------------
-- 1. Tabla de pruebas (estilo VentaHistorica de la consigna, mapeada
--    al negocio X Motors: fecha e importe de una venta de moto).
--
--    Heap a proposito (sin PK): permite demostrar la evolucion completa
--    de acceso que pide la consigna:
--      1) sin indice          -> Table Scan
--      2) indice agrupado     -> Clustered Index Seek (+ Lookup)
--      3) indice de cobertura -> Index Seek (sin tocar la tabla)
-- -------------------------------------------------------------------
CREATE TABLE dbo.venta_historica_prueba (
    id_venta     BIGINT IDENTITY(1,1) NOT NULL,
    fecha_venta  DATE NOT NULL,
    importe      DECIMAL(12,2) NOT NULL
);
GO

-- -------------------------------------------------------------------
-- 2. Carga masiva: 1.000.000 de filas en una sola sentencia.
--
--    Numeros   : ROW_NUMBER() + CROSS JOIN (mismo patron del guia).
--    fecha     : 2021-01-01 + 0..1824 dias (5 anios), cubre 2023 para
--                el rango de medicion [2023-01-01 ; 2023-03-31].
--    importe   : simula montos de venta de motos (~50.000 a ~8.050.000).
-- -------------------------------------------------------------------
WITH Numeros AS (
    SELECT TOP (1000000)
        ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
    FROM sys.objects a
    CROSS JOIN sys.objects b
    CROSS JOIN sys.objects c
)
INSERT INTO dbo.venta_historica_prueba (fecha_venta, importe)
SELECT
    DATEADD(DAY, ABS(CHECKSUM(NEWID())) % 1825, '2021-01-01'),
    CAST(RAND(CHECKSUM(NEWID())) * 8000000.0 + 50000.0 AS DECIMAL(12,2))
FROM Numeros;
GO

-- -------------------------------------------------------------------
-- 3. Verificacion del lote cargado
-- -------------------------------------------------------------------
SELECT COUNT(*) AS cantidad_registros
FROM dbo.venta_historica_prueba;

SELECT
    MIN(fecha_venta) AS fecha_minima,
    MAX(fecha_venta) AS fecha_maxima
FROM dbo.venta_historica_prueba;

SELECT
    MIN(importe)                       AS importe_minimo,
    MAX(importe)                       AS importe_maximo,
    CAST(AVG(importe) AS DECIMAL(12,2)) AS importe_promedio
FROM dbo.venta_historica_prueba;
GO
