

-- Verificacion de 01_seguridad.sql
EXECUTE AS USER = 'usr_xmotors_vendedor';   -- repetir con admin y consulta
SELECT USER_NAME() AS usuario,
       HAS_PERMS_BY_NAME('dbo.venta',               'OBJECT', 'SELECT')  AS select_venta,
       HAS_PERMS_BY_NAME('dbo.venta',               'OBJECT', 'INSERT')  AS insert_venta,
       HAS_PERMS_BY_NAME('dbo.auditoria_venta',     'OBJECT', 'SELECT')  AS select_auditoria,
       HAS_PERMS_BY_NAME('dbo.sp_cambiar_estado_venta', 'OBJECT', 'EXECUTE') AS exec_cambiar_estado;
REVERT;