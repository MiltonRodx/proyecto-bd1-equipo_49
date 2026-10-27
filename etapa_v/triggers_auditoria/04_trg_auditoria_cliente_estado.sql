-- ============================================================================
-- ETAPA V - TEMA 3: TRIGGER DE AUDITORIA DE ESTADOS DEL CLIENTE
-- Archivo: etapa_v/triggers_auditoria/04_trg_auditoria_cliente_estado.sql
-- Sistema: X Motors - Base de Datos I - Grupo 49 - FaCENA (UNNE)
--
-- Registra en auditoria_cliente cada cambio de la columna estado. Si el
-- UPDATE no modifica el estado (por ejemplo al reconfirmar un dato), no se
-- registra nada. Set-based con inserted/deleted.
-- ============================================================================

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

USE [X MOTORS];
GO

CREATE OR ALTER TRIGGER dbo.trg_auditoria_cliente_estado
ON dbo.cliente
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM inserted AS i
        JOIN deleted AS d
            ON d.dni_cliente = i.dni_cliente
        WHERE ISNULL(i.estado, '') <> ISNULL(d.estado, '')
    )
    BEGIN
        INSERT INTO dbo.auditoria_cliente (
            dni_cliente,
            estado_anterior,
            estado_nuevo
        )
        SELECT
            i.dni_cliente,
            d.estado,
            i.estado
        FROM inserted AS i
        JOIN deleted AS d
            ON d.dni_cliente = i.dni_cliente
        WHERE ISNULL(i.estado, '') <> ISNULL(d.estado, '');
    END;
END;
GO

PRINT '04_trg_auditoria_cliente_estado.sql ejecutado: trg_auditoria_cliente_estado creado.';
GO
