-- ============================================================================
-- SCRIPT RÁPIDO DE TESTEO DE ÍNDICES - X MOTORS
-- ============================================================================

USE [X MOTORS];
GO

PRINT '--- EJECUTANDO CONSULTA DE PRUEBA SOBRE VENTAS ---';
GO

-- Esta consulta utiliza exactamente el índice [ix_venta_fecha_estado]
SELECT 
    cod_venta, 
    monto_total, 
    dni_cliente, 
    dni_vendedor
FROM dbo.venta
WHERE fecha >= '2026-01-01' 
  AND estado = 'efectuada';
GO
