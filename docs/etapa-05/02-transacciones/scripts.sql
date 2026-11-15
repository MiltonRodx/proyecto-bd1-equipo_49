/* ============================================================================
   ETAPA V - TEMA 2: TRANSACCIONES
   Archivo: docs/etapa-05/02-transacciones/scripts.sql
   Sistema de Gestion de Ventas de Motos - X Motors - Grupo 49
   Motor: SQL Server 2016 SP1 o superior (probado en SQL Server 2025 Express)

   -------------------------------------------------------------------------
   QUE ES UNA TRANSACCION (para la defensa)
   -------------------------------------------------------------------------
   Un conjunto de operaciones que se ejecutan como UNA sola unidad de trabajo:
   o se aplican todas (COMMIT) o no se aplica ninguna (ROLLBACK).
   Una venta toca varias tablas (venta, detalle, stock de moto y de accesorio):
   no puede quedar a medias. Garantiza las propiedades ACID:
     A (Atomicidad)   -> todo o nada.                    Se ve en el DEMO 2 y 5.
     C (Consistencia) -> la base nunca viola sus reglas. Se ve en el DEMO 3
                         (la clave foranea rechaza el dato invalido).
     I (Aislamiento)  -> dos operaciones simultaneas no se pisan. Lo dan los
                         bloqueos UPDLOCK/HOLDLOCK (explicados en el DEMO 1).
     D (Durabilidad)  -> lo confirmado con COMMIT queda guardado. DEMO 1.

   -------------------------------------------------------------------------
   QUE DEMUESTRA ESTE SCRIPT (5 casos independientes)
   -------------------------------------------------------------------------
     1. Venta correcta:       venta + detalle + descuento de stock + COMMIT.
     2. Stock insuficiente:   se insertan venta y detalle, se detecta que no
                              hay stock y ROLLBACK deshace TODO.
     3. Error de integridad:  FK invalida + XACT_ABORT + ROLLBACK.
     4. Cancelacion:          vuelve a su lugar el stock de la venta del demo 1.
     5. Integracion (tema 1): sp_RegistrarVentaCompleta falla por falta de
                              stock de un accesorio y no deja nada registrado.

   COMO CORRERLO (para que se vea todo en orden)
     - sqlcmd:  sqlcmd -S localhost -U sa -C -i scripts.sql
     - DBeaver: ejecutar como script (Alt+X); cada SELECT sale en una pestana.

   Chasis reservado para el demo: HONCB500F004 (modelo 11, Honda CB500F,
   stock inicial 3). Unidad ficticia del demo 2: TEST-XR150-ETAPA-V (modelo 2,
   XR 150L, que debe tener stock 0).

   Notas:
     * No se modifican DDL, DML ni consultas de etapas anteriores.
     * Es repetible: al inicio limpia solo el chasis demo y la unidad ficticia.
     * Al terminar queda todo como al empezar (stocks restaurados); la unica
       huella es la venta demo en estado 'cancelada'.
     * Requiere haber ejecutado 02_procedimientos.sql (para el demo 5).
     * SQL sin tildes para evitar problemas de encoding.
   ============================================================================ */

USE [X MOTORS];
GO

/* La tabla venta tiene un indice filtrado (ux_venta_chasis_vigente) que impide
   dos ventas 'efectuada' del mismo chasis. SQL Server exige estas opciones SET
   para poder insertar, actualizar o borrar filas de una tabla con ese indice. */
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;
GO

SET NOCOUNT ON;
SET IMPLICIT_TRANSACTIONS OFF;                       -- las transacciones se abren SOLO con BEGIN TRAN
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;      -- nivel de aislamiento por defecto
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
   Deja el escenario en estado base aunque el script ya se haya corrido antes.
   Solo toca el chasis HONCB500F004 y la unidad ficticia del demo 2.
   Es una transaccion en si misma: si algo falla, no queda la limpieza a medias.
   ============================================================================ */
PRINT '--- 0. LIMPIEZA INICIAL DEL ESCENARIO ---';

