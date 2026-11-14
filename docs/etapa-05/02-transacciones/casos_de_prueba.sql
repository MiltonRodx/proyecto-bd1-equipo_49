-- ============================================================================
-- ETAPA V - TEMA 2: TRANSACCIONES - SCRIPT DE DEMOSTRACION
-- Archivo: docs/etapa-05/02-transacciones/03_demo_transacciones.sql
-- Sistema: X Motors - Base de Datos I - Grupo 49 - FaCENA (UNNE)
--
-- Demuestra la ATOMICIDAD (todo o nada) con sp_RegistrarVentaCompleta y
-- sp_cambiar_estado_venta. Los datos de prueba (cliente, vendedor, moto y
-- accesorio) se eligen solos de la base: no hay que editar nada.
--
--   PRUEBA 1  Venta INCORRECTA (accesorio sin stock) -> ROLLBACK: no queda nada
--   PRUEBA 2  Venta CORRECTA (stock suficiente)      -> COMMIT: todo se guarda
--   PRUEBA 3  Cancelacion de esa venta               -> se reintegra el stock
--   PRUEBA 4  Cancelar de nuevo                      -> error 50013: no se
--                                                       reintegra dos veces
--
-- Requiere: DDL, DML, 01_funciones.sql, 02_procedimientos.sql y
--           02_sp_cambiar_estado_venta.sql ejecutados.
-- Ejecutar el script COMPLETO de una vez (F5). Al final se muestra una tabla
-- con la "foto" de la base en cada momento.
-- OJO: modifica datos reales (stock) y los deja como estaban, salvo que se
-- conserva la venta como 'cancelada' y el cliente queda como 'comprador'.
-- ============================================================================
USE [X MOTORS];
GO

SET NOCOUNT ON;

-- ---------------------------------------------------------------------------
-- DATOS DE PRUEBA (se eligen solos)
-- ---------------------------------------------------------------------------
DECLARE @dni_cliente  INT, @dni_vendedor INT;
DECLARE @id_acc       INT, @stock_acc    INT;
DECLARE @chasis       VARCHAR(100);
DECLARE @cod          INT;
DECLARE @cod_descarte INT;
DECLARE @json         NVARCHAR(MAX);

SELECT TOP 1 @dni_cliente  = dni_cliente  FROM dbo.cliente  ORDER BY dni_cliente;
SELECT TOP 1 @dni_vendedor = dni_vendedor FROM dbo.vendedor ORDER BY dni_vendedor;

SELECT TOP 1 @id_acc = id_accesorio, @stock_acc = stock
FROM dbo.accesorio
WHERE stock >= 1
ORDER BY id_accesorio;

-- Una moto cuyo modelo tenga stock y que no este ya vendida.
SELECT TOP 1 @chasis = mo.numero_chasis
FROM dbo.motocicleta        AS mo
JOIN dbo.modelo_motocicleta AS m ON m.id_modelo = mo.id_modelo
WHERE m.stock_disponible >= 1
  AND NOT EXISTS (SELECT 1 FROM dbo.venta AS v
                  WHERE v.numero_chasis = mo.numero_chasis AND v.estado = 'efectuada')
ORDER BY mo.numero_chasis;

IF @dni_cliente IS NULL OR @dni_vendedor IS NULL OR @id_acc IS NULL OR @chasis IS NULL
BEGIN
    PRINT 'Faltan datos de prueba: cliente, vendedor, accesorio con stock o moto disponible.';
    RETURN;
END

PRINT 'Cliente: ' + CAST(@dni_cliente AS VARCHAR(20))
    + ' | Vendedor: ' + CAST(@dni_vendedor AS VARCHAR(20))
    + ' | Chasis: ' + @chasis
    + ' | Accesorio: ' + CAST(@id_acc AS VARCHAR(10));

