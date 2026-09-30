USE [X MOTORS];
GO

-- ============================================================================
-- 1. ENTIDAD BASE: PERSONA
-- Almacena los datos personales unificados de los actores del sistema.
-- ============================================================================
CREATE TABLE persona (
  dni INT NOT NULL,
  nombre VARCHAR(100) NOT NULL,
  apellido VARCHAR(100) NOT NULL,
  cuil BIGINT NOT NULL,
  telefono VARCHAR(30) NOT NULL,
  email VARCHAR(100) NOT NULL,
  CONSTRAINT pk_persona_dni PRIMARY KEY (dni)
);

-- ============================================================================
-- 2. ROLES HEREDADOS DE PERSONA (ESPECIALIZACIÓN / SUBTIPOS)
-- ============================================================================

-- VENDEDOR: Rol derivado de persona (ON DELETE CASCADE mantiene la integridad)
CREATE TABLE vendedor (
  dni_vendedor INT NOT NULL,
  CONSTRAINT pk_vendedor_dni_vendedor PRIMARY KEY (dni_vendedor),
  CONSTRAINT fk_vendedor_dni_vendedor FOREIGN KEY (dni_vendedor) 
    REFERENCES persona(dni) ON DELETE CASCADE
);

-- CLIENTE: Rol derivado de persona con validación de estados de compra
CREATE TABLE cliente (
  dni_cliente INT NOT NULL,
  estado VARCHAR(100) NOT NULL,
  CONSTRAINT ck_cliente_estado CHECK (estado IN ('interesado', 'en proceso de compra', 'comprador')),
  CONSTRAINT pk_cliente_dni_cliente PRIMARY KEY (dni_cliente),
  CONSTRAINT fk_cliente_dni_cliente FOREIGN KEY (dni_cliente) 
    REFERENCES persona(dni) ON DELETE CASCADE
);

-- ============================================================================
-- 3. CATÁLOGO Y GESTIÓN DE PRODUCTOS
-- ============================================================================

-- MODELO_MOTOCICLETA: Catálogo general de modelos vendidos
CREATE TABLE modelo_motocicleta (
  id_modelo INT NOT NULL IDENTITY(1,1),
  nombre_modelo VARCHAR(100) NOT NULL,
  marca VARCHAR(100) NOT NULL,
  cilindrada INT NOT NULL,
  color VARCHAR(50) NOT NULL,
  anio INT NOT NULL,
  stock_disponible INT NOT NULL CONSTRAINT df_modelo_motocicleta_stock_disponible DEFAULT 0,
  precio_lista DECIMAL(10,2) NOT NULL,
  CONSTRAINT pk_modelo_motocicleta PRIMARY KEY (id_modelo),
  CONSTRAINT ck_modelo_stock CHECK (stock_disponible >= 0)
);

-- MOTOCICLETA: Unidades físicas en stock identificadas por chasis y motor
CREATE TABLE motocicleta (
  numero_chasis VARCHAR(100) NOT NULL,
  numero_motor VARCHAR(100) NOT NULL,
  id_modelo INT NOT NULL,
  CONSTRAINT pk_motocicleta PRIMARY KEY (numero_chasis),
  CONSTRAINT fk_motocicleta_modelo_motocicleta FOREIGN KEY (id_modelo) 
    REFERENCES modelo_motocicleta(id_modelo),
  CONSTRAINT uq_motocicleta_numero_motor UNIQUE (numero_motor)
);

-- ============================================================================
-- 4. TRANSACCIONES PRINCIPALES
-- ============================================================================