-- XACT_ABORT ON: ante cualquier error SQL Server cancela la transaccion
-- entera. Es lo mas seguro para un script de limpieza.
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    /* Si quedo una venta efectuada de una corrida anterior, se restaura el
       stock de la moto y de los accesorios antes de borrarla. */
    UPDATE mm
    SET mm.stock_disponible = mm.stock_disponible + 1
    FROM dbo.modelo_motocicleta AS mm
    INNER JOIN dbo.motocicleta AS m ON m.id_modelo = mm.id_modelo
    INNER JOIN dbo.venta AS v       ON v.numero_chasis = m.numero_chasis
    WHERE v.numero_chasis = 'HONCB500F004'
      AND v.estado = 'efectuada';

    UPDATE a
    SET a.stock = a.stock + d.cantidad
    FROM dbo.accesorio AS a
    INNER JOIN dbo.detalle_venta_accesorio AS d ON d.id_accesorio = a.id_accesorio
    INNER JOIN dbo.venta AS v                   ON v.cod_venta = d.cod_venta
    WHERE v.numero_chasis = 'HONCB500F004'
      AND v.estado = 'efectuada';

    /* Se borran detalles y ventas del chasis demo (primero el detalle, que es
       la tabla hija de la FK). */
    DELETE d
    FROM dbo.detalle_venta_accesorio AS d
    INNER JOIN dbo.venta AS v ON v.cod_venta = d.cod_venta
    WHERE v.numero_chasis = 'HONCB500F004';

    DELETE FROM dbo.venta
    WHERE numero_chasis = 'HONCB500F004';

    /* Unidad ficticia del demo 2, por si quedo de una corrida fallida. */
    DELETE d
    FROM dbo.detalle_venta_accesorio AS d
    INNER JOIN dbo.venta AS v ON v.cod_venta = d.cod_venta
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
        ERROR_NUMBER()     AS error_number,
        ERROR_MESSAGE()    AS error_message,
        XACT_STATE()       AS xact_state,
        @@TRANCOUNT        AS trancount;
    THROW;      -- aca SI se relanza: si la limpieza falla, no tiene sentido seguir
END CATCH;
GO

SET XACT_ABORT OFF;
GO

/* ============================================================================
   BASELINE
   Foto del estado inicial (conteos y stocks) en una tabla temporal. Al final
   se compara contra el estado final para demostrar que no quedo nada de mas.
   (#nombre = tabla temporal de la sesion; sobrevive a los GO.)
   ============================================================================ */
IF OBJECT_ID('tempdb..#baseline') IS NOT NULL
    DROP TABLE #baseline;

CREATE TABLE #baseline (
    ventas             INT NOT NULL,
    detalles           INT NOT NULL,
    stock_modelo_11    INT NOT NULL,
    stock_modelo_2     INT NOT NULL,
    stock_accesorio_1  INT NOT NULL,
    stock_accesorio_2  INT NOT NULL,
    ventas_chasis_demo INT NOT NULL
);

INSERT INTO #baseline (
    ventas, detalles, stock_modelo_11, stock_modelo_2,
    stock_accesorio_1, stock_accesorio_2, ventas_chasis_demo
)
SELECT
    (SELECT COUNT(*) FROM dbo.venta),
    (SELECT COUNT(*) FROM dbo.detalle_venta_accesorio),
    (SELECT stock_disponible FROM dbo.modelo_motocicleta WHERE id_modelo = 11),
    (SELECT stock_disponible FROM dbo.modelo_motocicleta WHERE id_modelo = 2),
    (SELECT stock FROM dbo.accesorio WHERE id_accesorio = 1),
    (SELECT stock FROM dbo.accesorio WHERE id_accesorio = 2),
    (SELECT COUNT(*) FROM dbo.venta WHERE numero_chasis = 'HONCB500F004');

/* Guarda el cod_venta de la venta commiteada en el demo 1 (para cancelarla
   en la seccion 4). */
IF OBJECT_ID('tempdb..#demo') IS NOT NULL
    DROP TABLE #demo;

CREATE TABLE #demo (cod_venta INT NOT NULL);

SELECT 'BASELINE' AS momento, *
FROM #baseline;
GO

