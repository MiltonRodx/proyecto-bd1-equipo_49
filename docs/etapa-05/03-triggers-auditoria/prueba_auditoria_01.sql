-- ============================================================================
-- SCRIPT DE PRUEBA DE TRIGGERS Y AUDITORIA - X MOTORS
-- ============================================================================

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

USE [X MOTORS];
GO

PRINT '--- 1. CREANDO TRIGGERS DE AUDITORIA ADAPTADOS AL MODELO ---';
GO

-- ----------------------------------------------------------------------------
-- A. Trigger para dbo.cliente (Audita cambios de estado)
-- ----------------------------------------------------------------------------
CREATE OR ALTER TRIGGER tr_auditoria_cliente_dml
ON dbo.cliente
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    -- INSERT: Nuevo cliente registrado
    IF EXISTS (SELECT 1 FROM inserted) AND NOT EXISTS (SELECT 1 FROM deleted)
    BEGIN
        INSERT INTO dbo.auditoria_cliente (dni_cliente, estado_anterior, estado_nuevo)
        SELECT dni_cliente, NULL, estado 
        FROM inserted;
    END

    -- UPDATE: Cambio de estado del cliente
    IF EXISTS (SELECT 1 FROM inserted) AND EXISTS (SELECT 1 FROM deleted)
    BEGIN
        INSERT INTO dbo.auditoria_cliente (dni_cliente, estado_anterior, estado_nuevo)
        SELECT i.dni_cliente, d.estado, i.estado
        FROM inserted i
        JOIN deleted d ON i.dni_cliente = d.dni_cliente
        WHERE ISNULL(d.estado, '') <> ISNULL(i.estado, '');
    END

    -- DELETE: Cliente eliminado
    IF NOT EXISTS (SELECT 1 FROM inserted) AND EXISTS (SELECT 1 FROM deleted)
    BEGIN
        INSERT INTO dbo.auditoria_cliente (dni_cliente, estado_anterior, estado_nuevo)
        SELECT dni_cliente, estado, 'ELIMINADO' 
        FROM deleted;
    END
END;
GO

-- ----------------------------------------------------------------------------
-- B. Trigger para dbo.venta (Audita operaciones de venta)
-- ----------------------------------------------------------------------------
CREATE OR ALTER TRIGGER tr_auditoria_venta_dml
ON dbo.venta
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    -- INSERT
    IF EXISTS (SELECT 1 FROM inserted) AND NOT EXISTS (SELECT 1 FROM deleted)
    BEGIN
        INSERT INTO dbo.auditoria_venta (cod_venta, accion, estado_anterior, estado_nuevo, monto_anterior, monto_nuevo)
        SELECT cod_venta, 'INSERT', NULL, estado, NULL, monto_total 
        FROM inserted;
    END

    -- UPDATE
    IF EXISTS (SELECT 1 FROM inserted) AND EXISTS (SELECT 1 FROM deleted)
    BEGIN
        INSERT INTO dbo.auditoria_venta (cod_venta, accion, estado_anterior, estado_nuevo, monto_anterior, monto_nuevo)
        SELECT i.cod_venta, 'UPDATE', d.estado, i.estado, d.monto_total, i.monto_total
        FROM inserted i
        JOIN deleted d ON i.cod_venta = d.cod_venta;
    END

    -- DELETE
    IF NOT EXISTS (SELECT 1 FROM inserted) AND EXISTS (SELECT 1 FROM deleted)
    BEGIN
        INSERT INTO dbo.auditoria_venta (cod_venta, accion, estado_anterior, estado_nuevo, monto_anterior, monto_nuevo)
        SELECT cod_venta, 'DELETE', estado, 'ELIMINADO', monto_total, NULL 
        FROM deleted;
    END
END;
GO

PRINT 'Triggers creados con éxito.';
GO


-- ============================================================================
-- 2. SECUENCIA DE PRUEBAS (Respetando Claves Foráneas y Restricciones)
-- ============================================================================

PRINT '--- 2. INSERTANDO DATOS BASE PARA LA PRUEBA ---';
GO

