-- ============================================================================
-- ETAPA V - TEMA 3: TRIGGER DE AUDITORIA DE VENTAS
-- Archivo: etapa_v/triggers_auditoria/03_trg_auditoria_venta.sql
-- Sistema: X Motors - Base de Datos I - Grupo 49 - FaCENA (UNNE)
--
-- Registra en auditoria_venta cada INSERT, UPDATE y DELETE sobre dbo.venta.
-- Solo inserta; nunca modifica las tablas de negocio.
-- Set-based con inserted/deleted: soporta operaciones multi-fila.
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

    -- 1. INSERT: una fila por cada venta nueva.
    IF EXISTS (SELECT 1 FROM inserted)
       AND NOT EXISTS (SELECT 1 FROM deleted)
    BEGIN
        INSERT INTO dbo.auditoria_venta (
            cod_venta,
            accion,
            estado_anterior,
            estado_nuevo,
            monto_anterior,
            monto_nuevo
        )
        SELECT
            i.cod_venta,
            'INSERT',
            NULL,
            i.estado,
            NULL,
            i.monto_total
        FROM inserted AS i;
    END;

    -- 2. DELETE: una fila por cada venta eliminada.
    IF EXISTS (SELECT 1 FROM deleted)
       AND NOT EXISTS (SELECT 1 FROM inserted)
    BEGIN
        INSERT INTO dbo.auditoria_venta (
            cod_venta,
            accion,
            estado_anterior,
            estado_nuevo,
            monto_anterior,
            monto_nuevo
        )
        SELECT
            d.cod_venta,
            'DELETE',
            d.estado,
            NULL,
            d.monto_total,
            NULL
        FROM deleted AS d;
    END;

    -- 3. UPDATE: una fila por cada venta actualizada, con el estado y el
    --    monto antes y despues.
    IF EXISTS (SELECT 1 FROM inserted) AND EXISTS (SELECT 1 FROM deleted)
    BEGIN
        INSERT INTO dbo.auditoria_venta (
            cod_venta,
            accion,
            estado_anterior,
            estado_nuevo,
            monto_anterior,
            monto_nuevo
        )
        SELECT
            d.cod_venta,
            'UPDATE',
            d.estado,
            i.estado,
            d.monto_total,
            i.monto_total
        FROM deleted AS d
        JOIN inserted AS i
            ON i.cod_venta = d.cod_venta;
    END;
END;
GO

PRINT '03_trg_auditoria_venta.sql ejecutado: trg_auditoria_venta creado.';
GO
