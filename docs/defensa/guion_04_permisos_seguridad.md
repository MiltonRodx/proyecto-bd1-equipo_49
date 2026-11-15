# Guion 4 — Permisos y seguridad (3 min)

## Guion hablado

> "El tema es **mínimo privilegio**: cada usuario tiene justo los permisos que necesita para su función, ni uno más.
>
> Los tres conceptos base: un **login** es la identidad a nivel servidor (sirve para conectarse); un **user** es la identidad dentro de una base; y un **rol** es un grupo de permisos — los permisos se le dan al rol y los usuarios los heredan al ser miembros. Así administro por función, no por persona. Y la regla de oro de precedencia: `DENY` gana siempre sobre `GRANT`.
>
> En X Motors creamos tres roles: admin (lectoescritura y `EXECUTE` sobre todo el esquema), vendedor (puede leer, pero escribir **solo a través de los procedimientos**), y consulta (solo lectura, y le negamos la auditoría y el historial de precios, que son datos sensibles).
>
> [Ejecutar demo_04] Con `EXECUTE AS USER` me convierto en cada usuario sin cerrar la conexión. Como consultor: puedo contar ventas, pero leer `auditoria_venta` me da error 229 — permiso denegado por el `DENY` — y tampoco puedo ejecutar el SP de ventas. Como vendedor: el `INSERT` directo en `venta` me lo rechaza con 229, pero `EXEC sp_cambiar_estado_venta` funciona — el permiso de ejecución pasa, y el negocio rechaza con 50012 porque la venta -1 no existe. Ese es el punto clave: el vendedor **no puede** escribir tablas a mano, solo por los procedimientos donde están las reglas."

## Líneas clave a señalar (abrir en pestañas)

| Archivo | Líneas | Qué mostrar |
|---|---|---|
| `docs/etapa-05/04-seguridad/01_seguridad.sql` | 35-37 | Creación de los 3 roles |
| `docs/etapa-05/04-seguridad/01_seguridad.sql` | 84-90 | Vendedor: `GRANT EXECUTE` a los SPs + `DENY INSERT/UPDATE/DELETE ON SCHEMA::dbo` |
| `docs/etapa-05/04-seguridad/01_seguridad.sql` | 98-108 | Consulta: `GRANT SELECT ON SCHEMA::dbo` + `DENY` a auditoría/historial |
| `docs/etapa-05/04-seguridad/02_seguridad_logins_reales.sql` | 123-133 | `CREATE LOGIN` + `CREATE USER`: login servidor, user base |

## Preguntas probables del profesor

1. **¿Login vs usuario?** → Login: identidad de servidor (conectarse). User: identidad dentro de una base, mapeado a un login. Nuestros usuarios de prueba permanentes son `WITHOUT LOGIN`: existen solo adentro de la base, para probar con `EXECUTE AS`.
2. **¿Qué pasa con GRANT + DENY a la vez?** → Gana DENY. Un DENY bloquea incluso un GRANT heredado por otro rol.
3. **¿Cómo puede el vendedor escribir si tiene DENY?** → *Ownership chaining*: el SP y las tablas son del dueño `dbo`, así que dentro del SP no se revisan permisos de las tablas. Fuera del SP, el DENY lo bloquea.
4. **¿Qué es el error 229?** → `INSERT/SELECT permission denied` — el mensaje típico de permiso denegado.
5. **¿Qué hace `EXECUTE AS USER`?** → Me suplanta como otro usuario dentro de mi conexión; `REVERT` vuelve a mi identidad.
6. **¿Por qué roles y no permisos por persona?** → Si entra un vendedor nuevo, lo agrego al rol y listo; no reconfiguro 10 permisos.

## Glosario mínimo

- **LOGIN / USER / ROLE:** identidad de servidor / identidad en la base / grupo de permisos.
- **GRANT:** dar permiso. **DENY:** prohibir (siempre gana). Sin GRANT explícito no hay acceso.
- **Ownership chaining:** los permisos de las tablas no se revisan dentro de un SP del mismo dueño.
- **`EXECUTE AS USER` / `REVERT`:** suplantar a un usuario de la base / volver a mi identidad.
- **`HAS_PERMS_BY_NAME(...)`:** función que consulta si el usuario actual tiene un permiso.
- **Mínimo privilegio:** dar solo los permisos necesarios para la función.