-- 1. Insertar Persona base requerida por la jerarquía de herencia para CLIENTE
IF NOT EXISTS (SELECT 1 FROM persona WHERE dni = 40547162)
    INSERT INTO persona (dni, nombre, apellido, cuil, telefono, email)
    VALUES (40547162, 'Fernando', 'Zacarías', 20405471625, '3794123456', 'fernando@xmotors.com');

-- 2. Insertar Persona base requerida para VENDEDOR
IF NOT EXISTS (SELECT 1 FROM persona WHERE dni = 30111222)
    INSERT INTO persona (dni, nombre, apellido, cuil, telefono, email)
    VALUES (30111222, 'Carlos', 'Vendedor', 20301112223, '3794987654', 'carlos@xmotors.com');

-- 3. Registrar rol VENDEDOR
IF NOT EXISTS (SELECT 1 FROM vendedor WHERE dni_vendedor = 30111222)
    INSERT INTO vendedor (dni_vendedor) VALUES (30111222);

-- 4. Registrar rol CLIENTE (Estado inicial: 'interesado')
IF NOT EXISTS (SELECT 1 FROM cliente WHERE dni_cliente = 40547162)
    INSERT INTO cliente (dni_cliente, estado) VALUES (40547162, 'interesado');

-- 5. Registrar un Modelo de Moto de prueba
INSERT INTO modelo_motocicleta (nombre_modelo, marca, cilindrada, color, anio, stock_disponible, precio_lista)
VALUES ('NS 200 UG', 'Bajaj', 200, 'Negro', 2026, 5, 3500000.00);

-- Capturar el ID del modelo recién insertado
DECLARE @id_modelo_prueba INT = SCOPE_IDENTITY();

-- 6. Registrar una Motocicleta física (unidad en stock)
INSERT INTO motocicleta (numero_chasis, numero_motor, id_modelo)
VALUES ('CHASIS-TEST-999', 'MOTOR-TEST-999', @id_modelo_prueba);
GO


PRINT '--- 3. EJECUTANDO OPERACIONES DML A AUDITAR ---';
GO

-- A. Actualizar el estado del cliente (De 'interesado' a 'en proceso de compra')
UPDATE dbo.cliente
SET estado = 'en proceso de compra'
WHERE dni_cliente = 40547162;
GO

-- B. Registrar una Venta de prueba
DECLARE @id_modelo INT = (SELECT TOP 1 id_modelo FROM modelo_motocicleta WHERE nombre_modelo = 'NS 200 UG');
INSERT INTO dbo.venta (fecha, metodo_pago, precio_venta_moto, monto_total, estado, dni_cliente, dni_vendedor, numero_chasis)
VALUES (SYSDATETIME(), 'Efectivo', 3500000.00, 3500000.00, 'efectuada', 40547162, 30111222, 'CHASIS-TEST-999');
GO

-- C. Actualizar el estado de la venta (De 'efectuada' a 'cancelada')
-- Nota: Para actualizar el estado con el índice filtrado (ux_venta_chasis_vigente), 
-- primero aseguramos la transición lógica.
UPDATE dbo.venta
SET estado = 'cancelada', monto_total = 0.00
WHERE numero_chasis = 'CHASIS-TEST-999';
GO

-- D. Eliminar la venta y el cliente para probar la supervivencia de la auditoría (Sin FK restrictiva)
DELETE FROM dbo.venta WHERE numero_chasis = 'CHASIS-TEST-999';
DELETE FROM dbo.cliente WHERE dni_cliente = 40547162;
GO


-- ============================================================================
-- 4. VERIFICACIÓN DE RESULTADOS EN LAS TABLAS DE AUDITORÍA
-- ============================================================================

PRINT '--- 4. RESULTADOS DE LA AUDITORIA DE CLIENTES ---';
SELECT 
    id_auditoria,
    dni_cliente,
    estado_anterior,
    estado_nuevo,
    usuario,
    fecha_hora
FROM dbo.auditoria_cliente
WHERE dni_cliente = 40547162
ORDER BY fecha_hora DESC;
GO

PRINT '--- 4. RESULTADOS DE LA AUDITORIA DE VENTAS ---';
SELECT 
    id_auditoria,
    cod_venta,
    accion,
    estado_anterior,
    estado_nuevo,
    monto_anterior,
    monto_nuevo,
    usuario,
    fecha_hora
FROM dbo.auditoria_venta
ORDER BY id_auditoria DESC;
GO
