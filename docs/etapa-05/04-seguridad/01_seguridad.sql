-- ============================================================================
-- ETAPA V - ANEXO A: SEGURIDAD (ROLES, USUARIOS Y PERMISOS)
-- Archivo: docs/etapa-05/04-seguridad/01_seguridad.sql
-- Sistema: X Motors - Base de Datos I - Grupo 49 - FaCENA (UNNE)
--
-- Modelo de minimo privilegio:
--   rol_xmotors_admin    -> DML y EXECUTE sobre todo el esquema dbo
--   rol_xmotors_vendedor -> opera ventas (via procedimientos) y consulta contexto
--   rol_xmotors_consulta -> solo lectura de negocio, sin auditoria ni historial
--
-- Idempotente: roles y usuarios se crean solo si no existen; GRANT/DENY y
-- ADD MEMBER se pueden repetir sin efecto.
-- Requiere que ya existan las tablas y los procedimientos que se referencian
-- (un GRANT/DENY sobre un objeto inexistente da error).
--
-- CONCEPTOS
--   LOGIN : identidad a nivel servidor, sirve para conectarse.
--   USER  : identidad dentro de UNA base de datos (puede mapear a un login).
--   ROLE  : grupo de permisos. Se dan permisos al rol, y los usuarios los
--           heredan al ser miembros. Asi se administra por funcion, no por persona.
--   Precedencia: DENY > GRANT > sin permiso. Sin GRANT explicito no hay acceso,
--   y un DENY gana siempre, incluso sobre un GRANT heredado de otro rol.
-- ============================================================================

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

USE [X MOTORS];
GO

-- ============================================================================
-- 1. Roles de base de datos
-- ============================================================================
IF DATABASE_PRINCIPAL_ID('rol_xmotors_admin')    IS NULL CREATE ROLE rol_xmotors_admin;
IF DATABASE_PRINCIPAL_ID('rol_xmotors_vendedor') IS NULL CREATE ROLE rol_xmotors_vendedor;
IF DATABASE_PRINCIPAL_ID('rol_xmotors_consulta') IS NULL CREATE ROLE rol_xmotors_consulta;
GO

-- ============================================================================
-- 2. Usuarios de prueba y membresias
-- WITHOUT LOGIN: el usuario existe solo dentro de la base, no puede conectarse.
-- Sirve para probar permisos con EXECUTE AS USER sin ser sysadmin.
-- (El script 02 los reemplaza por logins reales.)
-- ============================================================================
IF DATABASE_PRINCIPAL_ID('usr_xmotors_admin')    IS NULL CREATE USER usr_xmotors_admin    WITHOUT LOGIN;
IF DATABASE_PRINCIPAL_ID('usr_xmotors_vendedor') IS NULL CREATE USER usr_xmotors_vendedor WITHOUT LOGIN;
IF DATABASE_PRINCIPAL_ID('usr_xmotors_consulta') IS NULL CREATE USER usr_xmotors_consulta WITHOUT LOGIN;
GO

ALTER ROLE rol_xmotors_admin    ADD MEMBER usr_xmotors_admin;
ALTER ROLE rol_xmotors_vendedor ADD MEMBER usr_xmotors_vendedor;
ALTER ROLE rol_xmotors_consulta ADD MEMBER usr_xmotors_consulta;
GO

-- ============================================================================
-- 3. rol_xmotors_admin
-- Lectura y escritura de datos + ejecutar procedimientos, a nivel ESQUEMA:
-- cubre tambien las tablas que se creen en el futuro dentro de dbo.
-- Nota: no incluye DDL (CREATE/ALTER/DROP); eso requeriria ALTER sobre el esquema.
-- ============================================================================
GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::dbo TO rol_xmotors_admin;
GRANT EXECUTE                        ON SCHEMA::dbo TO rol_xmotors_admin;
GO

