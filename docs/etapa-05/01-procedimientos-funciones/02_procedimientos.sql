-- ============================================================================
-- ETAPA V - TEMA 1: PROCEDIMIENTOS Y FUNCIONES ALMACENADAS
-- Archivo: docs/etapa-05/01-procedimientos-funciones/02_procedimientos.sql
-- Sistema: X Motors - Base de Datos I - Grupo 49 - FaCENA (UNNE)
--
-- Procedimientos de administracion de catalogo y reportes.
-- Los procedimientos transaccionales de venta/cancelacion estan en:
--   docs/etapa-05/02-transacciones/01_sp_registrar_venta.sql
--   docs/etapa-05/02-transacciones/02_sp_cambiar_estado_venta.sql
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

PRINT '02_procedimientos.sql ejecutado: sp_actualizar_precio_modelo, sp_reporte_ventas_periodo y sp_generar_cotizacion creados.';
GO