-- "Foto" del estado de la base en cada momento (se muestra al final).
DECLARE @foto TABLE (
    id              INT IDENTITY(1,1),
    momento         VARCHAR(45),
    stock_motos     INT,    -- suma del stock de todos los modelos
    stock_accesorio INT,    -- stock del accesorio de prueba
    ventas          INT,    -- filas en venta
    detalles        INT     -- filas en detalle_venta_accesorio
);

INSERT @foto (momento, stock_motos, stock_accesorio, ventas, detalles)
SELECT '0. ANTES', (SELECT SUM(stock_disponible) FROM dbo.modelo_motocicleta),
       (SELECT stock FROM dbo.accesorio WHERE id_accesorio = @id_acc),
       (SELECT COUNT(*) FROM dbo.venta), (SELECT COUNT(*) FROM dbo.detalle_venta_accesorio);

-- ---------------------------------------------------------------------------
-- PRUEBA 1: venta INCORRECTA. Se piden mas accesorios de los que hay.
-- El procedimiento ya inserto la venta y el detalle cuando descubre que no
-- alcanza el stock: el ROLLBACK tiene que deshacer TODO.
-- Esperado: error 50008, 0 transacciones abiertas y la foto sin cambios.
-- ---------------------------------------------------------------------------
PRINT '=== PRUEBA 1: accesorio SIN stock suficiente (debe fallar y deshacer todo) ===';

SET @json = N'[{"id_accesorio":' + CAST(@id_acc AS VARCHAR(10))
          + N',"cantidad":' + CAST(@stock_acc + 1000 AS VARCHAR(10)) + N'}]';

BEGIN TRY
    EXEC dbo.sp_RegistrarVentaCompleta
         @dni_cliente = @dni_cliente, @dni_vendedor = @dni_vendedor,
         @numero_chasis = @chasis, @metodo_pago = 'efectivo',
         @accesorios_json = @json, @cod_venta = @cod_descarte OUTPUT;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER()  AS numero_error,
           ERROR_MESSAGE() AS mensaje,
           @@TRANCOUNT     AS transacciones_abiertas;
END CATCH;

INSERT @foto (momento, stock_motos, stock_accesorio, ventas, detalles)
SELECT '1. DESPUES DE LA VENTA INCORRECTA', (SELECT SUM(stock_disponible) FROM dbo.modelo_motocicleta),
       (SELECT stock FROM dbo.accesorio WHERE id_accesorio = @id_acc),
       (SELECT COUNT(*) FROM dbo.venta), (SELECT COUNT(*) FROM dbo.detalle_venta_accesorio);

-- ---------------------------------------------------------------------------
-- PRUEBA 2: venta CORRECTA (1 unidad del accesorio).
-- Esperado: venta 'efectuada' con su detalle; el stock de la moto y del
-- accesorio baja en 1; ventas y detalles suben en 1.
-- ---------------------------------------------------------------------------
PRINT '=== PRUEBA 2: venta con stock suficiente (debe confirmarse completa) ===';

SET @json = N'[{"id_accesorio":' + CAST(@id_acc AS VARCHAR(10)) + N',"cantidad":1}]';

EXEC dbo.sp_RegistrarVentaCompleta
     @dni_cliente = @dni_cliente, @dni_vendedor = @dni_vendedor,
     @numero_chasis = @chasis, @metodo_pago = 'efectivo',
     @accesorios_json = @json, @cod_venta = @cod OUTPUT;

SELECT cod_venta, estado, precio_venta_moto, monto_total, numero_chasis
FROM dbo.venta WHERE cod_venta = @cod;

SELECT cod_venta, id_accesorio, cantidad, precio_pactado
FROM dbo.detalle_venta_accesorio WHERE cod_venta = @cod;

INSERT @foto (momento, stock_motos, stock_accesorio, ventas, detalles)
SELECT '2. DESPUES DE LA VENTA CORRECTA', (SELECT SUM(stock_disponible) FROM dbo.modelo_motocicleta),
       (SELECT stock FROM dbo.accesorio WHERE id_accesorio = @id_acc),
       (SELECT COUNT(*) FROM dbo.venta), (SELECT COUNT(*) FROM dbo.detalle_venta_accesorio);

