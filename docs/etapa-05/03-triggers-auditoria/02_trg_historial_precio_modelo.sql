-- ================================================================================
-- ETAPA V - TEMA 3: TRIGGER DE HISTORIAL DE PRECIOS (RN7)
-- Archivo: docs/etapa-05/03-triggers-auditoria/02_trg_historial_precio_modelo.sql
-- Sistema: X Motors - Base de Datos I - Grupo 49 - FaCENA (UNNE)
--
-- Cada vez que cambia precio_lista de un modelo, registra el precio anterior
-- y el nuevo en historial_de_precio. Es la tabla de NEGOCIO que alimenta los
-- reportes de evolucion de precios (RN7), no una tabla de auditoria tecnica.
-- Set-based: soporta UPDATE de varias filas en una sola sentencia.
-- ================================================================================

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

USE [X MOTORS];
GO

CREATE OR ALTER TRIGGER dbo.trg_historial_precio_modelo
ON dbo.modelo_motocicleta
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- Guard barato: muchos UPDATE solo tocan stock_disponible. Si precio_lista
    -- ni figura en el SET, no hay nada que registrar.
    IF NOT UPDATE(precio_lista)
        RETURN;

    DECLARE @fecha DATE = CAST(SYSDATETIME() AS DATE);

    -- UPDATE() es verdadero aunque el valor no cambie, por eso se compara igual.
    -- EXISTS (SELECT a EXCEPT SELECT b) es una comparacion "distinto de" que
    -- trata NULL como un valor mas (NULL vs NULL = igual, NULL vs 5 = distinto).
    INSERT INTO dbo.historial_de_precio (
        precio_nuevo,
        precio_anterior,
        fecha_modificacion,
        id_modelo
    )
    SELECT
        i.precio_lista,
        d.precio_lista,
        @fecha,
        i.id_modelo
    FROM inserted AS i
    JOIN deleted AS d
        ON d.id_modelo = i.id_modelo
    WHERE EXISTS (SELECT i.precio_lista EXCEPT SELECT d.precio_lista);
END;
GO

PRINT '02_trg_historial_precio_modelo.sql ejecutado: trg_historial_precio_modelo creado.';
GO