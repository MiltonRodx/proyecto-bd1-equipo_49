# Resultados — Tema 4: Seguridad (permisos de usuarios y roles)

**Sistema de Gestión de Ventas de Motos — "X Motors"** · Base de Datos I · Grupo 49 · FaCENA (UNNE) · Etapa V

Entorno: **SQL Server 2025 Express** bajo Docker (contenedor `sqlserver`), base `[X MOTORS]`.

---

## 1. Enfoque permanente: roles + usuarios `WITHOUT LOGIN`

Resumen de la demostración de [`01_seguridad.sql`](../01_seguridad.sql):

- Trazabilidad completa fila por fila: [`01_seguridad_salida.txt`](01_seguridad_salida.txt) (script reproducible: [`01_seguridad_pruebas.sql`](01_seguridad_pruebas.sql), corrido con `EXECUTE AS USER` + `REVERT`).

| Prueba | Usuario | Resultado |
|---|---|---|
| DML directo (INSERT/UPDATE/DELETE sobre tablas de negocio) | vendedor | **Negado** (229) |
| SELECT sobre `auditoria_venta` | vendedor | **Negado** (229) |
| `EXEC sp_reporte_ventas_periodo` | vendedor | OK (ownership chaining) |
| SELECT de negocio | consulta | OK |
| SELECT sobre `auditoria_venta` / `historial_de_precio` | consulta | **Negado** (229) |
| `EXEC sp_registrar_venta` | consulta | **Negado** (229) |
| SELECT + `EXEC` de administración | admin | OK |

Ninguna prueba dejó datos (el `EXEC` de admin se corre con `sp_actualizar_precio_modelo` al mismo precio, que evita el UPDATE si no hay cambios).

## 2. Enfoque de la consigna v2: logins reales efímeros

Resumen de la demostración de [`02_seguridad_logins_reales.sql`](../02_seguridad_logins_reales.sql) (logins `CREATE LOGIN` creados y dropeados por el mismo script):

- Trazabilidad completa: [`02_seguridad_logins_salida.txt`](02_seguridad_logins_salida.txt).

| Prueba | Usuario | Esperado (consigna v2) | Obtenido |
|---|---|---|---|
| `INSERT` directo en `venta` | admin (`db_owner`) | Correcto | ✅ Exitoso |
| `INSERT` directo en `venta` | lector | Acceso denegado | ✅ Error 229 |
| `EXEC` de SP con `INSERT` | lector | Correcto | ✅ Exitoso (ownership chaining) |
| `SELECT modelo_motocicleta` | con rol | Correcto | ✅ Exitoso |
| `SELECT modelo_motocicleta` | sin rol | Acceso denegado | ✅ Error 229 |

**Estado final verificado:** 0 logins/usuarios/rol/SP demo residuales; lote de Etapa III intacto (31 ventas); las filas de `auditoria_venta` generadas por el ciclo demo (`INSERT` via SP + `DELETE` de limpieza) se conservan como constancia.

## 3. Limitación conocida (documentada)

`sp_registrar_venta` ejecuta su `INSERT` vía `sp_executesql`: el ownership chaining no cruza lotes dinámicos, por lo que para proyectos reales se recomienda crearlo con `WITH EXECUTE AS OWNER`. La demo del profesor usa un SP simple (`sp_demo_insert_venta_simple`, sin SQL dinámico, espíritu del ejemplo de la consigna); ver §4 de [`investigacion.md`](../investigacion.md) para las dos opciones documentadas.
