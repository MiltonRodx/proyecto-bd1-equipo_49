-- ============================================================================
-- ETAPA V - ANEXO A: SEGURIDAD (ROLES, USUARIOS Y PERMISOS)
-- Archivo: etapa_v/procedimientos_funciones/03_seguridad.sql
-- Sistema: X Motors - Base de Datos I - Grupo 49 - FaCENA (UNNE)
--
-- Modelo de minimo privilegio:
--   rol_xmotors_admin    -> administracion completa del esquema
--   rol_xmotors_vendedor -> operar ventas y consultar catalogo/clientes
--   rol_xmotors_consulta -> solo lectura de negocio, sin auditoria ni historial
--
-- Los usuarios son WITHOUT LOGIN: reproducibles sin permisos de sysadmin y
-- probables con EXECUTE AS USER. En produccion se mapean a logins reales.
-- Idempotente: roles, usuarios y permisos solo se recrean si no existen.
-- ============================================================================

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

USE [X MOTORS];
GO

-- ============================================================================
-- 1. Roles de base de datos
-- ============================================================================
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'rol_xmotors_admin')
BEGIN
    CREATE ROLE rol_xmotors_admin;
    PRINT 'rol_xmotors_admin creado.';
END;

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'rol_xmotors_vendedor')
BEGIN
    CREATE ROLE rol_xmotors_vendedor;
    PRINT 'rol_xmotors_vendedor creado.';
END;

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'rol_xmotors_consulta')
BEGIN
    CREATE ROLE rol_xmotors_consulta;
    PRINT 'rol_xmotors_consulta creado.';
END;
GO

-- ============================================================================
-- 2. Usuarios de prueba (WITHOUT LOGIN)
-- ============================================================================
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'usr_xmotors_admin')
BEGIN
    CREATE USER usr_xmotors_admin WITHOUT LOGIN;
    PRINT 'usr_xmotors_admin creado.';
END;

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'usr_xmotors_vendedor')
BEGIN
    CREATE USER usr_xmotors_vendedor WITHOUT LOGIN;
    PRINT 'usr_xmotors_vendedor creado.';
END;

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'usr_xmotors_consulta')
BEGIN
    CREATE USER usr_xmotors_consulta WITHOUT LOGIN;
    PRINT 'usr_xmotors_consulta creado.';
END;
GO

-- Membresias
IF NOT EXISTS (SELECT 1 FROM sys.database_principals AS r WHERE r.name = 'rol_xmotors_admin'
               AND EXISTS (SELECT 1 FROM sys.database_role_members m WHERE m.role_principal_id = r.principal_id AND m.member_principal_id = USER_ID('usr_xmotors_admin')))
    ALTER ROLE rol_xmotors_admin ADD MEMBER usr_xmotors_admin;

IF NOT EXISTS (SELECT 1 FROM sys.database_principals AS r WHERE r.name = 'rol_xmotors_vendedor'
               AND EXISTS (SELECT 1 FROM sys.database_role_members m WHERE m.role_principal_id = r.principal_id AND m.member_principal_id = USER_ID('usr_xmotors_vendedor')))
    ALTER ROLE rol_xmotors_vendedor ADD MEMBER usr_xmotors_vendedor;

IF NOT EXISTS (SELECT 1 FROM sys.database_principals AS r WHERE r.name = 'rol_xmotors_consulta'
               AND EXISTS (SELECT 1 FROM sys.database_role_members m WHERE m.role_principal_id = r.principal_id AND m.member_principal_id = USER_ID('usr_xmotors_consulta')))
    ALTER ROLE rol_xmotors_consulta ADD MEMBER usr_xmotors_consulta;
GO

-- ============================================================================
-- 3. Permisos de rol_xmotors_admin: administracion completa del esquema
-- ============================================================================
GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::dbo TO rol_xmotors_admin;
GRANT EXECUTE ON SCHEMA::dbo TO rol_xmotors_admin;
GO

-- ============================================================================
-- 4. Permisos de rol_xmotors_vendedor: operar ventas y consultar contexto
-- ============================================================================
GRANT SELECT ON OBJECT::dbo.persona              TO rol_xmotors_vendedor;
GRANT SELECT ON OBJECT::dbo.cliente              TO rol_xmotors_vendedor;
GRANT SELECT ON OBJECT::dbo.vendedor             TO rol_xmotors_vendedor;
GRANT SELECT ON OBJECT::dbo.direccion_cliente    TO rol_xmotors_vendedor;
GRANT SELECT ON OBJECT::dbo.modelo_motocicleta   TO rol_xmotors_vendedor;
GRANT SELECT ON OBJECT::dbo.motocicleta          TO rol_xmotors_vendedor;
GRANT SELECT ON OBJECT::dbo.accesorio            TO rol_xmotors_vendedor;
GRANT SELECT ON OBJECT::dbo.venta                TO rol_xmotors_vendedor;
GRANT SELECT ON OBJECT::dbo.detalle_venta_accesorio TO rol_xmotors_vendedor;
GRANT SELECT ON OBJECT::dbo.cotizacion           TO rol_xmotors_vendedor;

GRANT EXECUTE ON OBJECT::dbo.sp_registrar_venta  TO rol_xmotors_vendedor;
GRANT EXECUTE ON OBJECT::dbo.sp_cambiar_estado_venta TO rol_xmotors_vendedor;
GRANT EXECUTE ON OBJECT::dbo.sp_reporte_ventas_periodo TO rol_xmotors_vendedor;

-- Nada de DML directo: las escrituras pasan por los procedimientos.
DENY INSERT, UPDATE, DELETE ON SCHEMA::dbo TO rol_xmotors_vendedor;
GO

-- ============================================================================
-- 5. Permisos de rol_xmotors_consulta: lectura de negocio, sin auditoria
-- ============================================================================
GRANT SELECT ON SCHEMA::dbo TO rol_xmotors_consulta;

-- Tampoco ve el nivel tecnico interno.
DENY SELECT ON OBJECT::dbo.historial_de_precio TO rol_xmotors_consulta;
DENY SELECT ON OBJECT::dbo.auditoria_venta     TO rol_xmotors_consulta;
DENY SELECT ON OBJECT::dbo.auditoria_cliente   TO rol_xmotors_consulta;

-- No opera ventas ni precios.
DENY EXECUTE ON OBJECT::dbo.sp_registrar_venta         TO rol_xmotors_consulta;
DENY EXECUTE ON OBJECT::dbo.sp_cambiar_estado_venta    TO rol_xmotors_consulta;
DENY EXECUTE ON OBJECT::dbo.sp_actualizar_precio_modelo TO rol_xmotors_consulta;
GO

PRINT '03_seguridad.sql ejecutado: roles, usuarios y permisos creados.';
GO
