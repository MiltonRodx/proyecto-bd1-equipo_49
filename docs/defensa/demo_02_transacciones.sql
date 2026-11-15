-- ============================================================================
-- DEMO 2: TRANSACCIONES (Etapa V - Tema 2)
-- Archivo: docs/defensa/demo_02_transacciones.sql
-- Ejecutar COMPLETO (F5). Es re-ejecutable: al final limpia lo que creo.
-- Requiere: DDL + DML + docs/etapa-05/01-procedimientos-funciones/02_procedimientos.sql
--           y docs/etapa-05/02-transacciones/02_sp_cambiar_estado_venta.sql.
--
-- QUÉ ES (para leer en voz alta):
--   Una transaccion es un grupo de operaciones que se ejecutan como UNA sola
--   unidad: se confirman todas (COMMIT) o no se confirma ninguna (ROLLBACK).
--
-- QUÉ PROBLEMA RESUELVE EN X MOTORS:
--   Una venta toca venta, detalle y el stock de la moto y de los accesorios.
--   Si a mitad de camino algo falla (ej: no hay stock de un accesorio), la
--   ROLLBACK deshace TODO: no queda venta registrada con stock mal descontado.
--   Y la cancelacion tambien es atomica: el stock se devuelve UNA sola vez,
--   aunque dos personas cancelen la misma venta a la vez.
-- ============================================================================

USE [X MOTORS];
GO

SET NOCOUNT ON;

DECLARE @cod INT;
DECLARE @json NVARCHAR(MAX);

-- "Foto" del estado de la base en cada momento (se muestra al final)
DECLARE @foto TABLE (
    momento         VARCHAR(40),
    stock_motos     INT,   -- suma del stock de todos los modelos
    stock_accesorio INT,   -- stock del accesorio 1 (casco)
    ventas          INT,
    detalles        INT
);

INSERT @foto (momento, stock_motos, stock_accesorio, ventas, detalles)
SELECT '0. ANTES',
       (SELECT SUM(stock_disponible) FROM dbo.modelo_motocicleta),
       (SELECT stock FROM dbo.accesorio WHERE id_accesorio = 1),
       (SELECT COUNT(*) FROM dbo.venta),
       (SELECT COUNT(*) FROM dbo.detalle_venta_accesorio);

-- ============================================================================
-- BLOQUE EJECUCION 1 (CASO DE ERROR): accesorio sin stock -> error 50008.
-- El SP ya inserto la venta cuando descubre que no alcanza el stock: el
-- ROLLBACK del CATCH tiene que deshacer TODO (venta, detalle y stock).
-- ============================================================================
SET @json = N'[{"id_accesorio":1,"cantidad":9999}]';
BEGIN TRY
    EXEC dbo.sp_RegistrarVentaCompleta
         @dni_cliente = 42111222, @dni_vendedor = 31222333,
         @numero_chasis = '9C2HON00000000002', @metodo_pago = 'efectivo',
         @accesorios_json = @json, @cod_venta = @cod OUTPUT;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER()  AS error_esperado_50008,
           ERROR_MESSAGE() AS mensaje,
           @@TRANCOUNT     AS transacciones_abiertas;
END CATCH;

INSERT @foto (momento, stock_motos, stock_accesorio, ventas, detalles)
SELECT '1. VENTA FALLIDA (ROLLBACK)',
       (SELECT SUM(stock_disponible) FROM dbo.modelo_motocicleta),
       (SELECT stock FROM dbo.accesorio WHERE id_accesorio = 1),
       (SELECT COUNT(*) FROM dbo.venta),
       (SELECT COUNT(*) FROM dbo.detalle_venta_accesorio);

-- ============================================================================
-- BLOQUE EJECUCION 2 (CASO FELIZ): venta correcta -> COMMIT.
-- ============================================================================
SET @json = N'[{"id_accesorio":1,"cantidad":1}]';
EXEC dbo.sp_RegistrarVentaCompleta
     @dni_cliente = 42111222, @dni_vendedor = 31222333,
     @numero_chasis = '9C2HON00000000002', @metodo_pago = 'efectivo',
     @accesorios_json = @json, @cod_venta = @cod OUTPUT;

