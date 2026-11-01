/* ============================================================================
   ETAPA V - TEMA 2: TRANSACCIONES
   Sistema de Gestion de Ventas de Motos - X Motors - Grupo 49
   Motor: SQL Server 2016 SP1 o superior (probado en SQL Server 2025 Express)

   Objetivo:
     Demostrar BEGIN TRAN, COMMIT y ROLLBACK con tres casos independientes:
       1. Venta correcta: venta + detalle + descuento de stock + COMMIT.
       2. Stock insuficiente: intento de venta + ROLLBACK.
       3. Error de integridad: cliente/chasis invalido + ROLLBACK + THROW.

   Chasis reservado para esta ejecucion:
     HONCB500F004 (modelo 11 - Honda CB500F, stock inicial 3)

   Notas:
     * No se modifican DDL, DML ni consultas de etapas anteriores.
     * El script es repetible: al inicio limpia solo las ventas del chasis demo
       y la unidad ficticia usada en el demo 2.
     * La venta commiteada se cancela al final para restaurar el stock.
     * Las pruebas usan datos reales del lote de Etapa III.
     * SQL sin tildes para evitar problemas de encoding.
   ============================================================================ */

USE [X MOTORS];
GO

/* La tabla venta tiene un indice filtrado (ux_venta_chasis_vigente).
   SQL Server exige estas opciones para poder insertar/actualizar/borrar. */
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;
GO

SET NOCOUNT ON;
SET IMPLICIT_TRANSACTIONS OFF;
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
GO

PRINT '============================================================';
PRINT ' ETAPA V - TEMA 2: DEMOS DE TRANSACCIONES';
PRINT '============================================================';
PRINT 'Version       : ' + CAST(@@VERSION AS VARCHAR(200));
PRINT 'Base de datos : ' + DB_NAME();
PRINT 'Usuario       : ' + USER_NAME();
PRINT 'Fecha/hora    : ' + CONVERT(VARCHAR(19), SYSDATETIME(), 120);
PRINT 'Chasis demo   : HONCB500F004';
PRINT '';
GO

/* ============================================================================
   0. LIMPIEZA INICIAL
   Deja el escenario en el estado base, sin importar si el script se ejecuto
   antes. Solo toca el chasis reservado HONCB500F004 y la unidad ficticia del
   demo 2.
   ============================================================================ */
PRINT '--- 0. LIMPIEZA INICIAL DEL ESCENARIO ---';
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    /* Si quedo una venta efectuada de una corrida anterior, restaurar stock. */
    UPDATE mm
    SET mm.stock_disponible = mm.stock_disponible + 1
    FROM dbo.modelo_motocicleta AS mm
    INNER JOIN dbo.motocicleta AS m
        ON m.id_modelo = mm.id_modelo
    INNER JOIN dbo.venta AS v
        ON v.numero_chasis = m.numero_chasis
    WHERE v.numero_chasis = 'HONCB500F004'
      AND v.estado = 'efectuada';

    UPDATE a
    SET a.stock = a.stock + d.cantidad
    FROM dbo.accesorio AS a
    INNER JOIN dbo.detalle_venta_accesorio AS d
        ON d.id_accesorio = a.id_accesorio
    INNER JOIN dbo.venta AS v
        ON v.cod_venta = d.cod_venta
    WHERE v.numero_chasis = 'HONCB500F004'
      AND v.estado = 'efectuada';

    /* Borrar detalles y ventas del chasis demo. */
    DELETE d
    FROM dbo.detalle_venta_accesorio AS d
    INNER JOIN dbo.venta AS v
        ON v.cod_venta = d.cod_venta
    WHERE v.numero_chasis = 'HONCB500F004';

    DELETE FROM dbo.venta
    WHERE numero_chasis = 'HONCB500F004';

    /* Limpiar la unidad ficticia del demo 2, si quedo de una corrida fallida. */
    DELETE d
    FROM dbo.detalle_venta_accesorio AS d
    INNER JOIN dbo.venta AS v
        ON v.cod_venta = d.cod_venta
    WHERE v.numero_chasis = 'TEST-XR150-ETAPA-V';

    DELETE FROM dbo.venta
    WHERE numero_chasis = 'TEST-XR150-ETAPA-V';

    DELETE FROM dbo.motocicleta
    WHERE numero_chasis = 'TEST-XR150-ETAPA-V';

    COMMIT TRANSACTION;
    PRINT 'Limpieza inicial: OK';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    SELECT
        'LIMPIEZA INICIAL' AS paso,
        ERROR_NUMBER() AS error_number,
        ERROR_MESSAGE() AS error_message,
        XACT_STATE() AS xact_state,
        @@TRANCOUNT AS trancount;
    THROW;
