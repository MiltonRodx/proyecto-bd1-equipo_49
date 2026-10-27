-- ============================================================================
-- ETAPA V - TEMA 1 / TEMA 2: PROCEDIMIENTO TRANSACCIONAL DE VENTA
-- Archivo: etapa_v/transacciones/01_sp_registrar_venta.sql
-- Sistema: X Motors - Base de Datos I - Grupo 49 - FaCENA (UNNE)
--
-- Registra una venta completa de forma atomica:
--   cabecera + detalle de accesorios + stock + estado del cliente.
-- El descuento se aplica SIEMPRE sobre el precio de la moto, nunca sobre
-- el monto total. Si no se informa el porcentaje, se usa el descuento por
-- historial calculado por fn_descuento_cliente.
-- El monto_total se calcula antes del INSERT para que el trigger de
-- auditoria registre una sola insercion, sin un UPDATE posterior.
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

CREATE OR ALTER PROCEDURE dbo.sp_registrar_venta
    @dni_cliente          INT,
    @dni_vendedor         INT,
    @numero_chasis        VARCHAR(100),
    @metodo_pago          VARCHAR(50),
    @porcentaje_descuento DECIMAL(5,2) = NULL,
    @accesorios_json      NVARCHAR(MAX) = NULL,
    @fecha                DATE = NULL,
    @cod_venta            INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- Las opciones SET que exige el indice filtrado ux_venta_chasis_vigente
    -- se fijan tambien en tiempo de ejecucion. No alcanza con fijarlas al
    -- crear el procedimiento.
    SET ANSI_PADDING ON;
    SET ANSI_WARNINGS ON;
    SET ARITHABORT ON;
    SET CONCAT_NULL_YIELDS_NULL ON;
    SET NUMERIC_ROUNDABORT OFF;

    -- ------------------------------------------------------------------------
    -- 1. Validaciones de entrada
    -- ------------------------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM dbo.cliente WHERE dni_cliente = @dni_cliente)
        THROW 50001, 'Cliente inexistente', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.vendedor WHERE dni_vendedor = @dni_vendedor)
        THROW 50002, 'Vendedor inexistente', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.motocicleta WHERE numero_chasis = @numero_chasis)
        THROW 50003, 'Chasis inexistente', 1;

    IF @porcentaje_descuento IS NOT NULL
       AND (@porcentaje_descuento < 0 OR @porcentaje_descuento > 100)
        THROW 50009, 'Porcentaje de descuento invalido', 1;

    -- Descuento por historial: si el llamador no informa un porcentaje, se
    -- aplica el que corresponde al cliente. Un porcentaje explicito puede ser
    -- igual o menor al permitido, pero nunca mayor.
    DECLARE @descuento_permitido DECIMAL(5,2) =
        dbo.fn_descuento_cliente(@dni_cliente);

    IF @descuento_permitido IS NULL
        SET @descuento_permitido = 0;

    IF @porcentaje_descuento IS NULL
        SET @porcentaje_descuento = @descuento_permitido;
    ELSE IF @porcentaje_descuento > @descuento_permitido
        THROW 50009, 'Porcentaje de descuento mayor al permitido', 1;

    -- Normalizacion del metodo de pago (el DML historico tiene mayusculas y
    -- variantes como Transferencia / Tarjeta de debito).
    IF @metodo_pago IS NULL OR LTRIM(RTRIM(@metodo_pago)) = ''
        THROW 50011, 'Metodo de pago invalido', 1;

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

        IF EXISTS (SELECT 1 FROM @accesorios WHERE precio_pactado < 0)
            THROW 50018, 'Precio de accesorio invalido', 1;
    END

    -- ------------------------------------------------------------------------
    -- 3. Transaccion principal
    -- ------------------------------------------------------------------------
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRAN;

        -- 3.1 Bloquear la moto fisica y obtener su modelo.
        DECLARE @id_modelo INT;

        SELECT @id_modelo = id_modelo
        FROM dbo.motocicleta WITH (UPDLOCK, HOLDLOCK)
        WHERE numero_chasis = @numero_chasis;

        IF @@ROWCOUNT = 0 OR @id_modelo IS NULL
            THROW 50003, 'Chasis inexistente', 1;

        -- 3.2 Bloquear el modelo y leer stock + precio de lista.
        DECLARE @precio_lista DECIMAL(10,2);
        DECLARE @stock        INT;

        SELECT
            @precio_lista = precio_lista,
            @stock        = stock_disponible
        FROM dbo.modelo_motocicleta WITH (UPDLOCK, HOLDLOCK)
        WHERE id_modelo = @id_modelo;

        IF @@ROWCOUNT = 0
            THROW 50017, 'Modelo inexistente', 1;

        IF @stock IS NULL OR @stock < 1
            THROW 50004, 'Sin stock disponible de la moto', 1;

        IF @precio_lista IS NULL OR @precio_lista < 0
            THROW 50016, 'Precio de modelo invalido', 1;

        -- 3.3 Bloquear accesorios en orden ascendente de id. El cursor
        --     garantiza el orden de adquisicion de bloqueos y evita
        --     interbloqueos entre ventas concurrentes.
        DECLARE @id_acc_bloqueo       INT;
        DECLARE @cantidad_bloqueo     INT;
        DECLARE @stock_acc_bloqueo    INT;

        DECLARE cursor_accesorios CURSOR LOCAL FAST_FORWARD FOR
            SELECT id_accesorio, cantidad
            FROM @accesorios
            ORDER BY id_accesorio;

        OPEN cursor_accesorios;
        FETCH NEXT FROM cursor_accesorios
            INTO @id_acc_bloqueo, @cantidad_bloqueo;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @stock_acc_bloqueo = NULL;

            SELECT @stock_acc_bloqueo = ac.stock
            FROM dbo.accesorio AS ac WITH (UPDLOCK, HOLDLOCK)
            WHERE ac.id_accesorio = @id_acc_bloqueo;

            IF @@ROWCOUNT = 0 OR @stock_acc_bloqueo IS NULL
                THROW 50006, 'Accesorio inexistente', 1;

            IF @stock_acc_bloqueo < @cantidad_bloqueo
                THROW 50008, 'Sin stock suficiente de accesorio', 1;

            FETCH NEXT FROM cursor_accesorios
                INTO @id_acc_bloqueo, @cantidad_bloqueo;
        END

        CLOSE cursor_accesorios;
        DEALLOCATE cursor_accesorios;

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

        IF @precio_venta_moto IS NULL
            THROW 50016, 'Precio de modelo invalido', 1;

        -- 3.6 Calcular el total antes del INSERT. Asi el trigger de auditoria
        --     ve el monto definitivo desde la primera y unica insercion.
        DECLARE @total_accesorios DECIMAL(12,2) = (
            SELECT ISNULL(
                SUM(CAST(a.cantidad * ISNULL(a.precio_pactado, ac.precio_lista) AS DECIMAL(12,2))),
                0.00
            )
            FROM @accesorios AS a
            JOIN dbo.accesorio AS ac
                ON ac.id_accesorio = a.id_accesorio
        );

        DECLARE @monto_total DECIMAL(12,2) =
            @precio_venta_moto + @total_accesorios;

        -- 3.6 Insertar la cabecera con el total definitivo. La sentencia se
        --     ejecuta con sp_executesql para que el lote hijo herede las
        --     opciones SET fijadas mas arriba; un INSERT directo dentro del
        --     procedimiento sigue viendo las opciones del llamador y puede
        --     fallar con 1934 si el cliente no las configuro.
        DECLARE @sql_venta NVARCHAR(MAX) = N'
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
                @monto_total,
                ''efectuada'',
                @dni_cliente,
                @dni_vendedor,
                @numero_chasis
            );

            SET @cod_venta_out = CAST(SCOPE_IDENTITY() AS INT);';

        EXEC sys.sp_executesql
            @sql_venta,
            N'@fecha DATE,
              @metodo VARCHAR(50),
              @precio_venta_moto DECIMAL(12,2),
              @monto_total DECIMAL(12,2),
              @dni_cliente INT,
              @dni_vendedor INT,
              @numero_chasis VARCHAR(100),
              @cod_venta_out INT OUTPUT',
            @fecha = @fecha,
            @metodo = @metodo,
            @precio_venta_moto = @precio_venta_moto,
            @monto_total = @monto_total,
            @dni_cliente = @dni_cliente,
            @dni_vendedor = @dni_vendedor,
            @numero_chasis = @numero_chasis,
            @cod_venta_out = @cod_venta OUTPUT;

        IF @cod_venta IS NULL
            THROW 50019, 'No se pudo obtener el codigo de venta', 1;

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

        IF @@ROWCOUNT <> 1
            THROW 50017, 'No se pudo actualizar el stock del modelo', 1;

        -- 3.10 RN5: el cliente pasa a comprador.
        UPDATE dbo.cliente
        SET estado = 'comprador'
        WHERE dni_cliente = @dni_cliente
          AND estado <> 'comprador';

        -- 3.11 Verificar la formula de control sin modificar la cabecera.
        DECLARE @total_control DECIMAL(12,2) =
            dbo.fn_total_venta(@precio_venta_moto, @cod_venta);

        IF @total_control IS NULL OR @total_control <> @monto_total
            THROW 50019, 'Total de venta inconsistente', 1;

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
