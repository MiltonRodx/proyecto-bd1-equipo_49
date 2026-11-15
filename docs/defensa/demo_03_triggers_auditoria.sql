-- ============================================================================
-- DEMO 3: TRIGGERS Y AUDITORIA (Etapa V - Tema 3)
-- Archivo: docs/defensa/demo_03_triggers_auditoria.sql
-- Ejecutar COMPLETO (F5). Todo va dentro de BEGIN TRAN + ROLLBACK: deja la
-- base EXACTAMENTE como estaba y se puede repetir las veces que quieras.
-- Requiere: DDL + DML + los 4 scripts de docs/etapa-05/03-triggers-auditoria/
--           (01_tablas, 02/03/04 triggers). Si no existen, ejecutarlos primero.
--
-- QUÉ ES (para leer en voz alta):
--   Un trigger es un bloque de codigo que se dispara SOLO cuando ocurre un
--   INSERT, UPDATE o DELETE sobre una tabla. Dentro del trigger, la tabla
--   lógica "inserted" trae las filas nuevas y "deleted" las viejas.
--
-- QUÉ PROBLEMA RESUELVE EN X MOTORS:
--   Responde la pregunta "quien cambió este precio / estado / monto, cuando
--   y con qué valores", sin que nadie tenga que acordarse de escribir el
--   registro: la base de datos lo hace sola.
-- ============================================================================

USE [X MOTORS];
GO

SET NOCOUNT ON;

BEGIN TRANSACTION;

-- ============================================================================
-- BLOQUE ANTES: que hay registrado hoy
-- ============================================================================
SELECT COUNT(*) AS historial_precio_modelo_1 FROM dbo.historial_de_precio WHERE id_modelo = 1;
SELECT precio_lista AS precio_antes FROM dbo.modelo_motocicleta WHERE id_modelo = 1;

-- ============================================================================
-- BLOQUE EJECUCION 1: cambiar el precio de lista de un modelo.
-- NO llamo a nada de auditoria: el trigger trg_historial_precio_modelo se
-- dispara SOLO cuando el UPDATE toca precio_lista.
-- ============================================================================
EXEC dbo.sp_actualizar_precio_modelo @id_modelo = 1, @nuevo_precio = 3900000.00;

-- (Comprobacion de que el trigger es listo: si el valor no cambia, no registra)
EXEC dbo.sp_actualizar_precio_modelo @id_modelo = 1, @nuevo_precio = 3900000.00;

SELECT precio_nuevo, precio_anterior, fecha_modificacion
FROM dbo.historial_de_precio
WHERE id_modelo = 1
ORDER BY id_historial DESC;

-- ============================================================================
-- BLOQUE EJECUCION 2: un UPDATE y un DELETE sobre venta.
-- El trigger trg_auditoria_venta registra las dos acciones en auditoria_venta
-- (una fila INSERT cuando la venta nace... en este caso ya existe: aqui va a
--  registrar un UPDATE de estado y un DELETE).
-- ============================================================================
DECLARE @v INT = (SELECT MIN(cod_venta) FROM dbo.venta WHERE estado = 'efectuada');

UPDATE dbo.venta SET estado = 'cancelada' WHERE cod_venta = @v;   -- UPDATE auditado
DELETE FROM dbo.detalle_venta_accesorio WHERE cod_venta = @v;     -- detalle primero (FK)
DELETE FROM dbo.venta WHERE cod_venta = @v;                       -- DELETE auditado

SELECT TOP (3) id_auditoria, cod_venta, accion, estado_anterior, estado_nuevo, usuario, fecha_hora
FROM dbo.auditoria_venta
ORDER BY id_auditoria DESC;

-- ============================================================================
-- BLOQUE EJECUCION 3: cambio de estado de un cliente.
-- trg_auditoria_cliente_estado registra en auditoria_cliente.
-- ============================================================================
UPDATE dbo.cliente SET estado = 'en proceso de compra' WHERE dni_cliente = 30456781;

SELECT TOP (2) dni_cliente, estado_anterior, estado_nuevo, usuario, fecha_hora
FROM dbo.auditoria_cliente
ORDER BY id_auditoria DESC;

ROLLBACK TRANSACTION;

-- ============================================================================
-- BLOQUE DESPUES (post-ROLLBACK): la base quedo EXACTAMENTE igual que al
-- principio: ni el precio, ni la venta, ni el estado del cliente cambiaron.
-- ============================================================================
SELECT COUNT(*) AS historial_precio_modelo_1_final FROM dbo.historial_de_precio WHERE id_modelo = 1;
SELECT precio_lista AS precio_final FROM dbo.modelo_motocicleta WHERE id_modelo = 1;
GO

PRINT 'DEMO 3 terminado: todo se revirtio. Se puede volver a ejecutar.';
GO