-- VENTA: Registro final de la operación comercial
CREATE TABLE venta (
  cod_venta INT NOT NULL IDENTITY(1,1),
  fecha DATE NOT NULL,
  metodo_pago VARCHAR(50) NOT NULL,
  precio_venta_moto DECIMAL(12,2) NOT NULL, -- Congela el precio al vender
  monto_total DECIMAL(12,2) NOT NULL,
  estado VARCHAR(30) NOT NULL CONSTRAINT df_venta_estado DEFAULT 'efectuada',
  dni_cliente INT NOT NULL,
  dni_vendedor INT NOT NULL,
  numero_chasis VARCHAR(100) NOT NULL,
  CONSTRAINT pk_venta PRIMARY KEY (cod_venta),
  CONSTRAINT ck_venta_estado CHECK (estado IN ('efectuada', 'cancelada', 'reembolsada')),
  CONSTRAINT fk_venta_cliente FOREIGN KEY (dni_cliente) 
    REFERENCES cliente(dni_cliente),
  CONSTRAINT fk_venta_vendedor FOREIGN KEY (dni_vendedor) 
    REFERENCES vendedor(dni_vendedor),
  CONSTRAINT fk_venta_motocicleta FOREIGN KEY (numero_chasis) 
    REFERENCES motocicleta(numero_chasis),
  CONSTRAINT uq_venta_numero_chasis UNIQUE (numero_chasis) -- Una moto física se vende una sola vez
);

-- DIRECCION_CLIENTE: Extensión 1:1 de los datos de domicilio del cliente
CREATE TABLE direccion_cliente (
  dni_cliente INT NOT NULL,
  calle VARCHAR(100) NOT NULL,
  numero INT NOT NULL,
  ciudad VARCHAR(100) NOT NULL,
  provincia VARCHAR(100) NOT NULL,
  codigo_postal VARCHAR(10) NOT NULL,
  CONSTRAINT pk_direccion_cliente PRIMARY KEY (dni_cliente),
  CONSTRAINT fk_direccion_cliente_dni_cliente FOREIGN KEY (dni_cliente) 
    REFERENCES cliente(dni_cliente) ON DELETE CASCADE
);

-- ============================================================================
-- 5. MÓDULO DE PROVEEDORES Y ABASTECIMIENTO
-- ============================================================================

-- PROVEEDOR: Entidad que suministra modelos y accesorios
CREATE TABLE proveedor (
  cuit_proveedor BIGINT NOT NULL,
  razon_social VARCHAR(100) NOT NULL,
  email VARCHAR(100) NOT NULL,
  telefono VARCHAR(30) NOT NULL,
  CONSTRAINT pk_proveedor PRIMARY KEY (cuit_proveedor)
);

-- DIRECCION_PROVEEDOR: Domicilio comercial del proveedor
CREATE TABLE direccion_proveedor (
  cuit_proveedor BIGINT NOT NULL,
  calle VARCHAR(100) NOT NULL,
  numero INT NOT NULL,
  ciudad VARCHAR(100) NOT NULL,
  provincia VARCHAR(100) NOT NULL,
  codigo_postal VARCHAR(10) NOT NULL,
  CONSTRAINT pk_direccion_proveedor PRIMARY KEY (cuit_proveedor),
  CONSTRAINT fk_direccion_proveedor_cuit_proveedor FOREIGN KEY (cuit_proveedor) 
    REFERENCES proveedor(cuit_proveedor) ON DELETE CASCADE
);

-- PROVISION_MOTOCICLETA: Relación N:M entre Proveedores y Modelos
CREATE TABLE provision_motocicleta (
  cuit_proveedor BIGINT NOT NULL,
  id_modelo INT NOT NULL,
  CONSTRAINT pk_provision_motocicleta PRIMARY KEY (cuit_proveedor, id_modelo),
  CONSTRAINT fk_provision_motocicleta_cuit_proveedor FOREIGN KEY (cuit_proveedor) 
    REFERENCES proveedor(cuit_proveedor),
  CONSTRAINT fk_provision_motocicleta_id_modelo FOREIGN KEY (id_modelo) 
    REFERENCES modelo_motocicleta(id_modelo)
);

-- ============================================================================
-- 6. MÓDULO DE ACCESORIOS Y DETALLES
-- ============================================================================

-- ACCESORIO: Catálogo de repuestos e indumentaria
CREATE TABLE accesorio (
  id_accesorio INT NOT NULL IDENTITY(1,1),
  descripcion VARCHAR(255) NOT NULL,
  stock INT NOT NULL CONSTRAINT df_accesorio_stock DEFAULT 0,
  categoria VARCHAR(50) NOT NULL,
  precio_lista DECIMAL(12,2) NOT NULL,
  precio_costo DECIMAL(12,2) NOT NULL,
  CONSTRAINT pk_accesorio PRIMARY KEY (id_accesorio),
  CONSTRAINT ck_accesorio_stock CHECK (stock >= 0),
  CONSTRAINT ck_accesorio_precio_lista CHECK (precio_lista >= 0),
  CONSTRAINT ck_accesorio_precio_costo CHECK (precio_costo >= 0)
);