SELECT @cod AS cod_venta_creada;

INSERT @foto (momento, stock_motos, stock_accesorio, ventas, detalles)
SELECT '2. VENTA CONFIRMADA (COMMIT)',
       (SELECT SUM(stock_disponible) FROM dbo.modelo_motocicleta),
       (SELECT stock FROM dbo.accesorio WHERE id_accesorio = 1),
       (SELECT COUNT(*) FROM dbo.venta),
       (SELECT COUNT(*) FROM dbo.detalle_venta_accesorio);

-- ============================================================================
-- BLOQUE EJECUCION 3: CANCELACION de la venta recien hecha.
-- Un solo procedimiento cambia el estado y devuelve el stock de la moto y de
-- los accesorios: los tres cambios viajan juntos en una transaccion.
-- ============================================================================
EXEC dbo.sp_cambiar_estado_venta @cod_venta = @cod, @nuevo_estado = 'cancelada';

INSERT @foto (momento, stock_motos, stock_accesorio, ventas, detalles)
SELECT '3. CANCELADA (stock devuelto)',
       (SELECT SUM(stock_disponible) FROM dbo.modelo_motocicleta),
       (SELECT stock FROM dbo.accesorio WHERE id_accesorio = 1),
       (SELECT COUNT(*) FROM dbo.venta),
       (SELECT COUNT(*) FROM dbo.detalle_venta_accesorio);

-- ============================================================================
-- BLOQUE EJECUCION 4 (CASO DE ERROR): cancelar DOS VECES -> error 50013.
-- El stock NO se devuelve dos veces: el segundo EXEC ya no encuentra la venta
-- en estado 'efectuada' y no toca nada.
-- ============================================================================
BEGIN TRY
    EXEC dbo.sp_cambiar_estado_venta @cod_venta = @cod, @nuevo_estado = 'cancelada';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER()  AS error_esperado_50013,
           ERROR_MESSAGE() AS mensaje,
           @@TRANCOUNT     AS transacciones_abiertas;
END CATCH;

INSERT @foto (momento, stock_motos, stock_accesorio, ventas, detalles)
SELECT '4. SEGUNDA CANCELACION RECHAZADA',
       (SELECT SUM(stock_disponible) FROM dbo.modelo_motocicleta),
       (SELECT stock FROM dbo.accesorio WHERE id_accesorio = 1),
       (SELECT COUNT(*) FROM dbo.venta),
       (SELECT COUNT(*) FROM dbo.detalle_venta_accesorio);

-- ============================================================================
-- BLOQUE DESPUES: la foto completa (para leer de corrido en la defensa)
-- ============================================================================
SELECT momento, stock_motos, stock_accesorio, ventas, detalles
FROM @foto
ORDER BY momento;

-- ============================================================================
-- BLOQUE LIMPIEZA: borra la venta demo y devuelve el estado del cliente.
-- El stock ya quedo como al principio gracias a la cancelacion (paso 3).
-- (Si hay triggers de auditoria instalados, quedan filas en auditoria_venta.)
-- ============================================================================
IF @cod IS NOT NULL
BEGIN
    DELETE FROM dbo.detalle_venta_accesorio WHERE cod_venta = @cod;
    DELETE FROM dbo.venta                   WHERE cod_venta = @cod;
    UPDATE dbo.cliente SET estado = 'interesado' WHERE dni_cliente = 42111222;

    SELECT (SELECT SUM(stock_disponible) FROM dbo.modelo_motocicleta) AS stock_motos_final,
           (SELECT stock FROM dbo.accesorio WHERE id_accesorio = 1)   AS stock_accesorio_final;
END;
ELSE
    PRINT 'No se creo venta demo: nada que limpiar.';
GO

PRINT 'DEMO 2 terminado y limpio. Se puede volver a ejecutar.';
GO
