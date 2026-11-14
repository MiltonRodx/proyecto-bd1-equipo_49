-- ============================================================================
-- ETAPA V - TEMA 1: PROCEDIMIENTOS ALMACENADOS
-- Archivo: docs/etapa-05/01-procedimientos-funciones/02_procedimientos.sql
-- Sistema: X Motors - Base de Datos I - Grupo 49 - FaCENA (UNNE)
--
-- QUE HAY EN ESTE ARCHIVO (4 procedimientos):
--   1. sp_actualizar_precio_modelo  Cambia el precio de lista de un modelo.
--                                   El registro del cambio lo hace un trigger (tema 3).
--   2. sp_reporte_ventas_periodo    Reporte de ventas por vendedor en un periodo.
--   3. sp_generar_cotizacion        Usa las funciones fn_descuento_cliente y
--                                   fn_precio_con_descuento (tema 1, funciones).
--   4. sp_RegistrarVentaCompleta    EL CASO DEL ENUNCIADO: registra una venta
--                                   completa en una sola llamada y de forma
--                                   atomica (tambien es la demo del tema 2).
--
-- Requiere ejecutados antes: DDL, DML y 01_funciones.sql.
-- Cancelacion / reembolso de ventas: ver docs/etapa-05/02-transacciones/.
--
-- CONVENCION DE ERRORES: los THROW usan numeros 50001 a 50019. Cada numero
-- identifica un error de negocio y los scripts de demostracion los usan para
-- comprobar que el procedimiento rechaza lo que corresponde.
-- ============================================================================

-- QUOTED_IDENTIFIER y ANSI_NULLS quedan guardados con cada procedimiento al
-- crearlo (por eso se fijan aca, antes de los CREATE).
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

USE [X MOTORS];
GO

-- ============================================================================
-- 1. sp_actualizar_precio_modelo
--    Cambia el precio de lista de un modelo de forma controlada.
--    NO escribe en historial_de_precio: eso lo hace el trigger
--    trg_historial_precio_modelo (Etapa V, triggers de auditoria). Asi cada
--    pieza tiene una sola responsabilidad.
-- ============================================================================
CREATE OR ALTER PROCEDURE dbo.sp_actualizar_precio_modelo
    @id_modelo    INT,
    @nuevo_precio DECIMAL(12,2)
AS
BEGIN
    SET NOCOUNT ON;

    -- Validacion: un precio nulo, cero o negativo no tiene sentido.
    IF @nuevo_precio IS NULL OR @nuevo_precio <= 0
        THROW 50016, 'Precio de modelo invalido', 1;

    UPDATE dbo.modelo_motocicleta
    SET precio_lista = @nuevo_precio
    WHERE id_modelo = @id_modelo;

    -- Si no se actualizo ninguna fila, el modelo no existe.
    IF @@ROWCOUNT = 0
        THROW 50017, 'Modelo inexistente', 1;
END;
GO

-- ============================================================================
-- 2. sp_reporte_ventas_periodo
--    Reporte de ventas efectuadas agrupado por vendedor.
--    Parametros opcionales: NULL en un extremo = sin limite de ese lado
--    (sin parametros devuelve todo el historico).
-- ============================================================================
CREATE OR ALTER PROCEDURE dbo.sp_reporte_ventas_periodo
    @fecha_desde DATE = NULL,
    @fecha_hasta DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- Si se informan ambos extremos, el rango tiene que ser coherente.
    IF @fecha_desde IS NOT NULL
       AND @fecha_hasta IS NOT NULL
       AND @fecha_desde > @fecha_hasta
        THROW 50015, 'Rango de fechas invalido', 1;

    SELECT
        v.dni_vendedor,
        p.nombre + ' ' + p.apellido               AS vendedor,
        COUNT(*)                                  AS cantidad_ventas,
        CAST(SUM(v.monto_total) AS DECIMAL(14,2)) AS monto_total,
        CAST(AVG(v.monto_total) AS DECIMAL(14,2)) AS ticket_promedio
    FROM dbo.venta    AS v
    JOIN dbo.vendedor AS vd ON vd.dni_vendedor = v.dni_vendedor
    JOIN dbo.persona  AS p  ON p.dni = vd.dni_vendedor
    WHERE v.estado = 'efectuada'                          -- solo ventas vigentes
      AND (@fecha_desde IS NULL OR v.fecha >= @fecha_desde)
      AND (@fecha_hasta IS NULL OR v.fecha <= @fecha_hasta)
    GROUP BY v.dni_vendedor, p.nombre, p.apellido
    ORDER BY monto_total DESC;