/* ============================================================================
   DEMO 1. VENTA CORRECTA: BEGIN TRAN + COMMIT
   Un cliente compra una Honda CB500F con un accesorio.
   Pasos: validar -> insertar venta -> insertar detalle -> descontar stock
          -> COMMIT.
   Como explicarlo: "las cuatro escrituras se confirman juntas con el COMMIT;
   recien ahi quedan guardadas de forma permanente (Durabilidad)".
   ============================================================================ */
PRINT '';
PRINT '--- 1. VENTA CORRECTA: BEGIN TRAN + COMMIT ---';
SET XACT_ABORT OFF;

DECLARE @cod_venta        INT;
DECLARE @fecha            DATE          = CAST(GETDATE() AS DATE);
DECLARE @precio_moto      DECIMAL(12,2) = 8500000.00;
DECLARE @precio_accesorio DECIMAL(12,2) = 185000.00;
DECLARE @stock_modelo     INT;
DECLARE @stock_accesorio  INT;

BEGIN TRY
    BEGIN TRANSACTION;

    -- @@TRANCOUNT cuenta las transacciones abiertas: aca vale 1.
    SELECT @@TRANCOUNT AS trancount_dentro_demo1;

    /* ---- Bloqueo pesimista + validacion de stock ----------------------------
       UPDLOCK : al LEER la fila, SQL Server la bloquea "con intencion de
                 modificarla". Si otra sesion intenta leer esa misma fila con
                 UPDLOCK, espera. Evita que dos ventas lean "stock = 1" al
                 mismo tiempo y las dos vendan la ultima unidad.
       HOLDLOCK: mantiene el bloqueo hasta el COMMIT/ROLLBACK (sin esto se
                 liberaria apenas termina el SELECT). Asi lo que validamos sigue
                 siendo cierto cuando escribimos.
       Juntos evitan las "race conditions" (condiciones de carrera). -------- */
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

    /* El chasis no puede tener otra venta efectuada. Mismo criterio de bloqueo. */
    IF EXISTS (
        SELECT 1
        FROM dbo.venta WITH (UPDLOCK, HOLDLOCK)
        WHERE numero_chasis = 'HONCB500F004'
          AND estado = 'efectuada'
    )
        THROW 50005, 'El chasis HONCB500F004 ya tiene una venta efectuada.', 1;

    /* Escritura 1: encabezado de la venta. */
    INSERT INTO dbo.venta (
        fecha, metodo_pago, precio_venta_moto, monto_total,
        estado, dni_cliente, dni_vendedor, numero_chasis
    )
    VALUES (
        @fecha, 'efectivo', @precio_moto, @precio_moto + @precio_accesorio,
        'efectuada', 30456781, 31222333, 'HONCB500F004'
    );

    SET @cod_venta = SCOPE_IDENTITY();     -- id que acaba de generar el INSERT

    /* Escritura 2: detalle (el accesorio vendido). */
    INSERT INTO dbo.detalle_venta_accesorio (
        cod_venta, id_accesorio, cantidad, precio_pactado
    )
    VALUES (@cod_venta, 1, 1, @precio_accesorio);

    /* Escrituras 3 y 4: descuento de stock de la moto y del accesorio. */
    UPDATE dbo.modelo_motocicleta
    SET stock_disponible = stock_disponible - 1
    WHERE id_modelo = 11;

    UPDATE dbo.accesorio
    SET stock = stock - 1
    WHERE id_accesorio = 1;

    COMMIT TRANSACTION;     -- recien aca las 4 escrituras quedan confirmadas

    INSERT INTO #demo (cod_venta) VALUES (@cod_venta);

    PRINT 'COMMIT OK. cod_venta = ' + CAST(@cod_venta AS VARCHAR(20));
    PRINT 'Venta y detalle insertados; stock descontado.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    SELECT
        'DEMO 1 - ERROR' AS paso,
        ERROR_NUMBER()   AS error_number,
        ERROR_MESSAGE()  AS error_message,
        XACT_STATE()     AS xact_state,
        @@TRANCOUNT      AS trancount;
    THROW;
END CATCH;
GO

/* Verificacion del demo 1: debe haber +1 venta, +1 detalle, stock de moto y
   accesorio en -1, y ninguna transaccion abierta (trancount = 0). */
