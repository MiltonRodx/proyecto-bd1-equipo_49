USE [X MOTORS];
GO
SET NOCOUNT ON;

DECLARE @dni_cliente INT, @dni_vendedor INT, @id_acc INT, @chasis VARCHAR(100);
DECLARE @cod INT, @json NVARCHAR(MAX), @antes INT, @despues INT;

SELECT TOP 1 @dni_cliente  = dni_cliente  FROM dbo.cliente  ORDER BY dni_cliente;
SELECT TOP 1 @dni_vendedor = dni_vendedor FROM dbo.vendedor ORDER BY dni_vendedor;
SELECT TOP 1 @id_acc = id_accesorio FROM dbo.accesorio WHERE stock >= 1 ORDER BY id_accesorio;

SELECT TOP 1 @chasis = mo.numero_chasis
FROM dbo.motocicleta AS mo
JOIN dbo.modelo_motocicleta AS m ON m.id_modelo = mo.id_modelo
WHERE m.stock_disponible >= 1
  AND NOT EXISTS (SELECT 1 FROM dbo.venta v
                  WHERE v.numero_chasis = mo.numero_chasis AND v.estado = 'efectuada')
ORDER BY mo.numero_chasis;

-- PRUEBA 1: INSERT -> debe auditarse
PRINT '=== PRUEBA 1: INSERT ===';
SET @json = N'[{"id_accesorio":' + CAST(@id_acc AS VARCHAR(10)) + N',"cantidad":1}]';
EXEC dbo.sp_RegistrarVentaCompleta
     @dni_cliente = @dni_cliente, @dni_vendedor = @dni_vendedor,
     @numero_chasis = @chasis, @metodo_pago = 'efectivo',
     @accesorios_json = @json, @cod_venta = @cod OUTPUT;

IF EXISTS (SELECT 1 FROM dbo.auditoria_venta
           WHERE cod_venta = @cod AND accion = 'INSERT'
             AND estado_anterior IS NULL AND monto_anterior IS NULL
             AND estado_nuevo = 'efectuada')
    PRINT 'PASS: INSERT auditado (anteriores en NULL)';
ELSE PRINT 'FAIL: no se audito el INSERT';

-- PRUEBA 2: UPDATE que NO cambia estado ni monto -> NO debe auditarse
PRINT '=== PRUEBA 2: UPDATE sin cambios auditados ===';
SELECT @antes = COUNT(*) FROM dbo.auditoria_venta WHERE cod_venta = @cod;
UPDATE dbo.venta SET estado = estado WHERE cod_venta = @cod;
SELECT @despues = COUNT(*) FROM dbo.auditoria_venta WHERE cod_venta = @cod;

IF @antes = @despues PRINT 'PASS: no se audito un UPDATE sin cambios';
ELSE PRINT 'FAIL: se audito un UPDATE que no cambio nada';

-- PRUEBA 3: UPDATE de estado -> debe auditarse con anterior y nuevo
PRINT '=== PRUEBA 3: UPDATE de estado (efectuada -> cancelada) ===';
EXEC dbo.sp_cambiar_estado_venta @cod_venta = @cod, @nuevo_estado = 'cancelada';

IF EXISTS (SELECT 1 FROM dbo.auditoria_venta
           WHERE cod_venta = @cod AND accion = 'UPDATE'
             AND estado_anterior = 'efectuada' AND estado_nuevo = 'cancelada')
    PRINT 'PASS: UPDATE auditado con estado anterior y nuevo';
ELSE PRINT 'FAIL: no se audito el cambio de estado';

-- PRUEBA 4: DELETE -> debe auditarse (dentro de una transaccion que se deshace)
PRINT '=== PRUEBA 4: DELETE (con ROLLBACK al final) ===';
BEGIN TRAN;
    DELETE FROM dbo.detalle_venta_accesorio WHERE cod_venta = @cod;  -- hijo primero (FK)
    DELETE FROM dbo.venta WHERE cod_venta = @cod;

    IF EXISTS (SELECT 1 FROM dbo.auditoria_venta
               WHERE cod_venta = @cod AND accion = 'DELETE'
                 AND estado_anterior = 'cancelada' AND estado_nuevo IS NULL)
        PRINT 'PASS: DELETE auditado (nuevos en NULL)';
    ELSE PRINT 'FAIL: no se audito el DELETE';
ROLLBACK;   -- la venta y su detalle vuelven a existir

-- Resumen: todo lo auditado para esta venta
SELECT * FROM dbo.auditoria_venta WHERE cod_venta = @cod;
GO