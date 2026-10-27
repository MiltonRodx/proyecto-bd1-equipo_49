-- ============================================================================
-- ETAPA V - ANEXO B: INDICES DE PERFORMANCE
-- Archivo: etapa_v/procedimientos_funciones/04_indices.sql
-- Sistema: X Motors - Base de Datos I - Grupo 49 - FaCENA (UNNE)
--
-- Indices de cobertura sobre las tablas mas consultadas. Idempotente:
-- con IF NOT EXISTS sobre sys.indexes for nonclustered.
-- Con pocos datos, el optimizador puede seguir eligiendo escaneos; los
-- indices quedan igual preparados para la escala de produccion.
-- ============================================================================

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

USE [X MOTORS];
GO

-- 1. Reportes de ventas por rango de fechas y estado
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'ix_venta_fecha_estado' AND object_id = OBJECT_ID('dbo.venta'))
    CREATE INDEX ix_venta_fecha_estado
        ON dbo.venta (fecha, estado)
        INCLUDE (monto_total, dni_cliente, dni_vendedor);
GO

-- 2. Historial de compras por cliente
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'ix_venta_cliente_fecha' AND object_id = OBJECT_ID('dbo.venta'))
    CREATE INDEX ix_venta_cliente_fecha
        ON dbo.venta (dni_cliente, fecha)
        INCLUDE (monto_total, estado);
GO

-- 3. Ranking de vendedores por periodo
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'ix_venta_vendedor_fecha' AND object_id = OBJECT_ID('dbo.venta'))
    CREATE INDEX ix_venta_vendedor_fecha
        ON dbo.venta (dni_vendedor, fecha)
        INCLUDE (monto_total, estado);
GO

-- 4. Accesorios mas vendidos
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'ix_detalle_venta_accesorio_accesorio' AND object_id = OBJECT_ID('dbo.detalle_venta_accesorio'))
    CREATE INDEX ix_detalle_venta_accesorio_accesorio
        ON dbo.detalle_venta_accesorio (id_accesorio)
        INCLUDE (cod_venta, cantidad, precio_pactado);
GO

-- 5. Cotizaciones vigentes por cliente
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'ix_cotizacion_cliente_vencimiento' AND object_id = OBJECT_ID('dbo.cotizacion'))
    CREATE INDEX ix_cotizacion_cliente_vencimiento
        ON dbo.cotizacion (dni_cliente, fecha_vencimiento)
        INCLUDE (precio_cotizado, id_modelo);
GO

-- 6. Consultas de cotizaciones vencidas
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'ix_cotizacion_vencimiento' AND object_id = OBJECT_ID('dbo.cotizacion'))
    CREATE INDEX ix_cotizacion_vencimiento
        ON dbo.cotizacion (fecha_vencimiento)
        INCLUDE (dni_cliente, id_modelo, precio_cotizado);
GO

-- 7. Evolucion de precios por modelo
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'ix_historial_precio_modelo_fecha' AND object_id = OBJECT_ID('dbo.historial_de_precio'))
    CREATE INDEX ix_historial_precio_modelo_fecha
        ON dbo.historial_de_precio (id_modelo, fecha_modificacion DESC)
        INCLUDE (precio_anterior, precio_nuevo);
GO

-- 8. Stock fisico por modelo
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'ix_motocicleta_modelo' AND object_id = OBJECT_ID('dbo.motocicleta'))
    CREATE INDEX ix_motocicleta_modelo
        ON dbo.motocicleta (id_modelo)
        INCLUDE (numero_motor);
GO

-- 9. Proveedores por modelo de moto
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'ix_provision_motocicleta_modelo' AND object_id = OBJECT_ID('dbo.provision_motocicleta'))
    CREATE INDEX ix_provision_motocicleta_modelo
        ON dbo.provision_motocicleta (id_modelo)
        INCLUDE (cuit_proveedor);
GO

-- 10. Proveedores por accesorio
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'ix_provision_accesorio_accesorio' AND object_id = OBJECT_ID('dbo.provision_accesorio'))
    CREATE INDEX ix_provision_accesorio_accesorio
        ON dbo.provision_accesorio (id_accesorio)
        INCLUDE (cuit_proveedor);
GO

PRINT '04_indices.sql ejecutado: 10 indices disponibles en dbo.';
GO
