-- ============================================================================
-- ETAPA V - TEMA 1 / TEMA 2: PROCEDIMIENTO TRANSACCIONAL DE CANCELACION
-- Archivo: etapa_v/transacciones/02_sp_cambiar_estado_venta.sql
-- Sistema: X Motors - Base de Datos I - Grupo 49 - FaCENA (UNNE)
--
-- Permite unicamente:
--   efectuada -> cancelada
--   efectuada -> reembolsada
-- Reintegra el stock de la moto y de los accesorios una sola vez.
-- La venta se vuelve a leer con bloqueo antes de cambiar el estado para
-- evitar que una cancelacion concurrente reintegre el stock dos veces.
-- ============================================================================

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;
GO

USE [X MOTORS];
GO

CREATE OR ALTER PROCEDURE dbo.sp_cambiar_estado_venta
    @cod_venta    INT,
    @nuevo_estado VARCHAR(30)
AS
BEGIN
    SET NOCOUNT ON;

    -- Opciones requeridas por el indice filtrado ux_venta_chasis_vigente.
    SET ANSI_PADDING ON;
    SET ANSI_WARNINGS ON;
    SET ARITHABORT ON;
    SET CONCAT_NULL_YIELDS_NULL ON;
    SET NUMERIC_ROUNDABORT OFF;

    -- ------------------------------------------------------------------------
    -- 1. Validaciones de entrada
    -- ------------------------------------------------------------------------
    IF @nuevo_estado IS NULL
       OR @nuevo_estado NOT IN ('cancelada', 'reembolsada')
        THROW 50014, 'Estado destino invalido', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.venta WHERE cod_venta = @cod_venta)
        THROW 50012, 'Venta inexistente', 1;

    SET XACT_ABORT ON;

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

        IF @@ROWCOUNT = 0
            THROW 50012, 'Venta inexistente', 1;

        -- 3. Bloquear en el mismo orden que sp_registrar_venta:
        --    moto -> modelo -> accesorios -> venta.
        DECLARE @id_modelo INT;

        SELECT @id_modelo = id_modelo
        FROM dbo.motocicleta WITH (UPDLOCK, HOLDLOCK)
        WHERE numero_chasis = @numero_chasis;

        IF @@ROWCOUNT = 0 OR @id_modelo IS NULL
            THROW 50003, 'Chasis inexistente', 1;

        DECLARE @dummy INT;

        SELECT @dummy = stock_disponible
        FROM dbo.modelo_motocicleta WITH (UPDLOCK, HOLDLOCK)
        WHERE id_modelo = @id_modelo;

        IF @@ROWCOUNT = 0
            THROW 50017, 'Modelo inexistente', 1;

        -- 3.1 Bloquear accesorios en orden ascendente de id. El cursor
        --     garantiza el orden de adquisicion de bloqueos.
        DECLARE @id_acc_bloqueo INT;
        DECLARE @stock_acc_bloqueo INT;

        DECLARE cursor_accesorios CURSOR LOCAL FAST_FORWARD FOR
            SELECT id_accesorio
            FROM dbo.detalle_venta_accesorio
            WHERE cod_venta = @cod_venta
            ORDER BY id_accesorio;

        OPEN cursor_accesorios;
        FETCH NEXT FROM cursor_accesorios INTO @id_acc_bloqueo;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @stock_acc_bloqueo = NULL;

            SELECT @stock_acc_bloqueo = ac.stock
            FROM dbo.accesorio AS ac WITH (UPDLOCK, HOLDLOCK)
            WHERE ac.id_accesorio = @id_acc_bloqueo;

            IF @@ROWCOUNT = 0 OR @stock_acc_bloqueo IS NULL
                THROW 50006, 'Accesorio inexistente', 1;

            FETCH NEXT FROM cursor_accesorios INTO @id_acc_bloqueo;
        END

        CLOSE cursor_accesorios;
        DEALLOCATE cursor_accesorios;

        -- 4. Bloquear la venta y revalidar estado + chasis.
        DECLARE @numero_chasis_actual VARCHAR(100);

        SELECT
            @estado_actual = estado,
            @numero_chasis_actual = numero_chasis
        FROM dbo.venta WITH (UPDLOCK, HOLDLOCK)
        WHERE cod_venta = @cod_venta;

        IF @@ROWCOUNT = 0
            THROW 50012, 'Venta inexistente', 1;

        IF @estado_actual IS NULL OR @estado_actual <> 'efectuada'
            THROW 50013, 'Transicion de estado invalida', 1;

        IF @numero_chasis_actual IS NULL
           OR @numero_chasis_actual <> @numero_chasis
            THROW 50013, 'La venta cambio de chasis durante la operacion', 1;

        -- 5. Cambiar el estado. Se usa sp_executesql para que el lote hijo
        --    herede las opciones SET fijadas arriba y no falle con 1934.
        DECLARE @filas_venta INT;
        DECLARE @sql_venta NVARCHAR(MAX) = N'
            UPDATE dbo.venta
            SET estado = @nuevo_estado
            WHERE cod_venta = @cod_venta;

            SET @filas_venta = @@ROWCOUNT;';

        EXEC sys.sp_executesql
            @sql_venta,
            N'@nuevo_estado VARCHAR(30), @cod_venta INT, @filas_venta INT OUTPUT',
            @nuevo_estado = @nuevo_estado,
            @cod_venta = @cod_venta,
            @filas_venta = @filas_venta OUTPUT;

        IF @filas_venta <> 1
            THROW 50013, 'No se pudo actualizar el estado de la venta', 1;

        -- 6. Reintegrar una unidad al modelo.
        UPDATE dbo.modelo_motocicleta
        SET stock_disponible = stock_disponible + 1
        WHERE id_modelo = @id_modelo;

        IF @@ROWCOUNT <> 1
            THROW 50017, 'No se pudo reintegrar el stock del modelo', 1;

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