-- ---------------------------------------------------------------------------
-- PRUEBA 3: cancelacion de la venta recien hecha.
-- Esperado: estado 'cancelada' y los stocks vuelven al valor inicial; la venta
-- queda registrada como historial (ventas y detalles no bajan).
-- ---------------------------------------------------------------------------
PRINT '=== PRUEBA 3: cancelar la venta (estado + stock de moto + stock de accesorios) ===';

EXEC dbo.sp_cambiar_estado_venta @cod_venta = @cod, @nuevo_estado = 'cancelada';

SELECT cod_venta, estado FROM dbo.venta WHERE cod_venta = @cod;

INSERT @foto (momento, stock_motos, stock_accesorio, ventas, detalles)
SELECT '3. DESPUES DE CANCELAR', (SELECT SUM(stock_disponible) FROM dbo.modelo_motocicleta),
       (SELECT stock FROM dbo.accesorio WHERE id_accesorio = @id_acc),
       (SELECT COUNT(*) FROM dbo.venta), (SELECT COUNT(*) FROM dbo.detalle_venta_accesorio);

-- ---------------------------------------------------------------------------
-- PRUEBA 4: cancelar la MISMA venta otra vez.
-- Esperado: error 50013 y la foto igual a la anterior (no se devuelve el
-- stock dos veces).
-- ---------------------------------------------------------------------------
PRINT '=== PRUEBA 4: cancelar de nuevo la misma venta (debe rechazarse) ===';

BEGIN TRY
    EXEC dbo.sp_cambiar_estado_venta @cod_venta = @cod, @nuevo_estado = 'cancelada';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER()  AS numero_error,
           ERROR_MESSAGE() AS mensaje,
           @@TRANCOUNT     AS transacciones_abiertas;
END CATCH;

INSERT @foto (momento, stock_motos, stock_accesorio, ventas, detalles)
SELECT '4. DESPUES DE CANCELAR DE NUEVO', (SELECT SUM(stock_disponible) FROM dbo.modelo_motocicleta),
       (SELECT stock FROM dbo.accesorio WHERE id_accesorio = @id_acc),
       (SELECT COUNT(*) FROM dbo.venta), (SELECT COUNT(*) FROM dbo.detalle_venta_accesorio);

-- ---------------------------------------------------------------------------
-- RESUMEN: foto de la base en cada momento
-- Esperado: 0 = 1 (la venta incorrecta no dejo nada) | 2 = stocks -1, ventas y
-- detalles +1 | 3 = 4 = stocks como al principio (stock devuelto UNA sola vez).
-- ---------------------------------------------------------------------------
SELECT momento, stock_motos, stock_accesorio, ventas, detalles
FROM @foto
ORDER BY id;
GO

-- ============================================================================
-- PRUEBA 5 (OPCIONAL): AISLAMIENTO con dos ventanas de consulta
-- Muestra que dos cancelaciones simultaneas de la misma venta no devuelven el
-- stock dos veces. Se hace a mano, en DOS pestanas de SSMS (no ejecutar este
-- bloque de una vez). Primero, elegir una venta efectuada:
--     SELECT TOP 1 cod_venta FROM dbo.venta WHERE estado = 'efectuada';
--
-- VENTANA 1:
--     BEGIN TRAN;
--     EXEC dbo.sp_cambiar_estado_venta @cod_venta = <cod>, @nuevo_estado = 'cancelada';
--     -- NO ejecutar COMMIT todavia (las filas siguen bloqueadas).
--
-- VENTANA 2:
--     EXEC dbo.sp_cambiar_estado_venta @cod_venta = <cod>, @nuevo_estado = 'cancelada';
--     -- Queda ESPERANDO: la ventana 1 tiene la fila del modelo bloqueada.
--
-- VENTANA 1:
--     COMMIT;
--     -- La ventana 2 se destraba y falla con el error 50013: ya no encuentra
--     -- la venta 'efectuada'. El stock se devolvio una sola vez.
-- ============================================================================
