-- ============================================================================
-- ETAPA V - TEMA 3: TRIGGER DE AUDITORIA DE VENTAS
-- Archivo: docs/etapa-05/03-triggers-auditoria/03_trg_auditoria_venta.sql
-- Sistema: X Motors - Base de Datos I - Grupo 49 - FaCENA (UNNE)
--
-- Registra en auditoria_venta cada INSERT, UPDATE y DELETE sobre dbo.venta.
-- Solo inserta; nunca modifica las tablas de negocio.
-- Set-based con inserted/deleted: soporta operaciones multi-fila.
-- Un UPDATE solo se audita si cambia estado o monto_total.
-- ============================================================================

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

USE [X MOTORS];
GO

CREATE OR ALTER TRIGGER dbo.trg_auditoria_venta
ON dbo.venta
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    -- inserted solo  -> INSERT
    -- deleted solo   -> DELETE
    -- ambas          -> UPDATE
    -- El FULL OUTER JOIN cubre los tres casos en una sola sentencia; las
    -- columnas "anterior" salen NULL en un INSERT y las "nuevas" en un DELETE.
    INSERT INTO dbo.auditoria_venta (
        cod_venta,
        accion,
        estado_anterior,
        estado_nuevo,
        monto_anterior,
        monto_nuevo
    )
    SELECT
        COALESCE(i.cod_venta, d.cod_venta),
        CASE
            WHEN d.cod_venta IS NULL THEN 'INSERT'
            WHEN i.cod_venta IS NULL THEN 'DELETE'
            ELSE 'UPDATE'
        END,
        d.estado,
        i.estado,
        d.monto_total,
        i.monto_total
    FROM inserted AS i
    FULL OUTER JOIN deleted AS d
        ON d.cod_venta = i.cod_venta
    WHERE d.cod_venta IS NULL            -- INSERT
       OR i.cod_venta IS NULL            -- DELETE
       OR EXISTS (                       -- UPDATE: solo si algo auditado cambio
            SELECT i.estado, i.monto_total
            EXCEPT
            SELECT d.estado, d.monto_total
          );
END;
GO

PRINT '03_trg_auditoria_venta.sql ejecutado: trg_auditoria_venta creado.';
GO