-- ============================================================================
-- ETAPA V - TEMA 1 / TEMA 2: PROCEDIMIENTO TRANSACCIONAL DE VENTA
-- Archivo: etapa_v/transacciones/01_sp_registrar_venta.sql
-- Sistema: X Motors - Base de Datos I - Grupo 49 - FaCENA (UNNE)
--
-- Registra una venta completa de forma atomica:
--   cabecera + detalle de accesorios + stock + estado del cliente.
-- El descuento se aplica SIEMPRE sobre el precio de la moto, nunca sobre
-- el monto total. Asi se mantiene la validacion de sql/consultas/01_factura.sql.
-- ============================================================================

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

USE [X MOTORS];
GO

CREATE OR ALTER PROCEDURE dbo.sp_registrar_venta
    @dni_cliente          INT,
    @dni_vendedor         INT,
    @numero_chasis        VARCHAR(100),
    @metodo_pago          VARCHAR(50),
    @porcentaje_descuento DECIMAL(5,2) = 0,
    @accesorios_json      NVARCHAR(MAX) = NULL,
    @fecha                DATE = NULL,
    @cod_venta            INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- ------------------------------------------------------------------------
    -- 1. Validaciones de entrada
    -- ------------------------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM dbo.cliente WHERE dni_cliente = @dni_cliente)
        THROW 50001, 'Cliente inexistente', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.vendedor WHERE dni_vendedor = @dni_vendedor)
        THROW 50002, 'Vendedor inexistente', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.motocicleta WHERE numero_chasis = @numero_chasis)
        THROW 50003, 'Chasis inexistente', 1;

    IF @porcentaje_descuento IS NULL
       OR @porcentaje_descuento < 0
       OR @porcentaje_descuento > 100
        THROW 50009, 'Porcentaje de descuento invalido', 1;

    -- Normalizacion del metodo de pago (el DML historico tiene mayusculas y
    -- variantes como Transferencia / Tarjeta de debito).
    DECLARE @metodo VARCHAR(50) = LOWER(LTRIM(RTRIM(@metodo_pago)));

    IF @metodo = 'transferencia'
        SET @metodo = 'transferencia bancaria';

    IF @metodo NOT IN (
        'efectivo',
        'transferencia bancaria',
        'tarjeta de credito',
        'tarjeta de debito',
        'financiamiento'
    )
        THROW 50011, 'Metodo de pago invalido', 1;

    IF @fecha IS NULL
        SET @fecha = CAST(GETDATE() AS DATE);

    -- ------------------------------------------------------------------------
    -- 2. Parseo y validacion del JSON de accesorios
    -- ------------------------------------------------------------------------
    DECLARE @accesorios TABLE (
        id_accesorio  INT NOT NULL PRIMARY KEY,
        cantidad      INT NOT NULL,
        precio_pactado DECIMAL(12,2) NULL
    );

    IF @accesorios_json IS NOT NULL
       AND LTRIM(RTRIM(@accesorios_json)) <> ''
       AND LTRIM(RTRIM(@accesorios_json)) <> '[]'
    BEGIN
        BEGIN TRY
            INSERT INTO @accesorios (id_accesorio, cantidad, precio_pactado)
            SELECT
                j.id_accesorio,
                j.cantidad,
                j.precio_pactado
            FROM OPENJSON(@accesorios_json)
            WITH (
                id_accesorio  INT           '$.id_accesorio',
                cantidad      INT           '$.cantidad',
                precio_pactado DECIMAL(12,2) '$.precio_pactado'
            ) AS j;
        END TRY
        BEGIN CATCH
            THROW 50010, 'JSON de accesorios invalido o con IDs duplicados', 1;
        END CATCH

        IF EXISTS (
            SELECT 1
            FROM @accesorios
            WHERE id_accesorio IS NULL
               OR cantidad IS NULL
               OR cantidad <= 0
        )
            THROW 50007, 'Cantidad de accesorio invalida', 1;
    END

    -- ------------------------------------------------------------------------
    -- 3. Transaccion principal
    -- ------------------------------------------------------------------------
    BEGIN TRY
        BEGIN TRAN;

        -- 3.1 Bloquear la moto fisica y obtener su modelo.
        DECLARE @id_modelo INT;

        SELECT @id_modelo = id_modelo
        FROM dbo.motocicleta WITH (UPDLOCK, HOLDLOCK)
        WHERE numero_chasis = @numero_chasis;

        -- 3.2 Bloquear el modelo y leer stock + precio de lista.
        DECLARE @precio_lista DECIMAL(10,2);
        DECLARE @stock        INT;

        SELECT
            @precio_lista = precio_lista,
            @stock        = stock_disponible
        FROM dbo.modelo_motocicleta WITH (UPDLOCK, HOLDLOCK)
        WHERE id_modelo = @id_modelo;

        IF @stock IS NULL OR @stock < 1
            THROW 50004, 'Sin stock disponible de la moto', 1;

        -- 3.3 Bloquear accesorios en orden de id y validar existencia/stock.
        DECLARE @dummy INT;

        SELECT @dummy = SUM(ac.stock)
        FROM dbo.accesorio AS ac WITH (UPDLOCK, HOLDLOCK)
        WHERE ac.id_accesorio IN (SELECT id_accesorio FROM @accesorios);

        IF EXISTS (
            SELECT 1
            FROM @accesorios AS a
            LEFT JOIN dbo.accesorio AS ac
                ON ac.id_accesorio = a.id_accesorio
            WHERE ac.id_accesorio IS NULL
        )
            THROW 50006, 'Accesorio inexistente', 1;

        IF EXISTS (
            SELECT 1
            FROM @accesorios AS a
            JOIN dbo.accesorio AS ac
                ON ac.id_accesorio = a.id_accesorio
            WHERE ac.stock < a.cantidad
        )
            THROW 50008, 'Sin stock suficiente de accesorio', 1;

        -- 3.4 Verificar que el chasis no tenga otra venta efectuada.
        IF EXISTS (
            SELECT 1
            FROM dbo.venta WITH (UPDLOCK, HOLDLOCK)
            WHERE numero_chasis = @numero_chasis
              AND estado = 'efectuada'
        )
            THROW 50005, 'El chasis ya tiene una venta efectuada', 1;

        -- 3.5 Calcular el precio de la moto con descuento.
        DECLARE @precio_venta_moto DECIMAL(12,2) =
            dbo.fn_precio_con_descuento(@precio_lista, @porcentaje_descuento);

        -- 3.6 Insertar la cabecera. monto_total queda provisorio y se
        --     recalcula al final con los accesorios.
        INSERT INTO dbo.venta (
            fecha,
            metodo_pago,
            precio_venta_moto,
            monto_total,
            estado,
            dni_cliente,
            dni_vendedor,
            numero_chasis
        )
        VALUES (
            @fecha,
            @metodo,
            @precio_venta_moto,
            @precio_venta_moto,
            'efectuada',
            @dni_cliente,
            @dni_vendedor,
            @numero_chasis
        );

        SET @cod_venta = CAST(SCOPE_IDENTITY() AS INT);

        -- 3.7 Insertar el detalle con el precio pactado congelado.
        INSERT INTO dbo.detalle_venta_accesorio (
            cod_venta,
            id_accesorio,
            cantidad,
            precio_pactado
        )
        SELECT
            @cod_venta,
            a.id_accesorio,
            a.cantidad,
            ISNULL(a.precio_pactado, ac.precio_lista)
        FROM @accesorios AS a
        JOIN dbo.accesorio AS ac
            ON ac.id_accesorio = a.id_accesorio;

        -- 3.8 Descontar stock de accesorios.
        UPDATE ac
        SET ac.stock = ac.stock - a.cantidad
        FROM dbo.accesorio AS ac
        JOIN @accesorios AS a
            ON a.id_accesorio = ac.id_accesorio;

        -- 3.9 Descontar una unidad del modelo.
        UPDATE dbo.modelo_motocicleta
        SET stock_disponible = stock_disponible - 1
        WHERE id_modelo = @id_modelo;

        -- 3.10 RN5: el cliente pasa a comprador.
        UPDATE dbo.cliente
        SET estado = 'comprador'
        WHERE dni_cliente = @dni_cliente
          AND estado <> 'comprador';

        -- 3.11 Recalcular el monto total con la formula de control.
        UPDATE dbo.venta
        SET monto_total = dbo.fn_total_venta(@precio_venta_moto, @cod_venta)
        WHERE cod_venta = @cod_venta;

        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK;
        THROW;
    END CATCH
END;
GO

PRINT '01_sp_registrar_venta.sql ejecutado: sp_registrar_venta creado.';
GO
