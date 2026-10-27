-- ============================================================================
-- ETAPA V - TEMA 3: TABLAS DE AUDITORIA
-- Archivo: etapa_v/triggers_auditoria/01_tablas_auditoria.sql
-- Sistema: X Motors - Base de Datos I - Grupo 49 - FaCENA (UNNE)
--
-- Tablas de auditoria SIN claves foraneas: la auditoria debe sobrevivir al
-- borrado del registro auditado. El usuario y la fecha/hora salen de los
-- DEFAULT, asi los triggers no tienen que informarlos.
-- Idempotente: solo crea una tabla si no existe.
-- ============================================================================

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

USE [X MOTORS];
GO

-- ============================================================================
-- 1. auditoria_venta: INSERT, UPDATE y DELETE sobre dbo.venta
-- ============================================================================
IF OBJECT_ID('dbo.auditoria_venta', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.auditoria_venta (
        id_auditoria     INT IDENTITY(1,1) NOT NULL,
        cod_venta        INT NOT NULL,
        accion           VARCHAR(10) NOT NULL,
        estado_anterior  VARCHAR(30) NULL,
        estado_nuevo     VARCHAR(30) NULL,
        monto_anterior   DECIMAL(12,2) NULL,
        monto_nuevo      DECIMAL(12,2) NULL,
        usuario          VARCHAR(128) NOT NULL
            CONSTRAINT df_auditoria_venta_usuario DEFAULT USER_NAME(),
        fecha_hora       DATETIME2(0) NOT NULL
            CONSTRAINT df_auditoria_venta_fecha DEFAULT SYSDATETIME(),
        CONSTRAINT pk_auditoria_venta PRIMARY KEY (id_auditoria),
        CONSTRAINT ck_auditoria_venta_accion
            CHECK (accion IN ('INSERT', 'UPDATE', 'DELETE'))
    );

    CREATE INDEX ix_auditoria_venta_cod_venta
        ON dbo.auditoria_venta (cod_venta, fecha_hora DESC);

    PRINT 'auditoria_venta creada.';
END;
ELSE
    PRINT 'auditoria_venta ya existe; no se modifica.';
GO

-- ============================================================================
-- 2. auditoria_cliente: cambios de estado sobre dbo.cliente
-- ============================================================================
IF OBJECT_ID('dbo.auditoria_cliente', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.auditoria_cliente (
        id_auditoria     INT IDENTITY(1,1) NOT NULL,
        dni_cliente      INT NOT NULL,
        estado_anterior  VARCHAR(100) NULL,
        estado_nuevo     VARCHAR(100) NULL,
        usuario          VARCHAR(128) NOT NULL
            CONSTRAINT df_auditoria_cliente_usuario DEFAULT USER_NAME(),
        fecha_hora       DATETIME2(0) NOT NULL
            CONSTRAINT df_auditoria_cliente_fecha DEFAULT SYSDATETIME(),
        CONSTRAINT pk_auditoria_cliente PRIMARY KEY (id_auditoria)
    );

    CREATE INDEX ix_auditoria_cliente_dni
        ON dbo.auditoria_cliente (dni_cliente, fecha_hora DESC);

    PRINT 'auditoria_cliente creada.';
END;
ELSE
    PRINT 'auditoria_cliente ya existe; no se modifica.';
GO

PRINT '01_tablas_auditoria.sql ejecutado.';
GO