-- ============================================================================
-- 4. rol_xmotors_vendedor
-- Lee las tablas que necesita para atender, y escribe SOLO a traves de
-- procedimientos. Funciona por "ownership chaining": el SP y las tablas son de
-- dbo, asi que SQL Server no revisa permisos de las tablas dentro del SP (ni
-- siquiera el DENY de abajo). La cadena se corta si el SP usa SQL dinamico.
-- ============================================================================
GRANT SELECT ON OBJECT::dbo.persona                 TO rol_xmotors_vendedor;
GRANT SELECT ON OBJECT::dbo.cliente                 TO rol_xmotors_vendedor;
GRANT SELECT ON OBJECT::dbo.vendedor                TO rol_xmotors_vendedor;
GRANT SELECT ON OBJECT::dbo.direccion_cliente       TO rol_xmotors_vendedor;
GRANT SELECT ON OBJECT::dbo.modelo_motocicleta      TO rol_xmotors_vendedor;
GRANT SELECT ON OBJECT::dbo.motocicleta             TO rol_xmotors_vendedor;
GRANT SELECT ON OBJECT::dbo.accesorio               TO rol_xmotors_vendedor;
GRANT SELECT ON OBJECT::dbo.venta                   TO rol_xmotors_vendedor;
GRANT SELECT ON OBJECT::dbo.detalle_venta_accesorio TO rol_xmotors_vendedor;
GRANT SELECT ON OBJECT::dbo.cotizacion              TO rol_xmotors_vendedor;

GRANT EXECUTE ON OBJECT::dbo.sp_RegistrarVentaCompleta TO rol_xmotors_vendedor;
GRANT EXECUTE ON OBJECT::dbo.sp_cambiar_estado_venta   TO rol_xmotors_vendedor;
GRANT EXECUTE ON OBJECT::dbo.sp_reporte_ventas_periodo TO rol_xmotors_vendedor;

-- Cinturon y tirantes: sin este DENY igual no tendria DML (nunca se le dio),
-- pero asi un GRANT heredado de otro rol tampoco se lo habilita.
DENY INSERT, UPDATE, DELETE ON SCHEMA::dbo TO rol_xmotors_vendedor;
GO

-- ============================================================================
-- 5. rol_xmotors_consulta
-- Lectura de todo el esquema, menos las tablas tecnicas. Es una lista de
-- exclusion: una tabla tecnica nueva quedaria visible hasta que se agregue aca.
-- ============================================================================
GRANT SELECT ON SCHEMA::dbo TO rol_xmotors_consulta;

DENY SELECT ON OBJECT::dbo.historial_de_precio TO rol_xmotors_consulta;
DENY SELECT ON OBJECT::dbo.auditoria_venta     TO rol_xmotors_consulta;
DENY SELECT ON OBJECT::dbo.auditoria_cliente   TO rol_xmotors_consulta;

-- No opera. Estos DENY son redundantes (GRANT SELECT no da EXECUTE), pero
-- dejan explicito que no debe poder ejecutarlos.
DENY EXECUTE ON OBJECT::dbo.sp_RegistrarVentaCompleta   TO rol_xmotors_consulta;
DENY EXECUTE ON OBJECT::dbo.sp_cambiar_estado_venta     TO rol_xmotors_consulta;
DENY EXECUTE ON OBJECT::dbo.sp_actualizar_precio_modelo TO rol_xmotors_consulta;
GO

PRINT '01_seguridad.sql ejecutado: roles, usuarios y permisos creados.';
GO



EXECUTE AS USER = 'usr_xmotors_vendedor';   -- repetir con admin y consulta
SELECT USER_NAME() AS usuario,
       HAS_PERMS_BY_NAME('dbo.venta',               'OBJECT', 'SELECT')  AS select_venta,
       HAS_PERMS_BY_NAME('dbo.venta',               'OBJECT', 'INSERT')  AS insert_venta,
       HAS_PERMS_BY_NAME('dbo.auditoria_venta',     'OBJECT', 'SELECT')  AS select_auditoria,
       HAS_PERMS_BY_NAME('dbo.sp_cambiar_estado_venta', 'OBJECT', 'EXECUTE') AS exec_cambiar_estado;
REVERT;