END;
GO

-- ============================================================================
-- 3. sp_generar_cotizacion
--    Genera una cotizacion aplicando el descuento por historial del cliente.
--    Es el uso de las funciones que pide el enunciado:
--      - fn_descuento_cliente decide QUE porcentaje le corresponde al cliente.
--      - fn_precio_con_descuento APLICA ese porcentaje al precio de lista.
--    La cotizacion vale 7 dias corridos (RN12).
--    Si el llamador manda un porcentaje, puede ser igual o menor al permitido,
--    nunca mayor.
-- ============================================================================
CREATE OR ALTER PROCEDURE dbo.sp_generar_cotizacion
    @dni_cliente          INT,
    @id_modelo            INT,
    @porcentaje_descuento DECIMAL(5,2) = NULL,   -- NULL = usar el del historial
    @fecha_emision        DATE = NULL,           -- NULL = hoy
    @id_cotizacion        INT OUTPUT             -- devuelve el id generado
AS
BEGIN
    SET NOCOUNT ON;

    -- Validaciones de entrada
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

    -- Descuento: la FUNCION decide el maximo permitido segun el historial.
    DECLARE @descuento_permitido DECIMAL(5,2) =
        ISNULL(dbo.fn_descuento_cliente(@dni_cliente), 0);

    IF @porcentaje_descuento IS NULL
        SET @porcentaje_descuento = @descuento_permitido;
    ELSE IF @porcentaje_descuento > @descuento_permitido
        THROW 50009, 'Porcentaje de descuento mayor al permitido', 1;

    IF @fecha_emision IS NULL
        SET @fecha_emision = CAST(GETDATE() AS DATE);

    -- Precio final: la FUNCION aplica el porcentaje al precio de lista.
    DECLARE @precio_cotizado DECIMAL(12,2) =
        dbo.fn_precio_con_descuento(@precio_lista, @porcentaje_descuento);

    IF @precio_cotizado IS NULL
        THROW 50016, 'Precio de modelo invalido', 1;

    INSERT INTO dbo.cotizacion (
        fecha_emision, fecha_vencimiento, precio_cotizado, dni_cliente, id_modelo
    )
    VALUES (
        @fecha_emision,
        DATEADD(DAY, 7, @fecha_emision),     -- RN12: vigencia de 7 dias corridos
        @precio_cotizado,
        @dni_cliente,
        @id_modelo
    );

    SET @id_cotizacion = CAST(SCOPE_IDENTITY() AS INT);

    -- Devuelve la cotizacion armada (comoda para la demo).
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
    JOIN dbo.persona             AS p ON p.dni = c.dni_cliente
    JOIN dbo.modelo_motocicleta  AS m ON m.id_modelo = c.id_modelo
    WHERE c.id_cotizacion = @id_cotizacion;
END;
GO

