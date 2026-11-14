-- ============================================================================
-- ETAPA V - TEMA 3: TRIGGER DE AUDITORIA DE ESTADOS DEL CLIENTE
-- Archivo: docs/etapa-05/03-triggers-auditoria/04_trg_auditoria_cliente_estado.sql
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

    -- Guard barato: si estado ni figura en el SET, no hay nada que auditar.
    IF NOT UPDATE(estado)
        RETURN;

    -- UPDATE() es verdadero aunque el valor no cambie, por eso se compara igual.
    -- EXCEPT compara NULL-safe: NULL vs NULL = igual, NULL vs 'x' = distinto.
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
    WHERE EXISTS (SELECT i.estado EXCEPT SELECT d.estado);
END;
GO

PRINT '04_trg_auditoria_cliente_estado.sql ejecutado: trg_auditoria_cliente_estado creado.';
GO