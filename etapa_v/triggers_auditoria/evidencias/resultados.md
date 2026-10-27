# Resultados — Tema 3: Triggers de auditoría

**Sistema:** X Motors · Base de Datos I · Grupo 49 · FaCENA (UNNE)
**Base de datos:** `[X MOTORS]`
**Motor:** SQL Server 2025 Express
**Fecha de ejecución:** 2026-10-27
**Usuario:** `dbo`

Archivos de evidencia:

- `01_pruebas_triggers.sql` — script de pruebas reproducible.
- `salida_sqlcmd.txt` — salida completa de la corrida.
- `01_historial_precio.txt`, `02_auditoria_venta.txt`, `03_auditoria_cliente.txt` — extractos por trigger.

---

## 1. Objetos creados

| Objeto | Tipo | Tabla | Evento | Escribe en |
|---|---|---|---|---|
| `auditoria_venta` | Tabla | — | — | Registra INSERT/UPDATE/DELETE de `venta` |
| `auditoria_cliente` | Tabla | — | — | Registra cambios de estado de `cliente` |
| `trg_historial_precio_modelo` | Trigger `AFTER UPDATE` | `modelo_motocicleta` | `UPDATE` | `historial_de_precio` (RN7) |
| `trg_auditoria_venta` | Trigger `AFTER INSERT, UPDATE, DELETE` | `venta` | `INSERT/UPDATE/DELETE` | `auditoria_venta` |
| `trg_auditoria_cliente_estado` | Trigger `AFTER UPDATE` | `cliente` | `UPDATE` | `auditoria_cliente` |

Las tablas de auditoría no tienen claves foráneas: sobreviven al borrado del registro auditado. `usuario` y `fecha_hora` salen de los `DEFAULT` (`USER_NAME()`, `SYSDATETIME()`).

---

## 2. Prueba 1 — `trg_historial_precio_modelo`

| Acción | Resultado |
|---|---|
| `sp_actualizar_precio_modelo` modelo 1: `$3.850.000 → $3.950.000` | 1 fila nueva en `historial_de_precio` (id `37`, fecha `2026-10-27`) |
| Restauración: `$3.950.000 → $3.850.000` | 1 fila más (id `38`) |
| Total de filas | `36 → 38` |
| Precio final del modelo 1 | `$3.850.000,00` (restaurado) |

Nota: las filas `35`/`36` corresponden a una corrida previa de validación con la versión antigua de `sp_actualizar_precio_modelo`; son evidencia válida del mismo trigger. En la reconstrucción final de la base (Ejecución 5) el lote parte de cero.

---

## 3. Prueba 2 — `trg_auditoria_venta` (venta demo `cod_venta = 34`)

**Datos de entrada:** chasis `KAWZ400001` (modelo 14 Z400, precio lista `$10.500.000`), cliente `40234567`, vendedor `32109876`, accesorio 2 × 1 (Casco abierto, `$98.000`).

Resultado de la venta: `precio_venta_moto = $10.500.000`, `monto_total = $10.598.000`, `estado = efectuada`.

Registro de auditoría de la venta demo, en orden:

| id | Acción | Estado anterior | Estado nuevo | Monto anterior | Monto nuevo |
|---|---|---|---|---|---|
| 5 | `INSERT` | — | `efectuada` | — | `$10.598.000` |
| 6 | `UPDATE` | `efectuada` | `cancelada` | `$10.598.000` | `$10.598.000` |
| 7 | `DELETE` | `cancelada` | — | `$10.598.000` | — |

- La saneada correcta se registra una sola vez: el procedimiento calcula `monto_total` **antes** del `INSERT`, así el trigger no ve ninguna actualización intermedia.
- La cancelación por `sp_cambiar_estado_venta` registra el `UPDATE` de `efectuada → cancelada` con el monto invariante.
- La limpieza de la venta demo registra el `DELETE`.
- El stock quedó restaurado: modelo 14 = `2`, accesorio 2 = `11`.
- La venta demo se eliminó al final (detalle + cabecera); las filas de auditoría **no** se borran: son la evidencia.

---

## 4. Prueba 3 — `trg_auditoria_cliente_estado` (cliente `42111222`, Nicolás Duarte)

| Acción | Resultado en `auditoria_cliente` |
|---|---|
| `interesado → comprador` | 1 fila: estado anterior `interesado`, nuevo `comprador` |
| `UPDATE` que re-confirma el mismo estado | **0 filas nuevas** (el trigger no registra cambios nulos) |
| Restauración `comprador → interesado` | 1 fila más |

Total de la demo: 2 registros, y el cliente quedó con su estado original `interesado`.

---

## 5. Estado final de la base

| Verificación | Valor |
|---|---|
| `historial_de_precio` | 38 filas (34 del DML + 4 de la prueba) |
| `auditoria_venta` | 3 filas (todas de la venta demo `34`) |
| `auditoria_cliente` | 2 filas (todas del cliente `42111222`) |
| Stock modelo 14 | `2` (original) |
| Stock accesorio 2 | `11` (original) |
| Precio modelo 1 | `$3.850.000` (original) |
| Ventas nuevas en `KAWZ400001` | 0 (demo eliminada) |
| Triggers activos | `trg_historial_precio_modelo`, `trg_auditoria_venta`, `trg_auditoria_cliente_estado` |

---

## 6. Conclusión

- Los 3 triggers dispararon correctamente en `INSERT`, `UPDATE` y `DELETE`.
- Los triggers son set-based (`inserted`/`deleted`) y no modifican las tablas de negocio.
- El trigger de precios escribe en la tabla de negocio `historial_de_precio` (RN7); las tablas `auditoria_*` son solo evidencia técnica.
- Los `DEFAULT` de las tablas de auditoría resolvieron usuario y fecha sin código extra en los triggers.
- La prueba dejó el lote de Etapa III intacto y los datos de auditoría como constancia.