-- ============================================================================
-- 4. sp_RegistrarVentaCompleta        <<< CASO DEL ENUNCIADO >>>
--
--    Problema: registrar una venta completa sin que el usuario tenga que
--    ejecutar multiples consultas. Toda la logica de ventas queda en un unico
--    componente reutilizable.
--
--    Las 6 tareas del enunciado y donde se hacen (ver "PASO n" mas abajo):
--      1. Registrar encabezado de venta -> PASO 7: INSERT en venta
--      2. Insertar detalle de venta     -> PASO 8: INSERT en detalle_venta_accesorio
--      3. Guardar precio historico      -> PASO 4: se congela el precio en
--         venta.precio_venta_moto (y precio_pactado en cada accesorio). Aunque
--         el precio de lista cambie despues, la venta conserva el de ese dia.
--         La evolucion del precio de lista queda en historial_de_precio, que
--         llena el trigger trg_historial_precio_modelo (no se duplica aca).
--      4. Actualizar stock              -> PASO 9: moto (-1) y accesorios
--      5. Aplicar descuentos            -> PASO 4: fn_descuento_cliente decide
--         el porcentaje y fn_precio_con_descuento lo aplica SOLO al precio de
--         la moto, nunca al monto total.
--      6. Confirmar la operacion        -> COMMIT al final; ante cualquier
--         error, ROLLBACK y no queda nada a medias (atomicidad, tema 2).
--
--    Ejemplo de uso:
--      DECLARE @cod INT;
--      EXEC dbo.sp_RegistrarVentaCompleta
--           @dni_cliente = 30111222, @dni_vendedor = 28999888,
--           @numero_chasis = 'CHASIS-001', @metodo_pago = 'efectivo',
--           @accesorios_json = N'[{"id_accesorio":3,"cantidad":1}]',
--           @cod_venta = @cod OUTPUT;
-- ============================================================================
CREATE OR ALTER PROCEDURE dbo.sp_RegistrarVentaCompleta
    @dni_cliente          INT,                    -- cliente que compra (RN5: pasa a "comprador")
    @dni_vendedor         INT,                    -- vendedor que efectua la venta
    @numero_chasis        VARCHAR(100),           -- moto fisica que se vende
    @metodo_pago          VARCHAR(50),            -- efectivo / transferencia / tarjeta / financiamiento
    @porcentaje_descuento DECIMAL(5,2) = NULL,    -- NULL = el del historial del cliente
    @accesorios_json      NVARCHAR(MAX) = NULL,   -- '[{"id_accesorio":3,"cantidad":1,"precio_pactado":9000}]'
    @fecha                DATE = NULL,            -- NULL = hoy
    @cod_venta            INT OUTPUT              -- devuelve el codigo de la venta creada
