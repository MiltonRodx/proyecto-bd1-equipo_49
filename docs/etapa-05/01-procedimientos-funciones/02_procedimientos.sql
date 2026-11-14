-- ============================================================================
-- ETAPA V - TEMA 1: PROCEDIMIENTOS ALMACENADOS
-- Archivo: docs/etapa-05/01-procedimientos-funciones/02_procedimientos.sql
-- Sistema: X Motors - Base de Datos I - Grupo 49 - FaCENA (UNNE)
--
-- QUE HAY EN ESTE ARCHIVO (4 procedimientos):
--   1. sp_actualizar_precio_modelo  Cambia el precio de lista de un modelo.
--                                   El historial lo registra un trigger (tema 3).
--   2. sp_reporte_ventas_periodo    Ventas efectuadas por vendedor en un periodo.
--   3. sp_generar_cotizacion        Usa fn_descuento_cliente y fn_precio_con_descuento.
--   4. sp_RegistrarVentaCompleta    CASO DEL ENUNCIADO: registra una venta completa
--                                   en una sola llamada y de forma atomica
--                                   (tambien es la demo del tema 2).
--
-- Requiere ejecutados antes: DDL, DML y 01_funciones.sql.
-- Cancelacion / reembolso de ventas: ver docs/etapa-05/02-transacciones/.
--
-- ERRORES: los THROW usan los numeros 50001 a 50019. Cada numero identifica un
-- error de negocio y las demos lo usan para comprobar que se rechaza lo debido.
-- ============================================================================

-- ANSI_NULLS y QUOTED_IDENTIFIER se guardan con cada procedimiento al crearlo.
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

USE [X MOTORS];
GO

-- ============================================================================
-- 1. sp_actualizar_precio_modelo
--    Cambia el precio de lista de un modelo. NO escribe en historial_de_precio:
--    eso lo hace el trigger trg_historial_precio_modelo (cada pieza tiene una
--    sola responsabilidad).
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

    IF @@ROWCOUNT = 0                       -- ninguna fila actualizada: no existe
        THROW 50017, 'Modelo inexistente', 1;
END;
GO

-- ============================================================================
-- 2. sp_reporte_ventas_periodo
--    Ventas efectuadas por vendedor. Fechas opcionales: NULL en un extremo =
--    sin limite de ese lado (sin parametros devuelve todo el historico).
-- ============================================================================
CREATE OR ALTER PROCEDURE dbo.sp_reporte_ventas_periodo
    @fecha_desde DATE = NULL,
    @fecha_hasta DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @fecha_desde > @fecha_hasta          -- si alguno es NULL no se cumple
        THROW 50015, 'Rango de fechas invalido', 1;

    SELECT
        v.dni_vendedor,
        p.nombre + ' ' + p.apellido               AS vendedor,
        COUNT(*)                                  AS cantidad_ventas,
        CAST(SUM(v.monto_total) AS DECIMAL(14,2)) AS monto_total,
        CAST(AVG(v.monto_total) AS DECIMAL(14,2)) AS ticket_promedio
    FROM dbo.venta   AS v
    JOIN dbo.persona AS p ON p.dni = v.dni_vendedor
    WHERE v.estado = 'efectuada'
      AND (@fecha_desde IS NULL OR v.fecha >= @fecha_desde)
      AND (@fecha_hasta IS NULL OR v.fecha <= @fecha_hasta)
    GROUP BY v.dni_vendedor, p.nombre, p.apellido
    ORDER BY monto_total DESC;
END;
GO

