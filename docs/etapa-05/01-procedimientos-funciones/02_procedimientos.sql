-- ============================================================================
-- ETAPA V - TEMA 1: PROCEDIMIENTOS Y FUNCIONES ALMACENADAS
-- Archivo: docs/etapa-05/01-procedimientos-funciones/02_procedimientos.sql
-- Sistema: X Motors - Base de Datos I - Grupo 49 - FaCENA (UNNE)
--
-- Procedimientos de administracion de catalogo y reportes.
-- Incluye sp_RegistrarVentaCompleta, el caso del enunciado y el unico
-- procedimiento transaccional de registro de ventas (tambien sirve de demo
-- del tema 2): registra la venta completa (encabezado + detalle + precio
-- historico congelado + stock + descuentos + COMMIT) en una sola llamada.
-- La cancelacion/reembolso esta en:
--   docs/etapa-05/02-transacciones/02_sp_cambiar_estado_venta.sql
--   docs/etapa-05/02-transacciones/scripts.sql (demos de transacciones)
--
-- Requiere que se hayan ejecutado antes:
--   sql/ddl/DDL_Script_X_Motors.sql  y  sql/dml/DML_Script_X_Motors.sql
--   01_funciones.sql (este mismo directorio)
-- ============================================================================

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

    IF @nuevo_precio IS NULL OR @nuevo_precio <= 0
        THROW 50016, 'Precio de modelo invalido', 1;

    UPDATE dbo.modelo_motocicleta
    SET precio_lista = @nuevo_precio
    WHERE id_modelo = @id_modelo;

    IF @@ROWCOUNT = 0
        THROW 50017, 'Modelo inexistente', 1;
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

-- ============================================================================
-- 3. sp_generar_cotizacion
--    Genera una cotizacion aplicando el descuento por historial del cliente.
--    Es el caso de uso de fn_descuento_cliente que pide la consigna: la
--    funcion decide el porcentaje segun el monto acumulado y el procedimiento
--    lo aplica al precio de lista del modelo, respetando la validez de 7 dias
--    corridos (RN12). Si el llamador informa un porcentaje, puede ser igual o
--    menor al permitido, pero nunca mayor.
-- ============================================================================
CREATE OR ALTER PROCEDURE dbo.sp_generar_cotizacion
    @dni_cliente          INT,
    @id_modelo            INT,
    @porcentaje_descuento DECIMAL(5,2) = NULL,
    @fecha_emision        DATE = NULL,
    @id_cotizacion        INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.cliente WHERE dni_cliente = @dni_cliente)
        THROW 50001, 'Cliente inexistente', 1;

    DECLARE @precio_lista DECIMAL(12,2);

    SELECT @precio_lista = precio_lista
    FROM dbo.modelo_motocicleta
    WHERE id_modelo = @id_modelo;

    IF @@ROWCOUNT = 0 OR @precio_lista IS NULL
        THROW 50017, 'Modelo inexistente', 1;

    IF @precio_lista < 0
        THROW 50016, 'Precio de modelo invalido', 1;

    IF @porcentaje_descuento IS NOT NULL
       AND (@porcentaje_descuento < 0 OR @porcentaje_descuento > 100)
        THROW 50009, 'Porcentaje de descuento invalido', 1;

    -- Descuento por historial: la funcion decide el porcentaje.
    DECLARE @descuento_permitido DECIMAL(5,2) =
        dbo.fn_descuento_cliente(@dni_cliente);

    IF @descuento_permitido IS NULL
        SET @descuento_permitido = 0;

    IF @porcentaje_descuento IS NULL
        SET @porcentaje_descuento = @descuento_permitido;
    ELSE IF @porcentaje_descuento > @descuento_permitido
        THROW 50009, 'Porcentaje de descuento mayor al permitido', 1;

    IF @fecha_emision IS NULL
        SET @fecha_emision = CAST(GETDATE() AS DATE);

    DECLARE @precio_cotizado DECIMAL(12,2) =
        dbo.fn_precio_con_descuento(@precio_lista, @porcentaje_descuento);

    IF @precio_cotizado IS NULL
        THROW 50016, 'Precio de modelo invalido', 1;

    INSERT INTO dbo.cotizacion (
        fecha_emision,
        fecha_vencimiento,
        precio_cotizado,
        dni_cliente,
        id_modelo
    )
    VALUES (
        @fecha_emision,
        DATEADD(day, 7, @fecha_emision),
        @precio_cotizado,
        @dni_cliente,
        @id_modelo
    );

    SET @id_cotizacion = CAST(SCOPE_IDENTITY() AS INT);

    SELECT
        c.id_cotizacion,
        p.nombre + ' ' + p.apellido AS cliente,
        m.marca,
        m.nombre_modelo,
        @precio_lista         AS precio_lista,
        @descuento_permitido  AS descuento_historial,
        @porcentaje_descuento AS descuento_aplicado,
        c.precio_cotizado,
        c.fecha_emision,
        c.fecha_vencimiento
    FROM dbo.cotizacion AS c
    JOIN dbo.persona AS p ON p.dni = c.dni_cliente
    JOIN dbo.modelo_motocicleta AS m ON m.id_modelo = c.id_modelo
    WHERE c.id_cotizacion = @id_cotizacion;