END CATCH;
GO

SET XACT_ABORT OFF;
GO

/* ============================================================================
   BASELINE
   Guarda los conteos y stocks de referencia en una tabla temporal.
   ============================================================================ */
IF OBJECT_ID('tempdb..#baseline') IS NOT NULL
    DROP TABLE #baseline;

CREATE TABLE #baseline (
    ventas            INT NOT NULL,
    detalles          INT NOT NULL,
    stock_modelo_11   INT NOT NULL,
    stock_accesorio_1 INT NOT NULL,
    stock_accesorio_2 INT NOT NULL,
    ventas_chasis_demo INT NOT NULL
);

INSERT INTO #baseline (
    ventas,
    detalles,
    stock_modelo_11,
    stock_accesorio_1,
    stock_accesorio_2,
    ventas_chasis_demo
)
SELECT
    (SELECT COUNT(*) FROM dbo.venta),
    (SELECT COUNT(*) FROM dbo.detalle_venta_accesorio),
    (SELECT stock_disponible FROM dbo.modelo_motocicleta WHERE id_modelo = 11),
    (SELECT stock FROM dbo.accesorio WHERE id_accesorio = 1),
    (SELECT stock FROM dbo.accesorio WHERE id_accesorio = 2),
    (SELECT COUNT(*) FROM dbo.venta WHERE numero_chasis = 'HONCB500F004');

IF OBJECT_ID('tempdb..#demo') IS NOT NULL
    DROP TABLE #demo;

CREATE TABLE #demo (
    cod_venta INT NOT NULL
);

SELECT
    'BASELINE' AS momento,
    ventas,
    detalles,
    stock_modelo_11,
    stock_accesorio_1,
    stock_accesorio_2,
    ventas_chasis_demo
FROM #baseline;
GO

/* ============================================================================
   DEMO 1. VENTA CORRECTA: BEGIN TRAN + COMMIT
   - Inserta la venta y su detalle.
   - Descuenta stock de la moto y del accesorio.
   - Confirma con COMMIT.
   ============================================================================ */
PRINT '';
PRINT '--- 1. VENTA CORRECTA: BEGIN TRAN + COMMIT ---';

DECLARE @cod_venta INT;
DECLARE @fecha DATE = CAST(GETDATE() AS DATE);
DECLARE @precio_moto DECIMAL(12,2) = 8500000.00;
DECLARE @precio_accesorio DECIMAL(12,2) = 185000.00;
DECLARE @stock_modelo INT;
DECLARE @stock_accesorio INT;

BEGIN TRY
    BEGIN TRANSACTION;

    SELECT @@TRANCOUNT AS trancount_dentro_demo1;

    /* Bloqueo pesimista del stock y validacion de disponibilidad. */
    SELECT @stock_modelo = stock_disponible
    FROM dbo.modelo_motocicleta WITH (UPDLOCK, HOLDLOCK)
    WHERE id_modelo = 11;

    IF @stock_modelo IS NULL
        THROW 50017, 'Modelo 11 inexistente.', 1;

    IF @stock_modelo < 1
        THROW 50004, 'Sin stock disponible para el modelo 11.', 1;

    SELECT @stock_accesorio = stock
    FROM dbo.accesorio WITH (UPDLOCK, HOLDLOCK)
    WHERE id_accesorio = 1;

    IF @stock_accesorio IS NULL
        THROW 50006, 'Accesorio 1 inexistente.', 1;

    IF @stock_accesorio < 1
        THROW 50008, 'Sin stock disponible para el accesorio 1.', 1;

    IF EXISTS (
        SELECT 1
        FROM dbo.venta WITH (UPDLOCK, HOLDLOCK)
        WHERE numero_chasis = 'HONCB500F004'
          AND estado = 'efectuada'
    )
        THROW 50005, 'El chasis HONCB500F004 ya tiene una venta efectuada.', 1;

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
        'efectivo',
        @precio_moto,
        @precio_moto + @precio_accesorio,
        'efectuada',
        30456781,
        31222333,
        'HONCB500F004'
    );

    SET @cod_venta = SCOPE_IDENTITY();

    INSERT INTO dbo.detalle_venta_accesorio (
        cod_venta,
        id_accesorio,
        cantidad,
        precio_pactado
    )
    VALUES (
        @cod_venta,
        1,
        1,
        @precio_accesorio
    );

    UPDATE dbo.modelo_motocicleta
    SET stock_disponible = stock_disponible - 1
    WHERE id_modelo = 11;

    UPDATE dbo.accesorio
    SET stock = stock - 1
    WHERE id_accesorio = 1;

    COMMIT TRANSACTION;

    INSERT INTO #demo (cod_venta) VALUES (@cod_venta);

    PRINT 'COMMIT OK. cod_venta = ' + CAST(@cod_venta AS VARCHAR(20));
    PRINT 'Venta y detalle insertados; stock descontado.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    SELECT
        'DEMO 1 - ERROR' AS paso,
        ERROR_NUMBER() AS error_number,
        ERROR_MESSAGE() AS error_message,
        XACT_STATE() AS xact_state,
        @@TRANCOUNT AS trancount;
    THROW;
