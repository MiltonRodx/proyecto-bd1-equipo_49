-- ============================================================================
-- ETAPA V - TEMA 1: PROCEDIMIENTOS Y FUNCIONES ALMACENADAS
-- Archivo: etapa_v/procedimientos_funciones/02_procedimientos.sql
-- Sistema: X Motors - Base de Datos I - Grupo 49 - FaCENA (UNNE)
--
-- Procedimientos de administracion de catalogo y reportes.
-- Los procedimientos transaccionales de venta/cancelacion estan en:
--   etapa_v/transacciones/01_sp_registrar_venta.sql
--   etapa_v/transacciones/02_sp_cambiar_estado_venta.sql
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

-- ============================================================================
-- 1. sp_actualizar_precio_modelo
--    Actualiza de forma controlada el precio de lista de un modelo.
--    No inserta en historial_de_precio: de eso se encarga el trigger
--    trg_historial_precio_modelo (Etapa V - triggers de auditoria).
-- ============================================================================
CREATE OR ALTER PROCEDURE dbo.sp_actualizar_precio_modelo
    @id_modelo    INT,
    @nuevo_precio DECIMAL(12,2)
AS
BEGIN
    SET NOCOUNT ON;

    IF @nuevo_precio IS NULL
       OR @nuevo_precio <= 0
       OR @nuevo_precio > 99999999.99
        THROW 50016, 'Precio de modelo invalido', 1;

    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRAN;

        -- Bloquear la fila antes de comparar y actualizar. Asi dos
        -- ejecuciones concurrentes no se pisan el precio ni el historial.
        DECLARE @precio_actual DECIMAL(12,2);

        SELECT @precio_actual = precio_lista
        FROM dbo.modelo_motocicleta WITH (UPDLOCK, HOLDLOCK)
        WHERE id_modelo = @id_modelo;

        IF @@ROWCOUNT = 0 OR @precio_actual IS NULL
            THROW 50017, 'Modelo inexistente', 1;

        IF @precio_actual = @nuevo_precio
        BEGIN
            COMMIT;
            SELECT 'El precio no cambia; no se actualiza.' AS mensaje;
            RETURN;
        END

        UPDATE dbo.modelo_motocicleta
        SET precio_lista = @nuevo_precio
        WHERE id_modelo = @id_modelo;

        IF @@ROWCOUNT <> 1
            THROW 50017, 'No se pudo actualizar el precio del modelo', 1;

        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK;
        THROW;
    END CATCH
END;
GO

-- ============================================================================
-- 2. sp_reporte_ventas_periodo
--    Reporte parametrizado de ventas efectuadas, agrupado por vendedor.
--    NULL en un extremo = sin limite por ese lado.
-- ============================================================================
CREATE OR ALTER PROCEDURE dbo.sp_reporte_ventas_periodo
    @fecha_desde DATE = NULL,
    @fecha_hasta DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @fecha_desde IS NOT NULL
       AND @fecha_hasta IS NOT NULL
       AND @fecha_desde > @fecha_hasta
        THROW 50015, 'Rango de fechas invalido', 1;

    SELECT
        v.dni_vendedor,
        p.nombre + ' ' + p.apellido AS vendedor,
        COUNT(*) AS cantidad_ventas,
        CAST(SUM(v.monto_total) AS DECIMAL(14,2)) AS monto_total,
        CAST(AVG(v.monto_total) AS DECIMAL(14,2)) AS ticket_promedio
    FROM dbo.venta AS v
    JOIN dbo.vendedor AS vd ON vd.dni_vendedor = v.dni_vendedor
    JOIN dbo.persona AS p ON p.dni = vd.dni_vendedor
    WHERE v.estado = 'efectuada'
      AND (@fecha_desde IS NULL OR v.fecha >= @fecha_desde)
      AND (@fecha_hasta IS NULL OR v.fecha <= @fecha_hasta)
    GROUP BY v.dni_vendedor, p.nombre, p.apellido
    ORDER BY monto_total DESC;
END;
GO

PRINT '02_procedimientos.sql ejecutado: sp_actualizar_precio_modelo y sp_reporte_ventas_periodo creados.';
GO
