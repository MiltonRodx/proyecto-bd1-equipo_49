-- ============================================================================
-- ETAPA V - TEMA 2: PROCEDIMIENTO TRANSACCIONAL DE CANCELACION
-- Archivo: docs/etapa-05/02-transacciones/02_sp_cambiar_estado_venta.sql
-- Sistema: X Motors - Base de Datos I - Grupo 49 - FaCENA (UNNE)
--
-- Permite unicamente:
--   efectuada -> cancelada
--   efectuada -> reembolsada
--
-- QUE ES Y PARA QUE SIRVE
-- Cancela o reembolsa una venta ya hecha: es la operacion inversa de
-- sp_RegistrarVentaCompleta. Tiene que cambiar tres cosas a la vez:
--   1. El estado de la venta (efectuada -> cancelada / reembolsada).
--   2. El stock de la moto: vuelve 1 unidad al modelo.
--   3. El stock de los accesorios: vuelven las cantidades vendidas.
-- Los tres cambios son UNA unidad de trabajo: o se hacen los tres o no se
-- hace ninguno (todo o nada). Si fallara el ultimo y los otros quedaran
-- guardados, la venta figuraria cancelada pero el stock estaria mal. Eso es
-- la ATOMICIDAD, la "A" de ACID.
-- ACID = Atomicidad, Consistencia, Aislamiento y Durabilidad: propiedades que
-- aseguran que las transacciones se ejecuten de forma segura, confiable y sin
-- corromper los datos.
--
-- COMO EVITA DEVOLVER EL STOCK DOS VECES
-- El UPDATE de la venta solo actua si la venta sigue 'efectuada'. Si dos
-- usuarios cancelan la misma venta a la vez, el segundo espera, ya no la
-- encuentra 'efectuada' y recibe el error 50013 (el stock no se reintegra
-- dos veces).
--
-- ERRORES: 50012 venta inexistente | 50013 transicion invalida |
--          50014 estado destino invalido
-- ============================================================================

-- ANSI_NULLS y QUOTED_IDENTIFIER se guardan con el procedimiento al crearlo.
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
    SET XACT_ABORT ON;      -- ante un error grave SQL Server deshace la transaccion solo

    -- Opciones que exige el indice filtrado ux_venta_chasis_vigente: el UPDATE
    -- cambia "estado", la columna del filtro (error 1934 si estan mal).
    SET ANSI_PADDING ON;  SET ANSI_WARNINGS ON;  SET ARITHABORT ON;
    SET CONCAT_NULL_YIELDS_NULL ON;  SET NUMERIC_ROUNDABORT OFF;

    -- VALIDACIONES (antes de abrir la transaccion: no tocan datos)
    IF ISNULL(@nuevo_estado, '') NOT IN ('cancelada', 'reembolsada')
        THROW 50014, 'Estado destino invalido', 1;

    -- Modelo de la moto vendida. Si no hay resultado, la venta no existe.
    DECLARE @id_modelo INT =
        (SELECT mo.id_modelo
         FROM dbo.venta       AS v
         JOIN dbo.motocicleta AS mo ON mo.numero_chasis = v.numero_chasis
         WHERE v.cod_venta = @cod_venta);

    IF @id_modelo IS NULL
        THROW 50012, 'Venta inexistente', 1;

    BEGIN TRY
        BEGIN TRAN;

        -- PASO 1: bloquear primero el modelo, igual que sp_RegistrarVentaCompleta
        -- (modelo -> venta). Con el mismo orden, los dos procedimientos no se
        -- esperan mutuamente (deadlock) y las operaciones sobre un mismo modelo
        -- se atienden de a una.
        SELECT @id_modelo = id_modelo
        FROM dbo.modelo_motocicleta WITH (UPDLOCK)
        WHERE id_modelo = @id_modelo;

        -- PASO 2: cambiar el estado SOLO si la venta sigue 'efectuada'. El chequeo
        -- y el cambio ocurren en la misma sentencia: no hay hueco para que otra
        -- cancelacion se meta en el medio. Cero filas = ya estaba cancelada o
        -- reembolsada: se corta aca y no se reintegra nada.
        UPDATE dbo.venta
        SET estado = @nuevo_estado
        WHERE cod_venta = @cod_venta AND estado = 'efectuada';

        IF @@ROWCOUNT = 0
            THROW 50013, 'Transicion de estado invalida', 1;

        -- PASO 3: reintegrar el stock. Una unidad al modelo...
        UPDATE dbo.modelo_motocicleta
        SET stock_disponible = stock_disponible + 1
        WHERE id_modelo = @id_modelo;

        -- ...y las cantidades vendidas de cada accesorio.
        UPDATE ac
        SET ac.stock = ac.stock + d.cantidad
        FROM dbo.accesorio AS ac
        JOIN dbo.detalle_venta_accesorio AS d ON d.id_accesorio = ac.id_accesorio
        WHERE d.cod_venta = @cod_venta;

        COMMIT;     -- los tres cambios se confirman juntos
    END TRY
    BEGIN CATCH
        -- Cualquier error: se deshace todo (estado y stocks) y se re-lanza el
        -- MISMO error para que lo vea quien llamo al procedimiento.
        IF @@TRANCOUNT > 0
            ROLLBACK;

        THROW;
    END CATCH
END;
GO

PRINT '02_sp_cambiar_estado_venta.sql ejecutado: sp_cambiar_estado_venta creado.';
GO