END CATCH;
GO

/* Verificacion del demo 1 */
SELECT
    'DESPUES DEMO 1' AS momento,
    (SELECT COUNT(*) FROM dbo.venta) AS ventas,
    (SELECT COUNT(*) FROM dbo.detalle_venta_accesorio) AS detalles,
    (SELECT stock_disponible FROM dbo.modelo_motocicleta WHERE id_modelo = 11) AS stock_modelo_11,
    (SELECT stock FROM dbo.accesorio WHERE id_accesorio = 1) AS stock_accesorio_1,
    (SELECT COUNT(*) FROM dbo.venta WHERE numero_chasis = 'HONCB500F004') AS ventas_chasis_demo;

SELECT
    'ESTADO TRAN POST DEMO 1' AS momento,
    XACT_STATE() AS xact_state,
    @@TRANCOUNT AS trancount;

SELECT
    v.cod_venta,
    v.fecha,
    v.metodo_pago,
    v.precio_venta_moto,
    v.monto_total,
    v.estado,
    v.numero_chasis,
    d.id_accesorio,
    d.cantidad,
    d.precio_pactado
FROM dbo.venta AS v
LEFT JOIN dbo.detalle_venta_accesorio AS d
    ON d.cod_venta = v.cod_venta
WHERE v.cod_venta = (SELECT cod_venta FROM #demo);
GO

/* ============================================================================
   DEMO 2. STOCK INSUFICIENTE: BEGIN TRAN + ROLLBACK
   - Inserta una unidad ficticia para el modelo 2 (XR 150L), que tiene stock 0.
   - Intenta registrar la venta y su detalle.
   - Detecta stock 0, lanza error y hace ROLLBACK.
   - Verifica que no queden venta, detalle, moto ficticia ni descuento de stock.
   ============================================================================ */
PRINT '';
PRINT '--- 2. STOCK INSUFICIENTE: BEGIN TRAN + ROLLBACK ---';

DECLARE @id_modelo_sin_stock INT = 2;
DECLARE @stock_sin_stock INT;

BEGIN TRY
    BEGIN TRANSACTION;

    SELECT @@TRANCOUNT AS trancount_dentro_demo2;

    /* Unidad ficticia: permite intentar la venta sin chocar con el indice
       filtrado ux_venta_chasis_vigente ni con las ventas del lote real. */
    INSERT INTO dbo.motocicleta (numero_chasis, numero_motor, id_modelo)
    VALUES ('TEST-XR150-ETAPA-V', 'TEST-MOT-XR150-ETAPA-V', @id_modelo_sin_stock);

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
        CAST(GETDATE() AS DATE),
        'efectivo',
        4900000.00,
        4998000.00,
        'efectuada',
        30456781,
        31222333,
        'TEST-XR150-ETAPA-V'
    );

    DECLARE @cod_venta_demo2 INT = SCOPE_IDENTITY();

    INSERT INTO dbo.detalle_venta_accesorio (
        cod_venta,
        id_accesorio,
        cantidad,
        precio_pactado
    )
    VALUES (
        @cod_venta_demo2,
        2,
        1,
        98000.00
    );

    /* Recien ahora se controla el stock: el modelo 2 tiene 0 unidades. */
    SELECT @stock_sin_stock = stock_disponible
    FROM dbo.modelo_motocicleta WITH (UPDLOCK, HOLDLOCK)
    WHERE id_modelo = @id_modelo_sin_stock;

    IF @stock_sin_stock IS NULL
        THROW 50017, 'Modelo sin stock inexistente.', 1;

    IF @stock_sin_stock <= 0
        THROW 50004, 'Sin stock disponible para el modelo 2 (XR 150L).', 1;

    /* Si hubiera stock, se descontaria y se confirmaria. */
    UPDATE dbo.modelo_motocicleta
    SET stock_disponible = stock_disponible - 1
    WHERE id_modelo = @id_modelo_sin_stock;

    UPDATE dbo.accesorio
    SET stock = stock - 1
    WHERE id_accesorio = 1;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    DECLARE @xact_state_demo2 INT = XACT_STATE();
    DECLARE @trancount_demo2 INT = @@TRANCOUNT;

    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    SELECT
        'DEMO 2 - ERROR CONTROLADO' AS paso,
        ERROR_NUMBER() AS error_number,
        ERROR_MESSAGE() AS error_message,
        @xact_state_demo2 AS xact_state_en_catch,
        @trancount_demo2 AS trancount_en_catch,
        XACT_STATE() AS xact_state_post_rollback,
        @@TRANCOUNT AS trancount_post_rollback;