-- ============================================================================
-- 3. sp_generar_cotizacion
--    Cotizacion con el descuento por historial del cliente:
--      - fn_descuento_cliente decide el MAXIMO porcentaje permitido.
--      - fn_precio_con_descuento lo aplica al precio de lista.
--    Vale 7 dias corridos (RN12). Un porcentaje explicito puede ser igual o
--    menor al permitido, nunca mayor.
-- ============================================================================
CREATE OR ALTER PROCEDURE dbo.sp_generar_cotizacion
    @dni_cliente          INT,
    @id_modelo            INT,
    @porcentaje_descuento DECIMAL(5,2) = NULL,   -- NULL = el del historial
    @fecha_emision        DATE = NULL,           -- NULL = hoy
    @id_cotizacion        INT OUTPUT             -- id de la cotizacion creada
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.cliente WHERE dni_cliente = @dni_cliente)
        THROW 50001, 'Cliente inexistente', 1;

    DECLARE @precio_lista DECIMAL(12,2) =
        (SELECT precio_lista FROM dbo.modelo_motocicleta WHERE id_modelo = @id_modelo);

    IF @precio_lista IS NULL                -- la columna es NOT NULL: no hay modelo
        THROW 50017, 'Modelo inexistente', 1;

    DECLARE @descuento_max DECIMAL(5,2) =
        ISNULL(dbo.fn_descuento_cliente(@dni_cliente), 0);

    SET @porcentaje_descuento = ISNULL(@porcentaje_descuento, @descuento_max);
    SET @fecha_emision        = ISNULL(@fecha_emision, CAST(GETDATE() AS DATE));

    IF @porcentaje_descuento NOT BETWEEN 0 AND @descuento_max
        THROW 50009, 'Porcentaje de descuento invalido o mayor al permitido', 1;

    -- La funcion devuelve NULL si el precio de lista es negativo.
    DECLARE @precio_cotizado DECIMAL(12,2) =
        dbo.fn_precio_con_descuento(@precio_lista, @porcentaje_descuento);

    IF @precio_cotizado IS NULL
        THROW 50016, 'Precio de modelo invalido', 1;

    INSERT INTO dbo.cotizacion
        (fecha_emision, fecha_vencimiento, precio_cotizado, dni_cliente, id_modelo)
    VALUES
        (@fecha_emision, DATEADD(DAY, 7, @fecha_emision),   -- RN12: 7 dias corridos
         @precio_cotizado, @dni_cliente, @id_modelo);

    SET @id_cotizacion = CAST(SCOPE_IDENTITY() AS INT);

    -- Devuelve la cotizacion armada (comoda para la demo).
    SELECT c.id_cotizacion,
           p.nombre + ' ' + p.apellido AS cliente,
           m.marca, m.nombre_modelo,
           @precio_lista         AS precio_lista,
           @descuento_max        AS descuento_historial,
           @porcentaje_descuento AS descuento_aplicado,
           c.precio_cotizado, c.fecha_emision, c.fecha_vencimiento
    FROM dbo.cotizacion        AS c
    JOIN dbo.persona            AS p ON p.dni = c.dni_cliente
    JOIN dbo.modelo_motocicleta AS m ON m.id_modelo = c.id_modelo
    WHERE c.id_cotizacion = @id_cotizacion;
END;
GO

