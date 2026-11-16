-- ============================================================================
-- DEMO 3: TRIGGERS Y AUDITORIA (X Motors)
-- COMO EJECUTAR EN DBEAVER: Ctrl+A (seleccionar todo) y Ctrl+Enter.
-- NO usar Alt+X: corta el script en pedazos y las variables se pierden.
-- Todo va dentro de BEGIN TRAN + ROLLBACK: la base queda EXACTAMENTE como
-- estaba y se puede repetir las veces que quieras.
-- Requiere: DDL + DML + procedimientos + los 4 scripts de
--           docs/etapa-05/03-triggers-auditoria/ ya ejecutados.
--
-- QUE ES (leer en voz alta):
--   Un trigger es un bloque de codigo que se dispara SOLO cuando ocurre un
--   INSERT, UPDATE o DELETE sobre una tabla. Dentro del trigger, la tabla
--   logica "inserted" trae las filas nuevas y "deleted" las viejas.
--
-- QUE PROBLEMA RESUELVE EN X MOTORS (leer en voz alta):
--   Responde la pregunta "quien cambio este precio / estado, cuando y con que
--   valores", sin que nadie tenga que acordarse de escribir el registro:
--   la base de datos lo hace sola.
--
-- RESULTADOS (pestañas, en orden):
--   1 ANTES | 2 trigger de precio (conteos + ultima fila) | 3 trigger de venta
--   4 trigger de cliente | 5 DESPUES del ROLLBACK (todo igual que al inicio)
-- ============================================================================

USE [X MOTORS];

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @precio_ant        DECIMAL(18,2);
DECLARE @precio_nuevo      DECIMAL(18,2);
DECLARE @hist_antes        INT;
DECLARE @hist_tras_cambio  INT;
DECLARE @hist_tras_repetir INT;
DECLARE @v                 INT;

-- ============================================================================
-- 1. ANTES: que hay registrado hoy
-- ============================================================================
SELECT @precio_ant = precio_lista FROM dbo.modelo_motocicleta WHERE id_modelo = 1;
SELECT @hist_antes = COUNT(*)     FROM dbo.historial_de_precio WHERE id_modelo = 1;

SELECT '1. ANTES' AS paso,
       @precio_ant AS precio_lista_modelo_1,
       @hist_antes AS filas_historial_precio;

BEGIN TRY
    BEGIN TRANSACTION;

    -- ========================================================================
    -- 2. TRIGGER trg_historial_precio_modelo
    -- NO llamo a nada de auditoria: el trigger se dispara SOLO cuando el
    -- UPDATE toca precio_lista. Subo el precio actual +100000.
    -- ========================================================================
    SET @precio_nuevo = @precio_ant + 100000;

    EXEC dbo.sp_actualizar_precio_modelo @id_modelo = 1, @nuevo_precio = @precio_nuevo;
    SELECT @hist_tras_cambio = COUNT(*) FROM dbo.historial_de_precio WHERE id_modelo = 1;

    -- Comprobacion de que el trigger es listo: mismo precio = no registra nada
    EXEC dbo.sp_actualizar_precio_modelo @id_modelo = 1, @nuevo_precio = @precio_nuevo;
    SELECT @hist_tras_repetir = COUNT(*) FROM dbo.historial_de_precio WHERE id_modelo = 1;

    SELECT '2. TRIGGER PRECIO' AS paso,
           @hist_antes        AS filas_antes,
           @hist_tras_cambio  AS filas_tras_cambiar_precio,
           @hist_tras_repetir AS filas_tras_repetir_mismo_precio;

    SELECT TOP (1) precio_anterior, precio_nuevo, fecha_modificacion
    FROM dbo.historial_de_precio
    WHERE id_modelo = 1
    ORDER BY id_historial DESC;

    -- ========================================================================
    -- 3. TRIGGER trg_auditoria_venta: un UPDATE y un DELETE sobre venta.
    -- Registra las dos acciones en auditoria_venta.
    -- ========================================================================
    SET @v = (SELECT MIN(cod_venta) FROM dbo.venta WHERE estado = 'efectuada');

    IF @v IS NULL
        PRINT 'No hay ventas en estado efectuada: se omite el bloque 3.';
    ELSE
    BEGIN
        UPDATE dbo.venta SET estado = 'cancelada' WHERE cod_venta = @v;   -- UPDATE auditado
        DELETE FROM dbo.detalle_venta_accesorio WHERE cod_venta = @v;     -- detalle primero (FK)
        DELETE FROM dbo.venta WHERE cod_venta = @v;                       -- DELETE auditado

        SELECT '3. TRIGGER VENTA' AS paso,
               id_auditoria, cod_venta, accion, estado_anterior, estado_nuevo, usuario, fecha_hora
        FROM dbo.auditoria_venta
        WHERE cod_venta = @v
        ORDER BY id_auditoria DESC;
    END;

    -- ========================================================================
    -- 4. TRIGGER trg_auditoria_cliente_estado: cambio de estado de un cliente.
    -- Elijo un estado distinto al actual para que el trigger siempre registre.
    -- ========================================================================
    UPDATE dbo.cliente
    SET estado = CASE WHEN estado = 'interesado' THEN 'en proceso de compra'
                      ELSE 'interesado' END
    WHERE dni_cliente = 30456781;

    SELECT TOP (1) '4. TRIGGER CLIENTE' AS paso,
           dni_cliente, estado_anterior, estado_nuevo, usuario, fecha_hora
    FROM dbo.auditoria_cliente
    WHERE dni_cliente = 30456781
    ORDER BY id_auditoria DESC;

    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;

-- ============================================================================
-- 5. DESPUES (post-ROLLBACK): la base quedo EXACTAMENTE igual que al inicio:
-- mismo precio, mismas filas de historial y ninguna transaccion abierta.
-- ============================================================================
SELECT '5. DESPUES DEL ROLLBACK' AS paso,
       (SELECT precio_lista FROM dbo.modelo_motocicleta WHERE id_modelo = 1) AS precio_final,
       @precio_ant AS precio_inicial,
       (SELECT COUNT(*) FROM dbo.historial_de_precio WHERE id_modelo = 1) AS filas_historial_final,
       @hist_antes AS filas_historial_inicial,
       @@TRANCOUNT AS transacciones_abiertas;