END;
GO

-- ============================================================================
-- 4. sp_RegistrarVentaCompleta
--    Caso de negocio del enunciado: registrar una venta completa sin que el
--    usuario tenga que ejecutar multiples consultas. Toda la logica de ventas
--    queda centralizada en un unico componente reutilizable.
--
--    Tareas que realiza (mapeadas al enunciado):
--      1. Registrar encabezado de venta  -> INSERT en dbo.venta.
--      2. Insertar detalle de venta      -> INSERT en dbo.detalle_venta_accesorio.
--      3. Guardar precio historico       -> congela en venta.precio_venta_moto
--         el precio de lista del modelo vigente al momento de la venta (con
--         descuento ya aplicado). La evolucion del precio de lista (RN7,
--         tabla historial_de_precio) sigue a cargo del trigger
--         trg_historial_precio_modelo; aca no se duplica ese registro.
--      4. Actualizar stock               -> resta 1 unidad del modelo y las
--         cantidades vendidas de cada accesorio.
--      5. Aplicar descuentos             -> fn_descuento_cliente decide el
--         porcentaje segun el historial de compras y fn_precio_con_descuento
--         lo aplica SOBRE EL PRECIO DE LA MOTO, nunca sobre el monto total.
--      6. Confirmar la operacion         -> COMMIT dentro de TRY/CATCH;
--         cualquier error hace ROLLBACK y no queda nada a medio registrar.
-- ============================================================================

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;
GO

CREATE OR ALTER PROCEDURE dbo.sp_RegistrarVentaCompleta
    @dni_cliente          INT,                 -- Cliente que compra (RN5: pasa a comprador)
    @dni_vendedor         INT,                 -- Vendedor que efectua la venta
    @numero_chasis        VARCHAR(100),        -- Moto fisica vendida
    @metodo_pago          VARCHAR(50),         -- Efectivo / transferencia / tarjeta / financiamiento
    @porcentaje_descuento DECIMAL(5,2) = NULL, -- NULL = usa el descuento por historial del cliente
    @accesorios_json      NVARCHAR(MAX) = NULL, -- Accesorios vendidos: '[{"id_accesorio":3,"cantidad":1}, ...]'
    @fecha                DATE = NULL,         -- NULL = fecha del dia
    @cod_venta            INT OUTPUT           -- Codigo de la venta registrada