END CATCH;
GO

/* Verificacion del demo 2: no debe quedar ninguna fila ni cambio de stock. */
SELECT
    'DESPUES DEMO 2' AS momento,
    (SELECT COUNT(*) FROM dbo.venta) AS ventas,
    (SELECT COUNT(*) FROM dbo.detalle_venta_accesorio) AS detalles,
    (SELECT stock_disponible FROM dbo.modelo_motocicleta WHERE id_modelo = 2) AS stock_modelo_2,
    (SELECT stock FROM dbo.accesorio WHERE id_accesorio = 1) AS stock_accesorio_1,
    (SELECT stock FROM dbo.accesorio WHERE id_accesorio = 2) AS stock_accesorio_2,
    (SELECT COUNT(*) FROM dbo.venta WHERE numero_chasis = 'TEST-XR150-ETAPA-V') AS ventas_test,
    (SELECT COUNT(*) FROM dbo.detalle_venta_accesorio AS d
        INNER JOIN dbo.venta AS v ON v.cod_venta = d.cod_venta
        WHERE v.numero_chasis = 'TEST-XR150-ETAPA-V') AS detalles_test,
    (SELECT COUNT(*) FROM dbo.motocicleta WHERE numero_chasis = 'TEST-XR150-ETAPA-V') AS motos_test;

SELECT
    'ESTADO TRAN POST DEMO 2' AS momento,
    XACT_STATE() AS xact_state,
    @@TRANCOUNT AS trancount;
GO

/* ============================================================================
   DEMO 3. ERROR DE INTEGRIDAD: BEGIN TRAN + ROLLBACK + THROW
   - Intenta insertar una venta con cliente y chasis inexistentes.
   - La FK falla; XACT_ABORT ON deja la transaccion no confirmable.
   - Captura XACT_STATE() y @@TRANCOUNT, hace ROLLBACK y relanza con THROW.
   ============================================================================ */
PRINT '';
PRINT '--- 3. ERROR DE INTEGRIDAD: BEGIN TRAN + ROLLBACK + THROW ---';
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    SELECT @@TRANCOUNT AS trancount_dentro_demo3;

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
        CAST(GETDATE() AS DATE),
        'efectivo',
        8500000.00,
        8500000.00,
        'efectuada',
        99999999,
        31222333,
        'CHASIS-INVALIDO-ETAPA-V'
    );

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    DECLARE @xact_state_demo3 INT = XACT_STATE();
    DECLARE @trancount_demo3 INT = @@TRANCOUNT;

    SELECT
        'DEMO 3 - ERROR DE INTEGRIDAD' AS paso,
        ERROR_NUMBER() AS error_number,
        ERROR_MESSAGE() AS error_message,
        ERROR_LINE() AS error_line,
        @xact_state_demo3 AS xact_state_en_catch,
        @trancount_demo3 AS trancount_en_catch;

    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    SELECT
        'DEMO 3 - DESPUES DEL ROLLBACK' AS paso,
        XACT_STATE() AS xact_state_post_rollback,
        @@TRANCOUNT AS trancount_post_rollback;

    /* Relanza el error original para que sqlcmd muestre el fallo intencional. */
    THROW;
