-- ============================================================================
-- DEMO 1: PROCEDIMIENTOS Y FUNCIONES (Etapa V - Tema 1)
-- Archivo: docs/defensa/demo_01_procedimientos_funciones.sql
-- Ejecutar COMPLETO (F5). Es re-ejecutable: al final limpia todo lo que creo.
-- Requiere: DDL + DML + docs/etapa-05/01-procedimientos-funciones/01_funciones.sql
--           y 02_procedimientos.sql ejecutados.
--
-- QUÉ ES (para leer en voz alta):
--   Un procedimiento almacenado es un programa guardado en el motor que agrupa
--   varias operaciones; una funcion recibe parametros y devuelve un valor.
--
-- QUÉ PROBLEMA RESUELVE EN X MOTORS:
--   Registrar una venta toca 5 tablas y aplica reglas (descuento, stock, total).
--   Sin procedimientos, cada vendedor/escriptorio podria ejecutar los pasos
--   a mano y dejar datos a medias. fn_descuento_cliente y fn_precio_con_descuento
--   calculan el descuento (mas de $5M acumulado -> 5%, mas de $10M -> 10%,
--   solo ventas 'efectuada') y sp_RegistrarVentaCompleta aplica todo en una llamada.
-- ============================================================================

USE [X MOTORS];
GO

SET NOCOUNT ON;

-- ============================================================================
-- BLOQUE ANTES: estado inicial (cliente sin compras, stock del modelo)
-- ============================================================================
SELECT dbo.fn_descuento_cliente(42111222)      AS descuento_cliente_nuevo,
       dbo.fn_precio_con_descuento(3850000.00, 5) AS precio_con_5_porciento,
       dbo.fn_stock_disponible_modelo(1)       AS stock_modelo_1;

-- ============================================================================
-- BLOQUE EJECUCION 1 (CASO DE ERROR): metodo de pago invalido -> error 50011.
-- El SP valida la entrada ANTES de tocar datos: no queda nada a medias.
-- ============================================================================
BEGIN TRY
    DECLARE @cod INT;
    EXEC dbo.sp_RegistrarVentaCompleta
         @dni_cliente = 42111222, @dni_vendedor = 31222333,
         @numero_chasis = '9C2HON00000000002', @metodo_pago = 'bitcoin',
         @accesorios_json = N'[{"id_accesorio":1,"cantidad":1}]',
         @cod_venta = @cod OUTPUT;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS error_esperado_50011, ERROR_MESSAGE() AS mensaje;
END CATCH;

-- ============================================================================
-- BLOQUE EJECUCION 2 (CASO FELIZ): una sola llamada registra toda la venta.
-- ============================================================================
EXEC dbo.sp_RegistrarVentaCompleta
     @dni_cliente = 42111222, @dni_vendedor = 31222333,
     @numero_chasis = '9C2HON00000000002', @metodo_pago = 'efectivo',
     @accesorios_json = N'[{"id_accesorio":1,"cantidad":1}]',
     @cod_venta = @cod OUTPUT;

SELECT @cod AS cod_venta_creada;

-- ============================================================================
-- BLOQUE DESPUES: la venta, su detalle y los efectos (stock, estado cliente)
-- ============================================================================
SELECT cod_venta, estado, precio_venta_moto, monto_total, numero_chasis
FROM dbo.venta WHERE cod_venta = @cod;

SELECT cod_venta, id_accesorio, cantidad, precio_pactado
FROM dbo.detalle_venta_accesorio WHERE cod_venta = @cod;

SELECT dbo.fn_stock_disponible_modelo(1) AS stock_modelo_despues,
       (SELECT estado FROM dbo.cliente WHERE dni_cliente = 42111222) AS estado_cliente_despues;

-- ============================================================================
-- BLOQUE LIMPIEZA: borra la venta demo y devuelve el stock/estado.
-- (Si los triggers de auditoria del tema 3 estan instalados, quedan filas en
--  auditoria_venta: es la convencion del proyecto, la auditoria no se borra.)
-- ============================================================================
IF @cod IS NOT NULL
BEGIN
    DELETE FROM dbo.detalle_venta_accesorio WHERE cod_venta = @cod;
    DELETE FROM dbo.venta                   WHERE cod_venta = @cod;
    UPDATE dbo.cliente SET estado = 'interesado' WHERE dni_cliente = 42111222;
    UPDATE dbo.modelo_motocicleta SET stock_disponible = stock_disponible + 1 WHERE id_modelo = 1;
    UPDATE dbo.accesorio SET stock = stock + 1 WHERE id_accesorio = 1;

    SELECT dbo.fn_stock_disponible_modelo(1) AS stock_final,
           (SELECT estado FROM dbo.cliente WHERE dni_cliente = 42111222) AS estado_cliente_final;
END;
ELSE
    PRINT 'No se creo venta demo: nada que limpiar.';
GO

PRINT 'DEMO 1 terminado y limpio. Se puede volver a ejecutar.';
GO