AS
BEGIN
    SET NOCOUNT ON;

    -- Las opciones SET que exige el indice filtrado ux_venta_chasis_vigente
    -- se fijan tambien en tiempo de ejecucion; no alcanza con fijarlas al
    -- crear el procedimiento.
    SET ANSI_PADDING ON;
    SET ANSI_WARNINGS ON;
    SET ARITHABORT ON;
    SET CONCAT_NULL_YIELDS_NULL ON;
    SET NUMERIC_ROUNDABORT OFF;

    -- ------------------------------------------------------------------
    -- Validaciones de entrada
    -- ------------------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM dbo.cliente WHERE dni_cliente = @dni_cliente)
        THROW 50001, 'Cliente inexistente', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.vendedor WHERE dni_vendedor = @dni_vendedor)
        THROW 50002, 'Vendedor inexistente', 1;

    IF @numero_chasis IS NULL OR LTRIM(RTRIM(@numero_chasis)) = ''
        THROW 50003, 'Chasis inexistente', 1;

    -- Tarea 5: aplicar descuentos. Si el llamador no informa un porcentaje,
    -- se usa el que corresponde por historial de compras. Un porcentaje
    -- explicito puede ser igual o menor al permitido, pero nunca mayor.
    IF @porcentaje_descuento IS NOT NULL
       AND (@porcentaje_descuento < 0 OR @porcentaje_descuento > 100)
        THROW 50009, 'Porcentaje de descuento invalido', 1;

    DECLARE @descuento_permitido DECIMAL(5,2) =
        dbo.fn_descuento_cliente(@dni_cliente);

    IF @descuento_permitido IS NULL
        SET @descuento_permitido = 0;

    IF @porcentaje_descuento IS NULL
        SET @porcentaje_descuento = @descuento_permitido;
    ELSE IF @porcentaje_descuento > @descuento_permitido
        THROW 50009, 'Porcentaje de descuento mayor al permitido', 1;

    -- Normalizacion del metodo de pago (el DML historico trae variantes con
    -- mayusculas y formas como Transferencia / Tarjeta de debito).
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

    -- ------------------------------------------------------------------
    -- Tarea 6 (prepaso): transaccion atomica. Si cualquier paso falla,
    -- el CATCH hace ROLLBACK y no queda ni encabezado ni detalle.
    -- ------------------------------------------------------------------
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRAN;

        -- 1) Bloquear la moto fisica y resolver su modelo. Los UPDLOCK
        --    serializan ventas concurrentes de la misma unidad.
        DECLARE @id_modelo INT;

        SELECT @id_modelo = id_modelo
        FROM dbo.motocicleta WITH (UPDLOCK, HOLDLOCK)
        WHERE numero_chasis = @numero_chasis;

        IF @@ROWCOUNT = 0 OR @id_modelo IS NULL
            THROW 50003, 'Chasis inexistente', 1;

        -- 2) Bloquear el modelo y leer stock + precio de lista historico.
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

        -- 3) La unidad no puede tener otra venta efectuada (lo respalda el
        --    indice filtrado ux_venta_chasis_vigente).
        IF EXISTS (
            SELECT 1
            FROM dbo.venta WITH (UPDLOCK, HOLDLOCK)
            WHERE numero_chasis = @numero_chasis
              AND estado = 'efectuada'
        )
            THROW 50005, 'El chasis ya tiene una venta efectuada', 1;

        -- 4) Tarea 5: descuento aplicado al precio de lista. El resultado es
        --    el precio historico congelado de la venta (tarea 3).
        DECLARE @precio_venta_moto DECIMAL(12,2) =
            dbo.fn_precio_con_descuento(@precio_lista, @porcentaje_descuento);

        IF @precio_venta_moto IS NULL
            THROW 50016, 'Precio de modelo invalido', 1;

        -- 5) Tarea 2 (preparacion): accesorios vendidos junto con la moto.
        --    Formato: '[{"id_accesorio":3,"cantidad":1}, ...]'. El precio
        --    pactado se congela: NULL = precio de lista del dia.
        DECLARE @accesorios TABLE (
            id_accesorio   INT NOT NULL PRIMARY KEY,
            cantidad       INT NOT NULL,
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
                    id_accesorio   INT           '$.id_accesorio',
                    cantidad       INT           '$.cantidad',
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

        -- Bloquear los accesorios en orden ascendente de id: garantiza el
        -- orden de adquisicion de bloqueos y evita interbloqueos.
        DECLARE @id_acc_bloqueo    INT;
        DECLARE @cantidad_bloqueo  INT;
        DECLARE @stock_acc_bloqueo INT;

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

        -- 6) Total antes del INSERT: el encabezado nace con el monto
        --    definitivo y el trigger de auditoria (si existe) ve una sola
        --    insercion consistente.
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

        -- ------------------------------------------------------------------
        -- Tarea 1: registrar encabezado de venta.
        --     La sentencia se ejecuta con sp_executesql para que el lote hijo
        --     herede las opciones SET fijadas mas arriba; un INSERT directo
        --     dentro del procedimiento sigue viendo las opciones del llamador
        --     y puede fallar con 1934 si el cliente no las configuro (el
        --     indice filtrado ux_venta_chasis_vigente las exige).
        -- ------------------------------------------------------------------
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

        -- ------------------------------------------------------------------
        -- Tarea 2: insertar detalle de venta (accesorios) con el precio
        -- pactado congelado en el momento de la transaccion.
        -- ------------------------------------------------------------------
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

        -- ------------------------------------------------------------------
        -- Tarea 4: actualizar stock (modelo y accesorios).
        -- ------------------------------------------------------------------
        UPDATE ac
        SET ac.stock = ac.stock - a.cantidad
        FROM dbo.accesorio AS ac
        JOIN @accesorios AS a
            ON a.id_accesorio = ac.id_accesorio;

        UPDATE dbo.modelo_motocicleta
        SET stock_disponible = stock_disponible - 1
        WHERE id_modelo = @id_modelo;

        IF @@ROWCOUNT <> 1
            THROW 50017, 'No se pudo actualizar el stock del modelo', 1;

        -- RN5: el cliente pasa a estado comprador.
        UPDATE dbo.cliente
        SET estado = 'comprador'
        WHERE dni_cliente = @dni_cliente
          AND estado <> 'comprador';

        -- Control de formula (RN6/RN11): el total debe reproducir el calculo
        -- centralizado de la funcion, tomando el detalle ya insertado.
        DECLARE @total_control DECIMAL(12,2) =
            dbo.fn_total_venta(@precio_venta_moto, @cod_venta);

        IF @total_control IS NULL OR @total_control <> @monto_total
            THROW 50019, 'Total de venta inconsistente', 1;

        -- ------------------------------------------------------------------
        -- Tarea 6: confirmar la operacion.
        -- ------------------------------------------------------------------
        COMMIT;
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('local', 'cursor_accesorios') >= 0
        BEGIN
            IF CURSOR_STATUS('local', 'cursor_accesorios') <> -3
                CLOSE cursor_accesorios;
            DEALLOCATE cursor_accesorios;
        END

        IF @@TRANCOUNT > 0
            ROLLBACK;

        THROW;
    END CATCH
END;
GO

PRINT '02_procedimientos.sql ejecutado: sp_actualizar_precio_modelo, sp_reporte_ventas_periodo, sp_generar_cotizacion y sp_RegistrarVentaCompleta creados.';
GO