END CATCH;
GO

/* Verificacion del demo 3: el rollback no debe dejar filas ni cambios. */
PRINT '';
PRINT '--- 3b. VERIFICACION DEL ROLLBACK DEL DEMO 3 ---';

SELECT
    'DESPUES DEMO 3' AS momento,
    (SELECT COUNT(*) FROM dbo.venta) AS ventas,
    (SELECT COUNT(*) FROM dbo.detalle_venta_accesorio) AS detalles,
    (SELECT stock_disponible FROM dbo.modelo_motocicleta WHERE id_modelo = 11) AS stock_modelo_11,
    (SELECT stock FROM dbo.accesorio WHERE id_accesorio = 1) AS stock_accesorio_1,
    (SELECT stock FROM dbo.accesorio WHERE id_accesorio = 2) AS stock_accesorio_2,
    (SELECT COUNT(*) FROM dbo.venta WHERE numero_chasis = 'CHASIS-INVALIDO-ETAPA-V') AS ventas_invalidas;

SELECT
    'ESTADO TRAN POST DEMO 3' AS momento,
    XACT_STATE() AS xact_state,
    @@TRANCOUNT AS trancount;
GO

/* ============================================================================
   4. CANCELACION DE LA VENTA COMMITEADA
   Restaura el stock de la moto y del accesorio. La venta queda como
   'cancelada' para conservar la evidencia (no se borra).
   ============================================================================ */
