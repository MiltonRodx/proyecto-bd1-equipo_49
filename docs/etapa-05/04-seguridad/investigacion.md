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

---

