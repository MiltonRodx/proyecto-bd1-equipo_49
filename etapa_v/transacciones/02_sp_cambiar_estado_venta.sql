-- ============================================================================
-- ETAPA V - TEMA 1 / TEMA 2: PROCEDIMIENTO TRANSACCIONAL DE CANCELACION
-- Archivo: etapa_v/transacciones/02_sp_cambiar_estado_venta.sql
-- Sistema: X Motors - Base de Datos I - Grupo 49 - FaCENA (UNNE)
--
-- Permite unicamente:
--   efectuada -> cancelada
--   efectuada -> reembolsada
-- Reintegra el stock de la moto y de los accesorios una sola vez.
-- ============================================================================

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

USE [X MOTORS];
GO

CREATE OR ALTER PROCEDURE dbo.sp_cambiar_estado_venta
    @cod_venta    INT,
    @nuevo_estado VARCHAR(30)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- ------------------------------------------------------------------------
    -- 1. Validaciones de entrada
    -- ------------------------------------------------------------------------
    IF @nuevo_estado IS NULL
       OR @nuevo_estado NOT IN ('cancelada', 'reembolsada')
        THROW 50014, 'Estado destino invalido', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.venta WHERE cod_venta = @cod_venta)
        THROW 50012, 'Venta inexistente', 1;

    BEGIN TRY
        BEGIN TRAN;

        -- 2. Leer la venta sin bloqueo para obtener el chasis.
        DECLARE @estado_actual VARCHAR(30);
        DECLARE @numero_chasis VARCHAR(100);

        SELECT
            @estado_actual = estado,
            @numero_chasis = numero_chasis
        FROM dbo.venta
        WHERE cod_venta = @cod_venta;

        -- 3. Bloquear en el mismo orden que sp_registrar_venta:
        --    moto -> modelo -> accesorios -> venta.
        DECLARE @id_modelo INT;

        SELECT @id_modelo = id_modelo
        FROM dbo.motocicleta WITH (UPDLOCK, HOLDLOCK)
        WHERE numero_chasis = @numero_chasis;

        DECLARE @dummy INT;

        SELECT @dummy = stock_disponible
        FROM dbo.modelo_motocicleta WITH (UPDLOCK, HOLDLOCK)
        WHERE id_modelo = @id_modelo;

        SELECT @dummy = SUM(ac.stock)
        FROM dbo.accesorio AS ac WITH (UPDLOCK, HOLDLOCK)
        WHERE ac.id_accesorio IN (
            SELECT id_accesorio
            FROM dbo.detalle_venta_accesorio
            WHERE cod_venta = @cod_venta
        );

        -- 4. Bloquear la venta y revalidar el estado.
        SELECT @estado_actual = estado
        FROM dbo.venta WITH (UPDLOCK, HOLDLOCK)
        WHERE cod_venta = @cod_venta;

        IF @estado_actual <> 'efectuada'
            THROW 50013, 'Transicion de estado invalida', 1;

        -- 5. Cambiar el estado.
        UPDATE dbo.venta
        SET estado = @nuevo_estado
        WHERE cod_venta = @cod_venta;

        -- 6. Reintegrar una unidad al modelo.
        UPDATE dbo.modelo_motocicleta
        SET stock_disponible = stock_disponible + 1
        WHERE id_modelo = @id_modelo;

        -- 7. Reintegrar las cantidades de accesorios.
        UPDATE ac
        SET ac.stock = ac.stock + d.cantidad
        FROM dbo.accesorio AS ac
        JOIN dbo.detalle_venta_accesorio AS d
            ON d.id_accesorio = ac.id_accesorio
        WHERE d.cod_venta = @cod_venta;

        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK;
        THROW;
    END CATCH
END;
GO

PRINT '02_sp_cambiar_estado_venta.sql ejecutado: sp_cambiar_estado_venta creado.';
GO
