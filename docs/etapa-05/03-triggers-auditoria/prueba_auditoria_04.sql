USE [X MOTORS];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @dni INT, @est_orig VARCHAR(30), @est_otro VARCHAR(30);
DECLARE @antes INT, @despues INT, @filas INT;

SELECT TOP 1 @dni = dni_cliente, @est_orig = estado
FROM dbo.cliente WHERE estado IS NOT NULL ORDER BY dni_cliente;

SELECT TOP 1 @est_otro = estado
FROM dbo.cliente WHERE estado <> @est_orig ORDER BY estado;

IF @dni IS NULL OR @est_otro IS NULL
BEGIN
    PRINT 'Faltan datos: hace falta un cliente y al menos dos estados distintos en la tabla.';
    RETURN;
END

PRINT 'Cliente: ' + CAST(@dni AS VARCHAR(20)) + ' | ' + @est_orig + ' -> ' + @est_otro;

BEGIN TRAN;

    -- PRUEBA 1: cambio de estado -> debe auditarse con anterior y nuevo
    PRINT '=== PRUEBA 1: cambio de estado ===';
    UPDATE dbo.cliente SET estado = @est_otro WHERE dni_cliente = @dni;

    IF EXISTS (SELECT 1 FROM dbo.auditoria_cliente
               WHERE dni_cliente = @dni
                 AND estado_anterior = @est_orig AND estado_nuevo = @est_otro)
        PRINT 'PASS: cambio auditado con estado anterior y nuevo';
    ELSE PRINT 'FAIL: no se audito el cambio de estado';

    -- PRUEBA 2: UPDATE con el MISMO estado -> NO debe auditarse
    PRINT '=== PRUEBA 2: UPDATE sin cambio real ===';
    SELECT @antes = COUNT(*) FROM dbo.auditoria_cliente WHERE dni_cliente = @dni;
    UPDATE dbo.cliente SET estado = estado WHERE dni_cliente = @dni;
    SELECT @despues = COUNT(*) FROM dbo.auditoria_cliente WHERE dni_cliente = @dni;

    IF @antes = @despues PRINT 'PASS: no se audito un UPDATE sin cambio';
    ELSE PRINT 'FAIL: se audito un UPDATE que no cambio el estado';

    -- PRUEBA 3: UPDATE multi-fila -> una fila de auditoria por cliente modificado
    PRINT '=== PRUEBA 3: UPDATE multi-fila ===';
    SELECT @antes = COUNT(*) FROM dbo.auditoria_cliente;
    UPDATE dbo.cliente SET estado = @est_orig WHERE estado <> @est_orig;
    SET @filas = @@ROWCOUNT;
    SELECT @despues = COUNT(*) FROM dbo.auditoria_cliente;

    PRINT 'Clientes modificados: ' + CAST(@filas AS VARCHAR(10));
    IF @despues - @antes = @filas PRINT 'PASS: una fila de auditoria por cada cliente cambiado';
    ELSE PRINT 'FAIL: la cantidad de filas auditadas no coincide con las modificadas';

    SELECT * FROM dbo.auditoria_cliente WHERE dni_cliente = @dni;

ROLLBACK;   -- clientes y auditoria vuelven a como estaban
GO