SELECT
    'DESPUES DEMO 1' AS momento,
    (SELECT COUNT(*) FROM dbo.venta) AS ventas,
    (SELECT COUNT(*) FROM dbo.detalle_venta_accesorio) AS detalles,
    (SELECT stock_disponible FROM dbo.modelo_motocicleta WHERE id_modelo = 11) AS stock_modelo_11,
    (SELECT stock FROM dbo.accesorio WHERE id_accesorio = 1) AS stock_accesorio_1,
    (SELECT COUNT(*) FROM dbo.venta WHERE numero_chasis = 'HONCB500F004') AS ventas_chasis_demo,
    XACT_STATE() AS xact_state,
    @@TRANCOUNT  AS trancount;

SELECT
    v.cod_venta, v.fecha, v.metodo_pago, v.precio_venta_moto, v.monto_total,
    v.estado, v.numero_chasis, d.id_accesorio, d.cantidad, d.precio_pactado
FROM dbo.venta AS v
LEFT JOIN dbo.detalle_venta_accesorio AS d ON d.cod_venta = v.cod_venta
WHERE v.cod_venta = (SELECT cod_venta FROM #demo);
GO

/* ============================================================================
   DEMO 2. STOCK INSUFICIENTE: BEGIN TRAN + ROLLBACK        (ATOMICIDAD)
   Se intenta vender una XR 150L (modelo 2), que tiene stock 0.
   A proposito, el control de stock se hace DESPUES de insertar venta y
   detalle: asi se ve que el ROLLBACK deshace escrituras que YA se habian
   hecho. Es el ejemplo de la guia: "si no hay stock, no se registra la venta,
   ni el detalle, ni se modifica el stock".
   Como explicarlo: "las filas existieron un instante dentro de la transaccion;
   el ROLLBACK las hizo desaparecer. Ningun otro usuario llego a verlas".
   ============================================================================ */
PRINT '';
PRINT '--- 2. STOCK INSUFICIENTE: BEGIN TRAN + ROLLBACK ---';
SET XACT_ABORT OFF;

/* Precondicion: el demo solo tiene sentido si el modelo 2 tiene stock 0.
   Si no, este THROW corta el lote ANTES de tocar nada. */
IF (SELECT stock_disponible FROM dbo.modelo_motocicleta WHERE id_modelo = 2) <> 0
    THROW 50099, 'El demo 2 requiere que el modelo 2 (XR 150L) tenga stock 0.', 1;

DECLARE @id_modelo_sin_stock INT = 2;
DECLARE @stock_sin_stock     INT;

BEGIN TRY
    BEGIN TRANSACTION;

    SELECT @@TRANCOUNT AS trancount_dentro_demo2;

    /* Unidad ficticia: permite intentar la venta sin chocar con el indice
       filtrado ni con las ventas del lote real. */
    INSERT INTO dbo.motocicleta (numero_chasis, numero_motor, id_modelo)
    VALUES ('TEST-XR150-ETAPA-V', 'TEST-MOT-XR150-ETAPA-V', @id_modelo_sin_stock);

    INSERT INTO dbo.venta (
        fecha, metodo_pago, precio_venta_moto, monto_total,
        estado, dni_cliente, dni_vendedor, numero_chasis
    )
    VALUES (
        CAST(GETDATE() AS DATE), 'efectivo', 4900000.00, 4998000.00,
        'efectuada', 30456781, 31222333, 'TEST-XR150-ETAPA-V'
    );

    DECLARE @cod_venta_demo2 INT = SCOPE_IDENTITY();

    INSERT INTO dbo.detalle_venta_accesorio (
        cod_venta, id_accesorio, cantidad, precio_pactado
    )
    VALUES (@cod_venta_demo2, 2, 1, 98000.00);

    /* Recien ahora se controla el stock: el modelo 2 tiene 0 unidades. */
    SELECT @stock_sin_stock = stock_disponible
    FROM dbo.modelo_motocicleta WITH (UPDLOCK, HOLDLOCK)
    WHERE id_modelo = @id_modelo_sin_stock;

    IF @stock_sin_stock IS NULL
        THROW 50017, 'Modelo sin stock inexistente.', 1;

    IF @stock_sin_stock <= 0
        THROW 50004, 'Sin stock disponible para el modelo 2 (XR 150L).', 1;

    /* Camino feliz (no se ejecuta en este demo): si hubiera stock se
       descontaria y se confirmaria. Se deja para mostrar la estructura
       completa de la transaccion. */
    UPDATE dbo.modelo_motocicleta
    SET stock_disponible = stock_disponible - 1
    WHERE id_modelo = @id_modelo_sin_stock;

    UPDATE dbo.accesorio
    SET stock = stock - 1
    WHERE id_accesorio = 2;          -- el mismo accesorio del detalle

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    /* Con XACT_ABORT OFF el THROW de negocio NO invalida la transaccion:
       XACT_STATE() = 1 (activa y confirmable). Somos nosotros quienes decidimos
       deshacer. Se capturan los valores ANTES del ROLLBACK para mostrarlos. */
    DECLARE @xact_state_demo2 INT = XACT_STATE();
    DECLARE @trancount_demo2  INT = @@TRANCOUNT;

    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;        -- deshace moto ficticia, venta y detalle

    SELECT
        'DEMO 2 - ERROR CONTROLADO'  AS paso,
        ERROR_NUMBER()               AS error_number,
        ERROR_MESSAGE()              AS error_message,
        @xact_state_demo2            AS xact_state_en_catch,
        @trancount_demo2             AS trancount_en_catch,
        XACT_STATE()                 AS xact_state_post_rollback,
        @@TRANCOUNT                  AS trancount_post_rollback;
END CATCH;
GO

/* Verificacion del demo 2: no debe quedar ninguna fila ni cambio de stock.
   Todas las columnas *_test deben valer 0. */
SELECT
    'DESPUES DEMO 2' AS momento,
    (SELECT COUNT(*) FROM dbo.venta) AS ventas,
    (SELECT COUNT(*) FROM dbo.detalle_venta_accesorio) AS detalles,
    (SELECT stock_disponible FROM dbo.modelo_motocicleta WHERE id_modelo = 2) AS stock_modelo_2,
    (SELECT stock FROM dbo.accesorio WHERE id_accesorio = 2) AS stock_accesorio_2,
    (SELECT COUNT(*) FROM dbo.venta WHERE numero_chasis = 'TEST-XR150-ETAPA-V') AS ventas_test,
    (SELECT COUNT(*) FROM dbo.detalle_venta_accesorio AS d
        INNER JOIN dbo.venta AS v ON v.cod_venta = d.cod_venta
        WHERE v.numero_chasis = 'TEST-XR150-ETAPA-V') AS detalles_test,
    (SELECT COUNT(*) FROM dbo.motocicleta WHERE numero_chasis = 'TEST-XR150-ETAPA-V') AS motos_test,
    XACT_STATE() AS xact_state,
    @@TRANCOUNT  AS trancount;
GO

/* ============================================================================
   DEMO 3. ERROR DE INTEGRIDAD: XACT_ABORT + ROLLBACK     (CONSISTENCIA)
   Se intenta insertar una venta con un cliente y un chasis que NO existen.
   La clave foranea (FK) rechaza el INSERT y la base queda consistente.

   Diferencia clave con el demo 2:
     - Demo 2: error DE NEGOCIO lanzado por nosotros con THROW, XACT_ABORT OFF
       -> XACT_STATE() = 1: la transaccion sigue viva y decidimos hacer ROLLBACK.
     - Demo 3: error DEL MOTOR (violacion de FK) con XACT_ABORT ON
       -> XACT_STATE() = -1: la transaccion queda "condenada"; lo UNICO
       permitido es ROLLBACK (no se puede hacer COMMIT).
   Nota: aca no se relanza el error (THROW) para que el script siga corriendo
   en cualquier cliente. En un procedimiento real se relanza con THROW; para
   verlo en accion, ver sp_RegistrarVentaCompleta y el demo 5.
   ============================================================================ */
PRINT '';
PRINT '--- 3. ERROR DE INTEGRIDAD: XACT_ABORT + ROLLBACK ---';
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    SELECT @@TRANCOUNT AS trancount_dentro_demo3;

    INSERT INTO dbo.venta (
        fecha, metodo_pago, precio_venta_moto, monto_total,
        estado, dni_cliente, dni_vendedor, numero_chasis
    )
    VALUES (
        CAST(GETDATE() AS DATE), 'efectivo', 8500000.00, 8500000.00,
        'efectuada', 99999999, 31222333, 'CHASIS-INVALIDO-ETAPA-V'   -- no existen
    );

    COMMIT TRANSACTION;      -- no se llega: el INSERT anterior falla
END TRY
BEGIN CATCH
    DECLARE @xact_state_demo3 INT = XACT_STATE();     -- se espera -1
    DECLARE @trancount_demo3  INT = @@TRANCOUNT;      -- se espera 1

    SELECT
        'DEMO 3 - ERROR DE INTEGRIDAD' AS paso,
        ERROR_NUMBER()                 AS error_number,      -- 547 = violacion de FK
        ERROR_MESSAGE()                AS error_message,
        ERROR_LINE()                   AS error_line,
        @xact_state_demo3              AS xact_state_en_catch,
        @trancount_demo3               AS trancount_en_catch;

    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    SELECT
        'DEMO 3 - DESPUES DEL ROLLBACK' AS paso,
        XACT_STATE()                    AS xact_state_post_rollback,   -- 0
        @@TRANCOUNT                     AS trancount_post_rollback;    -- 0
END CATCH;

SET XACT_ABORT OFF;
GO

/* Verificacion del demo 3: el rollback no debe dejar filas ni cambios. */
SELECT
    'DESPUES DEMO 3' AS momento,
    (SELECT COUNT(*) FROM dbo.venta) AS ventas,
    (SELECT COUNT(*) FROM dbo.detalle_venta_accesorio) AS detalles,
    (SELECT COUNT(*) FROM dbo.venta WHERE numero_chasis = 'CHASIS-INVALIDO-ETAPA-V') AS ventas_invalidas,
    XACT_STATE() AS xact_state,
    @@TRANCOUNT  AS trancount;
GO

/* ============================================================================
   4. CANCELACION DE LA VENTA COMMITEADA (restaura el stock)
   Otra transaccion: tres cambios que van juntos (estado de la venta, stock de
   la moto, stock del accesorio). La venta NO se borra: queda 'cancelada' para
   conservar la evidencia.
   Esta misma logica esta encapsulada en el procedimiento de cancelacion
   (02_sp_cambiar_estado_venta.sql); aca se hace inline para mostrar la
   transaccion paso a paso.
   ============================================================================ */
PRINT '';
PRINT '--- 4. CANCELACION DE LA VENTA COMMITEADA (RESTAURA STOCK) ---';
SET XACT_ABORT OFF;

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @cod_venta_cancelar INT = (SELECT cod_venta FROM #demo);

    IF @cod_venta_cancelar IS NULL
        THROW 50012, 'No hay venta demo para cancelar.', 1;

    /* Solo se cancela si estaba efectuada (evita cancelar dos veces y sumar
       stock dos veces). */
    UPDATE dbo.venta
    SET estado = 'cancelada'
    WHERE cod_venta = @cod_venta_cancelar
      AND estado = 'efectuada';

    IF @@ROWCOUNT <> 1
        THROW 50013, 'La venta demo no estaba efectuada.', 1;

    /* Devuelve 1 unidad al stock del modelo de la moto vendida. */
    UPDATE mm
    SET mm.stock_disponible = mm.stock_disponible + 1
    FROM dbo.modelo_motocicleta AS mm
    INNER JOIN dbo.motocicleta AS m ON m.id_modelo = mm.id_modelo
    INNER JOIN dbo.venta AS v       ON v.numero_chasis = m.numero_chasis
    WHERE v.cod_venta = @cod_venta_cancelar;

    /* Devuelve al stock los accesorios del detalle. */
    UPDATE a
    SET a.stock = a.stock + d.cantidad
    FROM dbo.accesorio AS a
    INNER JOIN dbo.detalle_venta_accesorio AS d ON d.id_accesorio = a.id_accesorio
    WHERE d.cod_venta = @cod_venta_cancelar;

    COMMIT TRANSACTION;

    PRINT 'Cancelacion OK. Venta ' + CAST(@cod_venta_cancelar AS VARCHAR(20))
          + ' quedo en estado cancelada.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    SELECT
        'CANCELACION - ERROR' AS paso,
        ERROR_NUMBER()        AS error_number,
        ERROR_MESSAGE()       AS error_message,
        XACT_STATE()          AS xact_state,
        @@TRANCOUNT           AS trancount;
    THROW;
END CATCH;
GO

/* ============================================================================
   5. INTEGRACION CON EL TEMA 1: sp_RegistrarVentaCompleta + ROLLBACK
   Se pide un accesorio en cantidad mayor al stock (stock + 1). El procedimiento
   inserta la venta y el detalle y recien al descontar el stock detecta que no
   alcanza: lanza el error 50008 y su CATCH hace ROLLBACK.
   Como explicarlo: "es lo mismo que el demo 2, pero ya empaquetado en un
   procedimiento: el usuario hace UNA llamada y la atomicidad la garantiza el
   procedimiento por dentro".
   Se ejecuta despues de la cancelacion (seccion 4) porque el chasis demo ya no
   tiene una venta 'efectuada'.
   ============================================================================ */
PRINT '';
PRINT '--- 5. sp_RegistrarVentaCompleta CON ACCESORIO SIN STOCK SUFICIENTE ---';
SET XACT_ABORT OFF;

IF OBJECT_ID('dbo.sp_RegistrarVentaCompleta', 'P') IS NULL
    THROW 50098, 'Falta crear sp_RegistrarVentaCompleta (ejecutar 02_procedimientos.sql).', 1;

DECLARE @cod_venta_sp INT;
DECLARE @stock_acc_1  INT = (SELECT stock FROM dbo.accesorio WHERE id_accesorio = 1);
DECLARE @json_pedido  NVARCHAR(MAX) =
    CONCAT(N'[{"id_accesorio":1,"cantidad":', @stock_acc_1 + 1, N'}]');   -- stock + 1

BEGIN TRY
    EXEC dbo.sp_RegistrarVentaCompleta
        @dni_cliente     = 30456781,
        @dni_vendedor    = 31222333,
        @numero_chasis   = 'HONCB500F004',
        @metodo_pago     = 'efectivo',
        @accesorios_json = @json_pedido,
        @cod_venta       = @cod_venta_sp OUTPUT;

    PRINT 'ATENCION: el procedimiento NO deberia haber confirmado esta venta.';
END TRY
BEGIN CATCH
    SELECT
        'DEMO 5 - ERROR ESPERADO (50008)' AS paso,
        ERROR_NUMBER()                    AS error_number,
        ERROR_MESSAGE()                   AS error_message,
        @@TRANCOUNT                       AS trancount_en_catch;   -- 0: el SP ya hizo ROLLBACK
END CATCH;
GO

/* ============================================================================
   VERIFICACION FINAL
   Compara contra el baseline. Resultado esperado:
     - ventas final = baseline + 1 (la venta demo, en estado 'cancelada')
     - stocks iguales al baseline
     - todas las columnas de la ultima tabla en 'OK'
   ============================================================================ */
SELECT
    'FINAL' AS momento,
    (SELECT COUNT(*) FROM dbo.venta) AS ventas,
    (SELECT COUNT(*) FROM dbo.detalle_venta_accesorio) AS detalles,
    (SELECT stock_disponible FROM dbo.modelo_motocicleta WHERE id_modelo = 11) AS stock_modelo_11,
    (SELECT stock_disponible FROM dbo.modelo_motocicleta WHERE id_modelo = 2) AS stock_modelo_2,
    (SELECT stock FROM dbo.accesorio WHERE id_accesorio = 1) AS stock_accesorio_1,
    (SELECT stock FROM dbo.accesorio WHERE id_accesorio = 2) AS stock_accesorio_2,
    XACT_STATE() AS xact_state,
    @@TRANCOUNT  AS trancount;

/* La unica venta que queda: la del demo 1, cancelada. */
SELECT
    v.cod_venta, v.fecha, v.metodo_pago, v.precio_venta_moto, v.monto_total,
    v.estado, v.numero_chasis
FROM dbo.venta AS v
WHERE v.cod_venta = (SELECT cod_venta FROM #demo);

/* Baseline vs final, lado a lado. */
SELECT
    b.ventas            AS ventas_baseline,
    (SELECT COUNT(*) FROM dbo.venta) AS ventas_final,
    b.detalles          AS detalles_baseline,
    (SELECT COUNT(*) FROM dbo.detalle_venta_accesorio) AS detalles_final,
    b.stock_modelo_11   AS stock_modelo_11_baseline,
    (SELECT stock_disponible FROM dbo.modelo_motocicleta WHERE id_modelo = 11) AS stock_modelo_11_final,
    b.stock_modelo_2    AS stock_modelo_2_baseline,
    (SELECT stock_disponible FROM dbo.modelo_motocicleta WHERE id_modelo = 2) AS stock_modelo_2_final,
    b.stock_accesorio_1 AS stock_accesorio_1_baseline,
    (SELECT stock FROM dbo.accesorio WHERE id_accesorio = 1) AS stock_accesorio_1_final,
    b.stock_accesorio_2 AS stock_accesorio_2_baseline,
    (SELECT stock FROM dbo.accesorio WHERE id_accesorio = 2) AS stock_accesorio_2_final
FROM #baseline AS b;

/* Auto-chequeo: una columna por cada garantia demostrada. */
SELECT
    CASE WHEN (SELECT COUNT(*) FROM dbo.venta
               WHERE numero_chasis = 'HONCB500F004' AND estado = 'cancelada') = 1
         THEN 'OK' ELSE 'FALLA' END AS demo1_venta_cancelada,
    CASE WHEN (SELECT COUNT(*) FROM dbo.venta) = (SELECT ventas FROM #baseline) + 1
         THEN 'OK' ELSE 'FALLA' END AS ventas_baseline_mas_1,
    CASE WHEN (SELECT stock_disponible FROM dbo.modelo_motocicleta WHERE id_modelo = 11)
              = (SELECT stock_modelo_11 FROM #baseline)
         THEN 'OK' ELSE 'FALLA' END AS stock_modelo_11_restaurado,
    CASE WHEN (SELECT stock_disponible FROM dbo.modelo_motocicleta WHERE id_modelo = 2)
              = (SELECT stock_modelo_2 FROM #baseline)
         THEN 'OK' ELSE 'FALLA' END AS stock_modelo_2_intacto,
    CASE WHEN (SELECT stock FROM dbo.accesorio WHERE id_accesorio = 1)
              = (SELECT stock_accesorio_1 FROM #baseline)
         THEN 'OK' ELSE 'FALLA' END AS stock_accesorio_1_restaurado,
    CASE WHEN (SELECT stock FROM dbo.accesorio WHERE id_accesorio = 2)
              = (SELECT stock_accesorio_2 FROM #baseline)
         THEN 'OK' ELSE 'FALLA' END AS stock_accesorio_2_intacto,
    CASE WHEN (SELECT COUNT(*) FROM dbo.venta WHERE numero_chasis = 'TEST-XR150-ETAPA-V') = 0
          AND (SELECT COUNT(*) FROM dbo.motocicleta WHERE numero_chasis = 'TEST-XR150-ETAPA-V') = 0
         THEN 'OK' ELSE 'FALLA' END AS demo2_rollback_total,
    CASE WHEN (SELECT COUNT(*) FROM dbo.detalle_venta_accesorio AS d
               INNER JOIN dbo.venta AS v ON v.cod_venta = d.cod_venta
               WHERE v.numero_chasis = 'TEST-XR150-ETAPA-V') = 0
         THEN 'OK' ELSE 'FALLA' END AS demo2_sin_detalle,
    CASE WHEN (SELECT COUNT(*) FROM dbo.venta WHERE numero_chasis = 'CHASIS-INVALIDO-ETAPA-V') = 0
         THEN 'OK' ELSE 'FALLA' END AS demo3_sin_venta_invalida,
    CASE WHEN (SELECT COUNT(*) FROM dbo.venta
               WHERE numero_chasis = 'HONCB500F004' AND estado = 'efectuada') = 0
         THEN 'OK' ELSE 'FALLA' END AS demo5_sin_venta_nueva;

IF OBJECT_ID('tempdb..#baseline') IS NOT NULL
    DROP TABLE #baseline;

IF OBJECT_ID('tempdb..#demo') IS NOT NULL
    DROP TABLE #demo;
GO