-- ============================================================================
-- 4. sp_RegistrarVentaCompleta        <<< CASO DEL ENUNCIADO >>>
--
--    Registra una venta completa sin que el usuario ejecute multiples
--    consultas: toda la logica de ventas en un unico componente reutilizable.
--
--    Las 6 tareas del enunciado y donde se hacen:
--      1. Encabezado de venta   -> PASO 6: INSERT en venta
--      2. Detalle de venta      -> PASO 7: INSERT en detalle_venta_accesorio
--      3. Precio historico      -> PASO 3: el precio queda congelado en
--         venta.precio_venta_moto (y precio_pactado en cada accesorio). Si el
--         precio de lista cambia despues, la venta conserva el de ese dia. La
--         evolucion del precio de lista la registra el trigger de auditoria.
--      4. Actualizar stock      -> PASO 8: accesorios y moto
--      5. Aplicar descuentos    -> validaciones + PASO 3: fn_descuento_cliente
--         decide el porcentaje y fn_precio_con_descuento lo aplica SOLO al
--         precio de la moto, nunca al monto total.
--      6. Confirmar             -> COMMIT al final; ante cualquier error,
--         ROLLBACK y no queda nada a medias (atomicidad, tema 2).
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
    @cod_venta            INT OUTPUT              -- codigo de la venta creada
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;      -- ante un error grave SQL Server deshace la transaccion solo

    -- Opciones que exige el indice filtrado ux_venta_chasis_vigente (error 1934).
    -- Se fijan aca para no depender de la configuracion del cliente.
    SET ANSI_PADDING ON;  SET ANSI_WARNINGS ON;  SET ARITHABORT ON;
    SET CONCAT_NULL_YIELDS_NULL ON;  SET NUMERIC_ROUNDABORT OFF;

    -- ========================================================================
    -- VALIDACIONES DE ENTRADA
    -- Antes de abrir la transaccion: no tocan datos, no hay nada que deshacer.
    -- ========================================================================
    IF NOT EXISTS (SELECT 1 FROM dbo.cliente WHERE dni_cliente = @dni_cliente)
        THROW 50001, 'Cliente inexistente', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.vendedor WHERE dni_vendedor = @dni_vendedor)
        THROW 50002, 'Vendedor inexistente', 1;

    -- Descuento: sin porcentaje explicito se usa el del historial; uno
    -- explicito puede ser igual o menor al permitido, nunca mayor.
    DECLARE @descuento_max DECIMAL(5,2) =
        ISNULL(dbo.fn_descuento_cliente(@dni_cliente), 0);

    SET @porcentaje_descuento = ISNULL(@porcentaje_descuento, @descuento_max);

    IF @porcentaje_descuento NOT BETWEEN 0 AND @descuento_max
        THROW 50009, 'Porcentaje de descuento invalido o mayor al permitido', 1;

    -- Metodo de pago: se normaliza (el DML historico trae variantes con
    -- mayusculas y "Transferencia") y se valida contra la lista permitida.
    DECLARE @metodo VARCHAR(50) = LOWER(LTRIM(RTRIM(@metodo_pago)));

    IF @metodo = 'transferencia'
        SET @metodo = 'transferencia bancaria';

    IF ISNULL(@metodo, '') NOT IN ('efectivo', 'transferencia bancaria',
                                   'tarjeta de credito', 'tarjeta de debito', 'financiamiento')
        THROW 50011, 'Metodo de pago invalido', 1;

    SET @fecha = ISNULL(@fecha, CAST(GETDATE() AS DATE));

    -- ========================================================================
    -- TRANSACCION
    -- ========================================================================
    DECLARE @id_modelo INT, @precio_lista DECIMAL(12,2), @stock INT;

    -- Accesorios del pedido. precio_pactado NULL en el JSON = precio de lista.
    -- La PRIMARY KEY impide repetir el mismo accesorio.
    DECLARE @accesorios TABLE (
        id_accesorio   INT NOT NULL PRIMARY KEY,
        cantidad       INT NOT NULL,
        precio_pactado DECIMAL(12,2) NULL
    );

    BEGIN TRY
        BEGIN TRAN;

        -- PASO 1: moto y modelo en una sola lectura. UPDLOCK bloquea la fila del
        -- modelo hasta el COMMIT: dos ventas simultaneas del mismo modelo (y por
        -- lo tanto del mismo chasis) se atienden de a una, sin pisarse el stock.
        SELECT @id_modelo = mo.id_modelo, @precio_lista = m.precio_lista,
               @stock = m.stock_disponible
        FROM dbo.motocicleta        AS mo
        JOIN dbo.modelo_motocicleta AS m WITH (UPDLOCK) ON m.id_modelo = mo.id_modelo
        WHERE mo.numero_chasis = @numero_chasis;

        IF @id_modelo IS NULL
            THROW 50003, 'Chasis inexistente', 1;

        IF @stock < 1
            THROW 50004, 'Sin stock disponible de la moto', 1;

        -- PASO 2: ese chasis no puede tener ya una venta efectuada.
        -- (Respaldo en la base: el indice filtrado ux_venta_chasis_vigente.)
        IF EXISTS (SELECT 1 FROM dbo.venta
                   WHERE numero_chasis = @numero_chasis AND estado = 'efectuada')
            THROW 50005, 'El chasis ya tiene una venta efectuada', 1;

        -- PASO 3 [TAREAS 3 y 5]: descuento sobre el precio de la MOTO. El
        -- resultado es el precio que queda "congelado" en la venta.
        DECLARE @precio_venta_moto DECIMAL(12,2) =
            dbo.fn_precio_con_descuento(@precio_lista, @porcentaje_descuento);

        IF @precio_venta_moto IS NULL
            THROW 50016, 'Precio de modelo invalido', 1;

        -- PASO 4: accesorios (llegan como JSON). Un JSON mal formado, con ids
        -- repetidos o con valores nulos falla en el INSERT: se informa con un
        -- error de negocio propio.
        IF LTRIM(RTRIM(ISNULL(@accesorios_json, ''))) <> ''
        BEGIN
            BEGIN TRY
                INSERT INTO @accesorios (id_accesorio, cantidad, precio_pactado)
                SELECT j.id_accesorio, j.cantidad, ISNULL(j.precio_pactado, ac.precio_lista)
                FROM OPENJSON(@accesorios_json)
                     WITH (id_accesorio   INT           '$.id_accesorio',
                           cantidad       INT           '$.cantidad',
                           precio_pactado DECIMAL(12,2) '$.precio_pactado') AS j
                LEFT JOIN dbo.accesorio AS ac ON ac.id_accesorio = j.id_accesorio;
            END TRY
            BEGIN CATCH
                THROW 50010, 'JSON de accesorios invalido o con IDs duplicados', 1;
            END CATCH;

            IF EXISTS (SELECT 1 FROM @accesorios WHERE cantidad <= 0)
                THROW 50007, 'Cantidad de accesorio invalida', 1;

            IF EXISTS (SELECT 1 FROM @accesorios AS a
                       WHERE NOT EXISTS (SELECT 1 FROM dbo.accesorio
                                         WHERE id_accesorio = a.id_accesorio))
                THROW 50006, 'Accesorio inexistente', 1;

            IF EXISTS (SELECT 1 FROM @accesorios WHERE precio_pactado < 0)
                THROW 50018, 'Precio de accesorio invalido', 1;
        END

        -- PASO 5: monto total = moto con descuento + accesorios. Se calcula
        -- ANTES del INSERT para que la venta nazca con su monto definitivo.
        DECLARE @monto_total DECIMAL(12,2) = @precio_venta_moto +
            (SELECT ISNULL(SUM(cantidad * precio_pactado), 0) FROM @accesorios);

        -- PASO 6 [TAREA 1]: encabezado de venta.
        INSERT INTO dbo.venta (fecha, metodo_pago, precio_venta_moto, monto_total,
                               estado, dni_cliente, dni_vendedor, numero_chasis)
        VALUES (@fecha, @metodo, @precio_venta_moto, @monto_total,
                'efectuada', @dni_cliente, @dni_vendedor, @numero_chasis);

        SET @cod_venta = CAST(SCOPE_IDENTITY() AS INT);

        -- PASO 7 [TAREA 2]: detalle de venta, con el precio pactado congelado.
        INSERT INTO dbo.detalle_venta_accesorio (cod_venta, id_accesorio, cantidad, precio_pactado)
        SELECT @cod_venta, id_accesorio, cantidad, precio_pactado
        FROM @accesorios;

        -- PASO 8 [TAREA 4]: stock.
        -- Accesorios: UN solo UPDATE que descuenta SOLO si alcanza el stock
        -- (WHERE stock >= cantidad): chequeo y descuento en la misma sentencia,
        -- sin hueco para otra venta. Si alguna fila no se actualizo, no habia
        -- stock suficiente: el CATCH deshace TODO (incluida la venta del PASO 6).
        UPDATE ac
        SET ac.stock = ac.stock - a.cantidad
        FROM dbo.accesorio AS ac
        JOIN @accesorios   AS a ON a.id_accesorio = ac.id_accesorio
        WHERE ac.stock >= a.cantidad;

        DECLARE @actualizados INT = @@ROWCOUNT;

        IF @actualizados <> (SELECT COUNT(*) FROM @accesorios)
            THROW 50008, 'Sin stock suficiente de accesorio', 1;

        -- Moto: 1 unidad menos en el stock del modelo (ya bloqueado en el PASO 1).
        UPDATE dbo.modelo_motocicleta
        SET stock_disponible = stock_disponible - 1
        WHERE id_modelo = @id_modelo;

        -- PASO 9: regla RN5 - el cliente pasa a estado "comprador".
        UPDATE dbo.cliente
        SET estado = 'comprador'
        WHERE dni_cliente = @dni_cliente AND estado <> 'comprador';

        -- PASO 10: control final (RN6 / RN11). Se recalcula el total con
        -- fn_total_venta leyendo el detalle ya guardado y se compara con el
        -- monto grabado en el encabezado.
        IF ISNULL(dbo.fn_total_venta(@precio_venta_moto, @cod_venta), -1) <> @monto_total
            THROW 50019, 'Total de venta inconsistente', 1;

        -- [TAREA 6]: sin errores hasta aca -> se confirma TODO.
        COMMIT;
    END TRY
    BEGIN CATCH
        -- Cualquier error cae aca: se deshace todo (venta, detalle, stocks) y se
        -- re-lanza el MISMO error para que lo vea quien llamo al procedimiento.
        IF @@TRANCOUNT > 0
            ROLLBACK;

        THROW;
    END CATCH
END;
GO

PRINT '02_procedimientos.sql ejecutado: sp_actualizar_precio_modelo, sp_reporte_ventas_periodo, sp_generar_cotizacion y sp_RegistrarVentaCompleta creados.';
GO