PRINT '';
PRINT '--- 4. CANCELACION DE LA VENTA COMMITEADA (RESTAURA STOCK) ---';
SET XACT_ABORT OFF;

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @cod_venta_cancelar INT = (SELECT cod_venta FROM #demo);

    IF @cod_venta_cancelar IS NULL
        THROW 50012, 'No hay venta demo para cancelar.', 1;

    UPDATE dbo.venta
    SET estado = 'cancelada'
    WHERE cod_venta = @cod_venta_cancelar
      AND estado = 'efectuada';

    IF @@ROWCOUNT <> 1
        THROW 50013, 'La venta demo no estaba efectuada.', 1;

    UPDATE mm
    SET mm.stock_disponible = mm.stock_disponible + 1
    FROM dbo.modelo_motocicleta AS mm
    INNER JOIN dbo.motocicleta AS m
        ON m.id_modelo = mm.id_modelo
    INNER JOIN dbo.venta AS v
        ON v.numero_chasis = m.numero_chasis
    WHERE v.cod_venta = @cod_venta_cancelar;

    UPDATE a
    SET a.stock = a.stock + d.cantidad
    FROM dbo.accesorio AS a
    INNER JOIN dbo.detalle_venta_accesorio AS d
        ON d.id_accesorio = a.id_accesorio
    WHERE d.cod_venta = @cod_venta_cancelar;

    COMMIT TRANSACTION;

    PRINT 'Cancelacion OK. Venta ' + CAST(@cod_venta_cancelar AS VARCHAR(20)) + ' quedo en estado cancelada.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    SELECT
        'CANCELACION - ERROR' AS paso,
        ERROR_NUMBER() AS error_number,
        ERROR_MESSAGE() AS error_message,
        XACT_STATE() AS xact_state,
        @@TRANCOUNT AS trancount;
    THROW;
END CATCH;
GO

/* ============================================================================
   VERIFICACION FINAL
   ============================================================================ */
SELECT
    'FINAL' AS momento,
    (SELECT COUNT(*) FROM dbo.venta) AS ventas,
    (SELECT COUNT(*) FROM dbo.detalle_venta_accesorio) AS detalles,
    (SELECT stock_disponible FROM dbo.modelo_motocicleta WHERE id_modelo = 11) AS stock_modelo_11,
    (SELECT stock FROM dbo.accesorio WHERE id_accesorio = 1) AS stock_accesorio_1,
    (SELECT stock FROM dbo.accesorio WHERE id_accesorio = 2) AS stock_accesorio_2,
    (SELECT COUNT(*) FROM dbo.venta WHERE numero_chasis = 'HONCB500F004') AS ventas_chasis_demo,
    (SELECT COUNT(*) FROM dbo.venta WHERE numero_chasis = 'CHASIS-INVALIDO-ETAPA-V') AS ventas_invalidas,
    (SELECT COUNT(*) FROM dbo.venta WHERE numero_chasis = 'TEST-XR150-ETAPA-V') AS ventas_test,
    (SELECT COUNT(*) FROM dbo.motocicleta WHERE numero_chasis = 'TEST-XR150-ETAPA-V') AS motos_test;

SELECT
    'ESTADO TRAN FINAL' AS momento,
    XACT_STATE() AS xact_state,
    @@TRANCOUNT AS trancount;

SELECT
    v.cod_venta,
    v.fecha,
    v.metodo_pago,
    v.precio_venta_moto,
    v.monto_total,
    v.estado,
    v.numero_chasis
FROM dbo.venta AS v
WHERE v.cod_venta = (SELECT cod_venta FROM #demo);

SELECT
    b.ventas AS ventas_baseline,
    (SELECT COUNT(*) FROM dbo.venta) AS ventas_final,
    b.detalles AS detalles_baseline,
    (SELECT COUNT(*) FROM dbo.detalle_venta_accesorio) AS detalles_final,
    b.stock_modelo_11 AS stock_modelo_baseline,
    (SELECT stock_disponible FROM dbo.modelo_motocicleta WHERE id_modelo = 11) AS stock_modelo_final,
    b.stock_accesorio_1 AS stock_accesorio_1_baseline,
    (SELECT stock FROM dbo.accesorio WHERE id_accesorio = 1) AS stock_accesorio_1_final,
    b.stock_accesorio_2 AS stock_accesorio_2_baseline,
    (SELECT stock FROM dbo.accesorio WHERE id_accesorio = 2) AS stock_accesorio_2_final
FROM #baseline AS b;

SELECT
    CASE
        WHEN (SELECT COUNT(*) FROM dbo.venta
              WHERE numero_chasis = 'HONCB500F004' AND estado = 'cancelada') = 1
            THEN 'OK' ELSE 'FALLA'
    END AS venta_demo_cancelada,
    CASE
        WHEN (SELECT stock_disponible FROM dbo.modelo_motocicleta WHERE id_modelo = 11)
             = (SELECT stock_modelo_11 FROM #baseline)
            THEN 'OK' ELSE 'FALLA'
    END AS stock_modelo_restaurado,
    CASE
        WHEN (SELECT stock FROM dbo.accesorio WHERE id_accesorio = 1)
             = (SELECT stock_accesorio_1 FROM #baseline)
            THEN 'OK' ELSE 'FALLA'
    END AS stock_accesorio_1_restaurado,
    CASE
        WHEN (SELECT stock FROM dbo.accesorio WHERE id_accesorio = 2)
             = (SELECT stock_accesorio_2 FROM #baseline)
            THEN 'OK' ELSE 'FALLA'
    END AS stock_accesorio_2_restaurado,
    CASE
        WHEN (SELECT COUNT(*) FROM dbo.venta WHERE numero_chasis = 'TEST-XR150-ETAPA-V') = 0
            THEN 'OK' ELSE 'FALLA'
    END AS sin_venta_stock_insuficiente,
    CASE
        WHEN (SELECT COUNT(*) FROM dbo.detalle_venta_accesorio AS d
              INNER JOIN dbo.venta AS v ON v.cod_venta = d.cod_venta
              WHERE v.numero_chasis = 'TEST-XR150-ETAPA-V') = 0
            THEN 'OK' ELSE 'FALLA'
    END AS sin_detalle_stock_insuficiente,
    CASE
        WHEN (SELECT COUNT(*) FROM dbo.venta WHERE numero_chasis = 'CHASIS-INVALIDO-ETAPA-V') = 0
            THEN 'OK' ELSE 'FALLA'
    END AS sin_venta_error_integridad;

IF OBJECT_ID('tempdb..#baseline') IS NOT NULL
    DROP TABLE #baseline;

IF OBJECT_ID('tempdb..#demo') IS NOT NULL
    DROP TABLE #demo;
GO
