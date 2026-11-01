# Tema 4 — Seguridad: permisos de usuarios y roles

**Sistema de Gestión de Ventas de Motos — "X Motors"**
Base de Datos I · Grupo 49 · FaCENA (UNNE) · Etapa V

> Este tema es obligatorio en la consigna v2 (tema 4) y ahora vive en su propia carpeta, con los mismos 5 puntos de la consigna (definición, ventajas, implementación, caso concreto y demostración).

## 1. Definición y objetivo

El **modelo de seguridad** de una base define quién puede hacer qué. En SQL Server conviven dos niveles: **logins** (identidad en el servidor) y **usuarios** (identidad en una base); los **roles** agrupan usuarios y reciben permisos, para no asignar privilegios persona por persona. El principio rector es el de **mínimo privilegio**: cada rol solo puede hacer lo que su tarea exige.

En X Motors hay tres perfiles reales: el administrador del sistema, el vendedor de salón y una persona que consulta para responder llamados. Cada uno obtiene su rol, y ni el vendedor ni el consultor tocan los datos contables ni el nivel técnico interno.

## 2. Ventajas y aplicaciones

| Ventaja | Cómo se aplica en X Motors |
|---|---|
| Permisos por **rol**, no por persona | El equipo puede cambiar de personas sin re-vistar permisos |
| **Mínimo privilegio** | El vendedor vende; ni borra personas ni mira la auditoría |
| **Ownership chaining** | Los SP de `dbo` operan tablas de `dbo` sin dar permisos directos de escritura al vendedor |
| **Auditable** | `USER_NAME()` dentro de un `EXECUTE AS` es el autor real en las tablas de auditoría |
| Sin cuentas reales de prueba | Los usuarios son `WITHOUT LOGIN`: nadie puede loguearse con ellos |

## 3. Implementación en SQL Server Express

`01_seguridad.sql` crea roles, usuarios y permisos de forma idempotente (`IF NOT EXISTS` sobre `sys.database_principals`). Todo lo probado usa `EXECUTE AS USER` + `REVERT`, lo que no exige cuentas de servidor ni contraseñas.

```sql
CREATE ROLE rol_xmotors_vendedor;
CREATE USER usr_xmotors_vendedor WITHOUT LOGIN;
ALTER ROLE rol_xmotors_vendedor ADD MEMBER usr_xmotors_vendedor;

GRANT SELECT ON OBJECT::dbo.modelo_motocicleta  TO rol_xmotors_vendedor;
GRANT EXECUTE ON OBJECT::dbo.sp_registrar_venta TO rol_xmotors_vendedor;
DENY  INSERT, UPDATE, DELETE ON SCHEMA::dbo     TO rol_xmotors_vendedor;

GRANT SELECT ON SCHEMA::dbo              TO rol_xmotors_consulta;
DENY  SELECT ON OBJECT::dbo.auditoria_venta TO rol_xmotors_consulta;
```

Los `DENY` **preceden** a los `GRANT` de esquema: sobre `dbo` el rol de consulta tiene lectura, pero el esquema interno técnico (auditoría e historial) le queda vetado. El `DENY` siempre gana sobre el `GRANT`.

## 4. Caso concreto aplicado al sistema de ventas

| Prueba | Rol | Resultado |
|---|---|---|
| `SELECT` de catálogo de modelos | vendedor | OK |
| `INSERT` directo en `venta` ("= registrar sin el SP") | vendedor | **Negado** (229) |
| `UPDATE` directo en `cliente` | vendedor | **Negado** (229) |
| `SELECT` sobre `auditoria_venta` | vendedor | **Negado** (229) |
| `EXEC sp_reporte_ventas_periodo` | vendedor | OK (ownership chaining) |
| `SELECT` de ventas | consulta | OK |
| `SELECT` sobre `auditoria_venta` / `historial_de_precio` | consulta | **Negado** (229) |
| `EXEC sp_registrar_venta` | consulta | **Negado** (229) |
| `SELECT` de todo + `EXEC` de administración | admin | OK |

Ninguna prueba dejó datos: el `EXEC` de admin se corrió con `sp_actualizar_precio_modelo` con el mismo precio (la lógica evita el UPDATE si no hay cambios) y el lote quedó intacto.