-- PROVISION_ACCESORIO: Relación N:M entre Proveedores y Accesorios
CREATE TABLE provision_accesorio (
  cuit_proveedor BIGINT NOT NULL,
  id_accesorio INT NOT NULL,
  CONSTRAINT pk_provision_accesorio PRIMARY KEY (cuit_proveedor, id_accesorio),
  CONSTRAINT fk_provision_accesorio_cuit_proveedor FOREIGN KEY (cuit_proveedor) 
    REFERENCES proveedor(cuit_proveedor),
  CONSTRAINT fk_provision_accesorio_id_accesorio FOREIGN KEY (id_accesorio) 
    REFERENCES accesorio(id_accesorio)
);

-- DETALLE_VENTA_ACCESORIO: Relación N:M que registra los accesorios vendidos en cada venta
CREATE TABLE detalle_venta_accesorio (
  cod_venta INT NOT NULL,
  id_accesorio INT NOT NULL,
  cantidad INT NOT NULL,
  precio_pactado DECIMAL(12,2) NOT NULL, -- Mantiene el valor pactado en el momento de la transacción
  CONSTRAINT pk_detalle_venta_accesorio PRIMARY KEY (cod_venta, id_accesorio),
  CONSTRAINT fk_detalle_venta_accesorio_venta FOREIGN KEY (cod_venta) 
    REFERENCES venta(cod_venta),
  CONSTRAINT fk_detalle_venta_accesorio_accesorio FOREIGN KEY (id_accesorio) 
    REFERENCES accesorio(id_accesorio),
  CONSTRAINT ck_detalle_venta_accesorio_cantidad CHECK (cantidad > 0),
  CONSTRAINT ck_detalle_venta_accesorio_precio CHECK (precio_pactado >= 0)
);

-- ============================================================================
-- 7. REGLAS DE NEGOCIO ADICIONALES (RN) Y TRAZABILIDAD
-- ============================================================================

-- COTIZACION: Presupuestos previos solicitados por clientes (RN12: 7 días corridos)
CREATE TABLE cotizacion (
  id_cotizacion INT NOT NULL IDENTITY(1,1),
  fecha_emision DATE NOT NULL,
  fecha_vencimiento DATE NOT NULL,
  precio_cotizado DECIMAL(12,2) NOT NULL,
  dni_cliente INT NOT NULL,
  id_modelo INT NOT NULL,
  CONSTRAINT pk_cotizacion PRIMARY KEY (id_cotizacion),
  CONSTRAINT fk_cotizacion_dni_cliente FOREIGN KEY (dni_cliente) 
    REFERENCES cliente(dni_cliente),
  CONSTRAINT fk_cotizacion_id_modelo FOREIGN KEY (id_modelo) 
    REFERENCES modelo_motocicleta(id_modelo),
  CONSTRAINT ck_cotizacion_precio CHECK (precio_cotizado >= 0),
  CONSTRAINT ck_cotizacion_validez_7_dias CHECK (fecha_vencimiento = DATEADD(day, 7, fecha_emision))
);

-- HISTORIAL_DE_PRECIO: Registro histórico de modificaciones de listas de precios
CREATE TABLE historial_de_precio (
  id_historial INT NOT NULL IDENTITY(1,1),
  precio_nuevo DECIMAL(12,2) NOT NULL,
  precio_anterior DECIMAL(12,2) NOT NULL,
  fecha_modificacion DATE NOT NULL,
  id_modelo INT NOT NULL,
  CONSTRAINT pk_historial_de_precio PRIMARY KEY (id_historial),
  CONSTRAINT fk_historial_de_precio_id_modelo FOREIGN KEY (id_modelo) 
    REFERENCES modelo_motocicleta(id_modelo),
  CONSTRAINT ck_historial_precio_nuevo CHECK (precio_nuevo >= 0),
  CONSTRAINT ck_historial_precio_anterior CHECK (precio_anterior >= 0)
);


