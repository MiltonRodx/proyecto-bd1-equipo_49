-- ============================================================================
-- ETAPA V - TEMA 3: TRIGGER DE HISTORIAL DE PRECIOS (RN7)
-- Archivo: etapa_v/triggers_auditoria/02_trg_historial_precio_modelo.sql
-- Sistema: X Motors - Base de Datos I - Grupo 49 - FaCENA (UNNE)
--
-- Cada vez que cambia precio_lista de un modelo, registra el precio anterior
-- y el nuevo en historial_de_precio. Es la tabla de NEGOCIO que alimenta los
-- reportes de evolucion de precios (RN7), no una tabla de auditoria tecnica.
-- Set-based: soporta UPDATE de varias filas en una sola sentencia.
-- ============================================================================

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

    -- Solo actua si alguna fila cambio realmente el precio de lista.
    IF NOT EXISTS (
        SELECT 1
        FROM inserted AS i
        JOIN deleted AS d
            ON d.id_modelo = i.id_modelo
        WHERE ISNULL(i.precio_lista, -1) <> ISNULL(d.precio_lista, -1)
    )
        RETURN;

    INSERT INTO dbo.historial_de_precio (
        precio_nuevo,
        precio_anterior,
        fecha_modificacion,
        id_modelo
    )
    SELECT
        i.precio_lista,
        d.precio_lista,
        CAST(SYSDATETIME() AS DATE),
        i.id_modelo
    FROM inserted AS i
    JOIN deleted AS d
        ON d.id_modelo = i.id_modelo
    WHERE ISNULL(i.precio_lista, -1) <> ISNULL(d.precio_lista, -1);
END;
GO

PRINT '02_trg_historial_precio_modelo.sql ejecutado: trg_historial_precio_modelo creado.';
GO
