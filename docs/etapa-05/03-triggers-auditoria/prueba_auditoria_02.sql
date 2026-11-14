-- ============================================================================
-- SCRIPT DE PRUEBA CORREGIDO: TRIGGER DE HISTORIAL DE PRECIO (RN7)
-- ============================================================================

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

USE [X MOTORS];
GO

PRINT '--- 1. ASEGURANDO DATOS DE PRUEBA EN modelo_motocicleta ---';
GO

-- Insertar un modelo de prueba si no existe
IF NOT EXISTS (SELECT 1 FROM modelo_motocicleta WHERE nombre_modelo = 'Test Historial Precio')
BEGIN
    INSERT INTO modelo_motocicleta (nombre_modelo, marca, cilindrada, color, anio, stock_disponible, precio_lista)
    VALUES ('Test Historial Precio', 'Bajaj', 150, 'Azul', 2026, 10, 2000000.00);
END
GO

PRINT '--- 2. EJECUTANDO PRUEBAS SOBRE PRECIOS ---';
GO

-- PRUEBA A: UPDATE falso (Modificar solo el stock, el precio_lista sigue igual).
-- No debe insertar historial.
UPDATE dbo.modelo_motocicleta
SET stock_disponible = 15
WHERE nombre_modelo = 'Test Historial Precio';
GO

-- PRUEBA B: UPDATE que asigna exactamente EL MISMO precio.
-- El operador EXCEPT detecta que no hay cambio real y NO inserta historial.
UPDATE dbo.modelo_motocicleta
SET precio_lista = 2000000.00
WHERE nombre_modelo = 'Test Historial Precio';
GO

-- PRUEBA C: Primer cambio real de precio (De 2.000.000 a 2.300.000).
-- Debe insertar un registro en historial_de_precio.
UPDATE dbo.modelo_motocicleta
SET precio_lista = 2300000.00
WHERE nombre_modelo = 'Test Historial Precio';
GO

-- PRUEBA D: Segundo cambio real de precio (De 2.300.000 a 2.500.000).
-- Debe insertar un segundo registro en historial_de_precio.
UPDATE dbo.modelo_motocicleta
SET precio_lista = 2500000.00
WHERE nombre_modelo = 'Test Historial Precio';
GO


-- ============================================================================
-- 3. VERIFICACIÓN DE RESULTADOS EN historial_de_precio
-- ============================================================================

PRINT '--- 3. RESULTADOS DE LA TABLA historial_de_precio ---';
SELECT 
    h.id_historial,
    h.id_modelo,
    m.nombre_modelo,
    h.precio_anterior,
    h.precio_nuevo,
    h.fecha_modificacion
FROM dbo.historial_de_precio h
JOIN dbo.modelo_motocicleta m ON h.id_modelo = m.id_modelo
WHERE m.nombre_modelo = 'Test Historial Precio'
ORDER BY h.id_historial ASC;
GO