> **Observación honesta:** para que el vendedor ejecute `sp_registrar_venta` en producción (que internamente llama a `sp_executesql` con el `INSERT`), los SP con SQL dinámico deben crearse con `WITH EXECUTE AS OWNER`, ya que el ownership chaining no cruza batches dinámicos. En este lote se demuestra el `GRANT EXECUTE` y el `DENY` de DML directo; la combinación completa (vendedor ejecutando la venta real) se documenta pero no se fuerza en la demostración para no escribir datos bajo otro contexto de seguridad que después complicaría la limpieza del lote.

## 5. Script y resultados

- Script: [`01_seguridad.sql`](01_seguridad.sql)
- Pruebas reproducibles: [`evidencias/01_seguridad_pruebas.sql`](evidencias/01_seguridad_pruebas.sql)
- Salida completa con fecha y usuario: [`evidencias/01_seguridad_salida.txt`](evidencias/01_seguridad_salida.txt)

## 6. Demo complementaria: logins reales (tal como el ejemplo del profesor)

La consigna v2 arma su ejemplo con `CREATE LOGIN` (usuarios de servidor reales) y una tabla de 5 pruebas. Este enfoque complementa al script principal: los usuarios `WITHOUT LOGIN` de [`01_seguridad.sql`](01_seguridad.sql) son reproducibles sin permisos de `sysadmin`; el script [`02_seguridad_logins_reales.sql`](02_seguridad_logins_reales.sql) reproduce la demo del profesor con logins reales **efímeros** (se crean y se destruyen en el mismo script, contraseñas placeholder de demo nunca reales).

Resultados sobre la base `[X MOTORS]` (SQL Server 2025 Express, Docker), 5 de 5 con el resultado esperado:

| Prueba | Usuario | Resultado esperado (consigna v2) | Resultado obtenido |
|---|---|---|---|
| `INSERT` directo en `venta` | `usr_demo_xmotors_admin` (`db_owner`) | Correcto | ✅ Exitoso |
| `INSERT` directo en `venta` | `usr_demo_xmotors_lector` | Acceso denegado | ✅ Denegado, error 229 |
| `EXEC` de procedimiento con `INSERT` | `usr_demo_xmotors_lector` | Correcto | ✅ Exitoso (ownership chaining) |
| `SELECT` sobre `modelo_motocicleta` | usuario con rol `rol_demo_consulta_modelos` | Correcto | ✅ Exitoso |
| `SELECT` sobre `modelo_motocicleta` | usuario sin rol | Acceso denegado | ✅ Denegado, error 229 |

Notas técnicas documentadas en el propio script:

- Para la prueba de `EXEC` se usa un **SP simple espejo del ejemplo del profesor** (`sp_demo_insert_venta_simple`, `INSERT` directo sin SQL dinámico, creado y dropeado por la demo). El SP real `sp_registrar_venta` ejecuta su `INSERT` vía `sp_executesql` y el ownership chaining no cruza lotes dinámicos: es la limitación ya citada en la observación honesta de §4; la demo del profesor queda demostrada con el SP simple y el SP real se trataría con `WITH EXECUTE AS OWNER` (también comentado ahí).
- El `INSERT` directo del admin corre dentro de una transacción con `ROLLBACK` (convención de la etapa: no ensuciar el lote); el `INSERT` por SP de la prueba 3 sí se confirma y se **elimina en la limpieza del script**; las filas de `auditoria_venta` generadas por ese ciclo `INSERT`/`DELETE` quedan como constancia.
- Entorno con `SET QUOTED_IDENTIFIER ON` de encabezado: `venta` tiene el índice filtrado `ux_venta_chasis_vigente` y con las opciones por defecto de `sqlcmd` fallaría con error 1934.
- La limpieza final dropea usuarios, luego el rol (no puede dropearse con miembros), el SP, y los 4 logins; verificado: 0 principios residuales.

- Script: [`02_seguridad_logins_reales.sql`](02_seguridad_logins_reales.sql)
- Salida completa con fecha y usuario: [`evidencias/02_seguridad_logins_salida.txt`](evidencias/02_seguridad_logins_salida.txt)

---