AS
BEGIN
    SET NOCOUNT ON;

    -- Opciones SET que exige el indice filtrado ux_venta_chasis_vigente (el que
    -- impide dos ventas efectuadas del mismo chasis). Se fijan en tiempo de
    -- ejecucion para no depender de como este configurado el cliente.
    SET ANSI_PADDING ON;
    SET ANSI_WARNINGS ON;
    SET ARITHABORT ON;
    SET CONCAT_NULL_YIELDS_NULL ON;
    SET NUMERIC_ROUNDABORT OFF;

    -- ========================================================================
    -- VALIDACIONES DE ENTRADA
    -- Se hacen ANTES de abrir la transaccion: son baratas y no tocan datos,
    -- asi que si fallan no hay nada que deshacer.
    -- ========================================================================
    IF NOT EXISTS (SELECT 1 FROM dbo.cliente WHERE dni_cliente = @dni_cliente)
        THROW 50001, 'Cliente inexistente', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.vendedor WHERE dni_vendedor = @dni_vendedor)
        THROW 50002, 'Vendedor inexistente', 1;

    IF @numero_chasis IS NULL OR LTRIM(RTRIM(@numero_chasis)) = ''
        THROW 50003, 'Chasis inexistente', 1;

    -- Descuento: sin porcentaje explicito se usa el del historial. Uno
    -- explicito puede ser igual o menor al permitido, nunca mayor.
    IF @porcentaje_descuento IS NOT NULL
       AND (@porcentaje_descuento < 0 OR @porcentaje_descuento > 100)
        THROW 50009, 'Porcentaje de descuento invalido', 1;

    DECLARE @descuento_permitido DECIMAL(5,2) =
        ISNULL(dbo.fn_descuento_cliente(@dni_cliente), 0);

    IF @porcentaje_descuento IS NULL
        SET @porcentaje_descuento = @descuento_permitido;
    ELSE IF @porcentaje_descuento > @descuento_permitido
        THROW 50009, 'Porcentaje de descuento mayor al permitido', 1;

    -- Metodo de pago: se normaliza (el DML historico trae variantes con
    -- mayusculas y formas como "Transferencia") y se valida contra la lista.
    IF @metodo_pago IS NULL OR LTRIM(RTRIM(@metodo_pago)) = ''
        THROW 50011, 'Metodo de pago invalido', 1;

    DECLARE @metodo VARCHAR(50) = LOWER(LTRIM(RTRIM(@metodo_pago)));

    IF @metodo = 'transferencia'
        SET @metodo = 'transferencia bancaria';

    IF @metodo NOT IN ('efectivo', 'transferencia bancaria',
                       'tarjeta de credito', 'tarjeta de debito', 'financiamiento')
        THROW 50011, 'Metodo de pago invalido', 1;

    IF @fecha IS NULL
        SET @fecha = CAST(GETDATE() AS DATE);

    -- ========================================================================
    -- TRANSACCION
    -- XACT_ABORT ON: ante un error grave SQL Server deshace la transaccion
    -- solo. El CATCH de abajo cubre el resto de los casos.
    -- ========================================================================
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRAN;

        -- --------------------------------------------------------------
        -- PASO 1: moto fisica. Se la bloquea (UPDLOCK) para que dos vendedores
        -- no puedan vender la MISMA unidad al mismo tiempo. De paso obtenemos
        -- a que modelo pertenece.
        -- --------------------------------------------------------------
        DECLARE @id_modelo INT;

        SELECT @id_modelo = id_modelo
        FROM dbo.motocicleta WITH (UPDLOCK, HOLDLOCK)
        WHERE numero_chasis = @numero_chasis;

        IF @@ROWCOUNT = 0 OR @id_modelo IS NULL
            THROW 50003, 'Chasis inexistente', 1;

        -- --------------------------------------------------------------
        -- PASO 2: modelo. Se bloquea y se lee el stock y el precio de lista
        -- vigente en este momento.
        -- --------------------------------------------------------------
        DECLARE @precio_lista DECIMAL(12,2);
        DECLARE @stock        INT;

        SELECT @precio_lista = precio_lista,
               @stock        = stock_disponible
        FROM dbo.modelo_motocicleta WITH (UPDLOCK, HOLDLOCK)
        WHERE id_modelo = @id_modelo;

        IF @@ROWCOUNT = 0
            THROW 50017, 'Modelo inexistente', 1;

        IF @stock IS NULL OR @stock < 1
            THROW 50004, 'Sin stock disponible de la moto', 1;

        IF @precio_lista IS NULL OR @precio_lista < 0
            THROW 50016, 'Precio de modelo invalido', 1;

        -- --------------------------------------------------------------
        -- PASO 3: ese chasis no puede tener ya una venta efectuada.
        -- (Respaldo en la base: el indice filtrado ux_venta_chasis_vigente.)
        -- --------------------------------------------------------------
        IF EXISTS (
            SELECT 1
            FROM dbo.venta WITH (UPDLOCK, HOLDLOCK)
            WHERE numero_chasis = @numero_chasis
              AND estado = 'efectuada'
        )
            THROW 50005, 'El chasis ya tiene una venta efectuada', 1;

        -- --------------------------------------------------------------
        -- PASO 4  [TAREAS 3 y 5]: descuento y precio historico.
        -- La funcion aplica el descuento SOBRE EL PRECIO DE LA MOTO. El
        -- resultado es el precio que queda "congelado" en la venta.
        -- --------------------------------------------------------------
        DECLARE @precio_venta_moto DECIMAL(12,2) =
            dbo.fn_precio_con_descuento(@precio_lista, @porcentaje_descuento);

        IF @precio_venta_moto IS NULL
            THROW 50016, 'Precio de modelo invalido', 1;

        -- --------------------------------------------------------------
        -- PASO 5: accesorios. Llegan como JSON y se cargan en una tabla
        -- temporal (variable de tabla). precio_pactado NULL = precio de lista
        -- del dia. La PRIMARY KEY impide repetir el mismo accesorio.
        -- --------------------------------------------------------------
        DECLARE @accesorios TABLE (
            id_accesorio   INT NOT NULL PRIMARY KEY,
            cantidad       INT NOT NULL,
            precio_pactado DECIMAL(12,2) NULL
        );

        IF @accesorios_json IS NOT NULL
           AND LTRIM(RTRIM(@accesorios_json)) NOT IN ('', '[]')
        BEGIN
            -- Un JSON mal formado o con ids repetidos falla en el INSERT;
            -- se captura y se informa con un error de negocio propio.
            BEGIN TRY
                INSERT INTO @accesorios (id_accesorio, cantidad, precio_pactado)
                SELECT j.id_accesorio, j.cantidad, j.precio_pactado
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

            IF EXISTS (SELECT 1 FROM @accesorios
                       WHERE id_accesorio IS NULL OR cantidad IS NULL OR cantidad <= 0)
                THROW 50007, 'Cantidad de accesorio invalida', 1;

            IF EXISTS (SELECT 1 FROM @accesorios WHERE precio_pactado < 0)
                THROW 50018, 'Precio de accesorio invalido', 1;

            -- Todos los accesorios pedidos tienen que existir en el catalogo.
            -- (El control de stock se hace en el PASO 9, junto con el descuento.)
            IF EXISTS (
                SELECT 1
                FROM @accesorios AS a
                WHERE NOT EXISTS (SELECT 1 FROM dbo.accesorio AS ac
                                  WHERE ac.id_accesorio = a.id_accesorio)
            )
                THROW 50006, 'Accesorio inexistente', 1;
        END

        -- --------------------------------------------------------------
        -- PASO 6: monto total = moto con descuento + accesorios. Se calcula
        -- ANTES del INSERT para que la venta nazca con su monto definitivo.
        -- --------------------------------------------------------------
        DECLARE @total_accesorios DECIMAL(12,2) = (
            SELECT ISNULL(
                SUM(CAST(a.cantidad * ISNULL(a.precio_pactado, ac.precio_lista) AS DECIMAL(12,2))),
                0.00)
            FROM @accesorios AS a
            JOIN dbo.accesorio AS ac ON ac.id_accesorio = a.id_accesorio
        );

        DECLARE @monto_total DECIMAL(12,2) = @precio_venta_moto + @total_accesorios;

        -- --------------------------------------------------------------
        -- PASO 7  [TAREA 1]: encabezado de venta.
        -- Se ejecuta como lote dinamico (sp_executesql) por el indice filtrado
        -- ux_venta_chasis_vigente: si el cliente que llama tiene opciones SET
        -- distintas, un INSERT directo puede fallar con el error 1934. El lote
        -- dinamico toma las opciones fijadas arriba en este procedimiento.
        -- --------------------------------------------------------------
        DECLARE @sql_venta NVARCHAR(MAX) = N'
            INSERT INTO dbo.venta (
                fecha, metodo_pago, precio_venta_moto, monto_total,
                estado, dni_cliente, dni_vendedor, numero_chasis
            )
            VALUES (
                @fecha, @metodo, @precio_venta_moto, @monto_total,
                ''efectuada'', @dni_cliente, @dni_vendedor, @numero_chasis
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
            @fecha             = @fecha,
            @metodo            = @metodo,
            @precio_venta_moto = @precio_venta_moto,
            @monto_total       = @monto_total,
            @dni_cliente       = @dni_cliente,
            @dni_vendedor      = @dni_vendedor,
            @numero_chasis     = @numero_chasis,
            @cod_venta_out     = @cod_venta OUTPUT;

        IF @cod_venta IS NULL
            THROW 50019, 'No se pudo obtener el codigo de venta', 1;

        -- --------------------------------------------------------------
        -- PASO 8  [TAREA 2]: detalle de venta (los accesorios), con el
        -- precio pactado congelado en este momento.
        -- --------------------------------------------------------------
        INSERT INTO dbo.detalle_venta_accesorio (
            cod_venta, id_accesorio, cantidad, precio_pactado
        )
        SELECT @cod_venta,
               a.id_accesorio,
               a.cantidad,
               ISNULL(a.precio_pactado, ac.precio_lista)
        FROM @accesorios AS a
        JOIN dbo.accesorio AS ac ON ac.id_accesorio = a.id_accesorio;

        -- --------------------------------------------------------------
        -- PASO 9  [TAREA 4]: actualizar stock.
        --
        -- Accesorios: UN solo UPDATE que descuenta SOLO si alcanza el stock
        -- (WHERE stock >= cantidad). Chequeo y descuento en la misma sentencia
        -- = no hay hueco para que otra venta se meta en el medio. Si alguna
        -- fila no se actualizo es porque no habia stock suficiente: se lanza
        -- el error y el CATCH deshace TODO (incluida la venta del PASO 7).
        -- --------------------------------------------------------------
        UPDATE ac
        SET ac.stock = ac.stock - a.cantidad
        FROM dbo.accesorio AS ac
        JOIN @accesorios   AS a ON a.id_accesorio = ac.id_accesorio
        WHERE ac.stock >= a.cantidad;

        DECLARE @accesorios_actualizados INT = @@ROWCOUNT;

        IF @accesorios_actualizados <> (SELECT COUNT(*) FROM @accesorios)
            THROW 50008, 'Sin stock suficiente de accesorio', 1;

        -- Moto: se resta 1 unidad al stock del modelo.
        UPDATE dbo.modelo_motocicleta
        SET stock_disponible = stock_disponible - 1
        WHERE id_modelo = @id_modelo;

        IF @@ROWCOUNT <> 1
            THROW 50017, 'No se pudo actualizar el stock del modelo', 1;

        -- --------------------------------------------------------------
        -- PASO 10: regla RN5 - el cliente pasa a estado "comprador".
        -- --------------------------------------------------------------
        UPDATE dbo.cliente
        SET estado = 'comprador'
        WHERE dni_cliente = @dni_cliente
          AND estado <> 'comprador';

        -- --------------------------------------------------------------
        -- PASO 11: control final (RN6 / RN11). Se recalcula el total con
        -- fn_total_venta leyendo el detalle ya guardado y se compara con el
        -- monto que se grabo en el encabezado.
        -- --------------------------------------------------------------
        DECLARE @total_control DECIMAL(12,2) =
            dbo.fn_total_venta(@precio_venta_moto, @cod_venta);

        IF @total_control IS NULL OR @total_control <> @monto_total
            THROW 50019, 'Total de venta inconsistente', 1;

        -- --------------------------------------------------------------
        -- [TAREA 6]: llegamos hasta aca sin errores -> se confirma TODO.
        -- --------------------------------------------------------------
        COMMIT;
    END TRY
    BEGIN CATCH
        -- Cualquier error de arriba cae aca: se deshace todo lo hecho en la
        -- transaccion (venta, detalle, stocks) y se re-lanza el MISMO error
        -- para que lo vea quien llamo al procedimiento.
        IF @@TRANCOUNT > 0
            ROLLBACK;

        THROW;
    END CATCH
END;
GO

PRINT '02_procedimientos.sql ejecutado: sp_actualizar_precio_modelo, sp_reporte_ventas_periodo, sp_generar_cotizacion y sp_RegistrarVentaCompleta creados.';
GO