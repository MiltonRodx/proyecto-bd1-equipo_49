# Evidencias — Transacciones (Etapa V, Tema 2)

**Proyecto:** X Motors — Base de Datos I — Grupo 49
**Base:** `[X MOTORS]`
**Motor:** SQL Server 2025 Express (17.0.1000.7)
**Cliente:** `sqlcmd` 17.0.1000.7
**Fecha de ejecución:** 2026-10-27 15:09:10
**Script:** [`../scripts.sql`](../scripts.sql)
**Salida completa:** [`salida_sqlcmd.txt`](salida_sqlcmd.txt)

---

## 1. Comando de ejecución

```powershell
sqlcmd -S ".\SQLEXPRESS" -E -C -I -d "X MOTORS" `
  -i "etapa_v\transacciones\scripts.sql" `
  -o "etapa_v\transacciones\evidencias\salida_sqlcmd.txt" `
  -W -s "|" -w 300 -r1 -f 65001
```

| Opción | Motivo |
|---|---|
| `-E` | Autenticación Windows |
| `-C` | Confiar en el certificado del servidor local |
| `-I` | Habilitar `QUOTED_IDENTIFIER` (obligatorio por el índice filtrado `ux_venta_chasis_vigente`) |
| `-d "X MOTORS"` | Base de datos del proyecto |
| `-i ...` | Script de entrada |
| `-o ...` | Archivo de evidencia |
| `-W` | Recortar espacios en blanco |
| `-s "\|"` | Separador de columnas |
| `-w 300` | Ancho de salida |
| `-r1` | Redirigir mensajes de error a la salida estándar |
| `-f 65001` | UTF-8 |

> No se usa `-b` a propósito: el demo 3 termina con un `THROW` intencional y el script debe continuar hasta la cancelación final. `sqlcmd` devuelve `exit=0`; el error 547 es esperado y está documentado.

---

## 2. Estado inicial (baseline)

| Métrica | Valor |
|---|---:|
| Ventas (`dbo.venta`) | 30 |
| Detalles (`dbo.detalle_venta_accesorio`) | 38 |
| Stock modelo 11 — Honda CB500F | 3 |
| Stock accesorio 1 — Casco integral ABS | 11 |
| Stock accesorio 2 — Casco abierto | 11 |
| Ventas del chasis `HONCB500F004` | 0 |

La limpieza inicial deja el escenario en este estado. El chasis `HONCB500F004` está libre en el lote de Etapa III.

---

## 3. Demo 1 — Venta correcta (`BEGIN TRAN` + `COMMIT`)

### Operaciones

1. `BEGIN TRANSACTION`.
2. Bloqueo del stock del modelo 11 con `UPDLOCK, HOLDLOCK`.
3. Inserción de la venta en `dbo.venta`.
4. Inserción del detalle del accesorio 1.
5. Descuento de stock: modelo 11 y accesorio 1.
6. `COMMIT TRANSACTION`.

### Resultado

| Campo | Valor |
|---|---|
| `cod_venta` | **52** |
| Fecha | 2026-10-27 |
| Método de pago | efectivo |
| `precio_venta_moto` | 8.500.000,00 |
| `monto_total` | 8.685.000,00 |
| Estado | `efectuada` |
| Chasis | `HONCB500F004` |
| Accesorio | 1 — cantidad 1 — 185.000,00 |

**Verificación posterior:**

| Métrica | Antes | Después |
|---|---:|---:|
| Ventas | 30 | **31** |
| Detalles | 38 | **39** |
| Stock modelo 11 | 3 | **2** |
| Stock accesorio 1 | 11 | **10** |
| Ventas del chasis demo | 0 | **1** |
| `XACT_STATE()` | — | **0** |
| `@@TRANCOUNT` | — | **0** |

**Salida real:**

```text
COMMIT OK. cod_venta = 52
Venta y detalle insertados; stock descontado.
momento|ventas|detalles|stock_modelo_11|stock_accesorio_1|ventas_chasis_demo
DESPUES DEMO 1|31|39|2|10|1
momento|xact_state|trancount
ESTADO TRAN POST DEMO 1|0|0
```

**Conclusión:** el `COMMIT` confirma la venta, el detalle y los descuentos de stock. La venta queda visible para las demás sesiones.

---

## 4. Demo 2 — Stock insuficiente (`BEGIN TRAN` + `ROLLBACK`)

### Operaciones

1. `BEGIN TRANSACTION`.
2. Inserción de una unidad ficticia `TEST-XR150-ETAPA-V` para el modelo 2 (XR 150L), que tiene `stock_disponible = 0`.
3. Inserción de la venta y del detalle del accesorio 2, como si se fuera a vender.
4. Lectura del stock del modelo 2 con `UPDLOCK, HOLDLOCK`.
5. Detección de stock 0: `THROW 50004`.
6. `ROLLBACK TRANSACTION` en el `CATCH`.

### Resultado

| Campo | Valor |
|---|---|
| Modelo | 2 — XR 150L |
| Stock del modelo | 0 |
| Chasis de prueba | `TEST-XR150-ETAPA-V` |
| Error | 50004 — `Sin stock disponible para el modelo 2 (XR 150L).` |
| `XACT_STATE()` en el `CATCH` | **1** (transacción confirmable) |
| `@@TRANCOUNT` en el `CATCH` | **1** |
| `XACT_STATE()` después del `ROLLBACK` | **0** |
| `@@TRANCOUNT` después del `ROLLBACK` | **0** |

**Verificación posterior (tomando como referencia el estado después del demo 1):**

| Métrica | Después demo 1 | Después demo 2 |
|---|---:|---:|
| Ventas | 31 | **31** |
| Detalles | 39 | **39** |
| Stock modelo 2 | 0 | **0** |
| Stock accesorio 1 | 10 | **10** |
| Stock accesorio 2 | 11 | **11** |
| Ventas `TEST-XR150-ETAPA-V` | 0 | **0** |
| Detalles `TEST-XR150-ETAPA-V` | 0 | **0** |
| Motos `TEST-XR150-ETAPA-V` | 0 | **0** |

**Salida real:**

```text
DEMO 2 - ERROR CONTROLADO|50004|Sin stock disponible para el modelo 2 (XR 150L).|1|1|0|0
momento|ventas|detalles|stock_modelo_2|stock_accesorio_1|stock_accesorio_2|ventas_test|detalles_test|motos_test
DESPUES DEMO 2|31|39|0|10|11|0|0|0
momento|xact_state|trancount
ESTADO TRAN POST DEMO 2|0|0
```

**Conclusión:** el `ROLLBACK` deshizo la venta, el detalle, la unidad ficticia y cualquier descuento. No quedaron filas parciales ni cambios de stock. La transacción era confirmable (`XACT_STATE = 1`) porque el error fue de negocio, lanzado con `THROW` y `XACT_ABORT OFF`.

---

## 5. Demo 3 — Error de integridad (`BEGIN TRAN` + `ROLLBACK` + `THROW`)

### Operaciones

1. `SET XACT_ABORT ON`.
2. `BEGIN TRANSACTION`.
3. Inserción de una venta con `dni_cliente = 99999999` (inexistente) y chasis `CHASIS-INVALIDO-ETAPA-V` (inexistente).
4. La FK `fk_venta_cliente` rechaza la operación con el error **547**.
5. En el `CATCH`: se captura `XACT_STATE()` y `@@TRANCOUNT`.
6. `ROLLBACK TRANSACTION`.
7. `THROW;` para relanzar el error original.

### Resultado

| Campo | Valor |
|---|---|
| Error | **547** — violación de `fk_venta_cliente` |
| Tabla/columna | `dbo.cliente.dni_cliente` |
| `XACT_STATE()` en el `CATCH` | **-1** (transacción no confirmable) |
| `@@TRANCOUNT` en el `CATCH` | **1** |
| `XACT_STATE()` después del `ROLLBACK` | **0** |
| `@@TRANCOUNT` después del `ROLLBACK` | **0** |

**Salida real:**

```text
DEMO 3 - ERROR DE INTEGRIDAD|547|The INSERT statement conflicted with the FOREIGN KEY constraint "fk_venta_cliente". The conflict occurred in database "X MOTORS", table "dbo.cliente", column 'dni_cliente'.|17|-1|1
DEMO 3 - DESPUES DEL ROLLBACK|0|0
Msg 547, Level 16, State 1, Server DESKTOP-DQ7DOJB\SQLEXPRESS, Line 17
The INSERT statement conflicted with the FOREIGN KEY constraint "fk_venta_cliente". The conflict occurred in database "X MOTORS", table "dbo.cliente", column 'dni_cliente'.
```

**Verificación posterior (después del `ROLLBACK` y del `THROW`):**

| Métrica | Valor |
|---|---:|
| Ventas | 31 |
| Detalles | 39 |
| Stock modelo 11 | 2 |
| Stock accesorio 1 | 10 |
| Stock accesorio 2 | 11 |
| Ventas con chasis `CHASIS-INVALIDO-ETAPA-V` | **0** |
| `XACT_STATE()` | **0** |
| `@@TRANCOUNT` | **0** |

**Conclusión:** la transacción quedó no confirmable (`-1`) por la violación de integridad con `XACT_ABORT ON`; el `ROLLBACK` la dejó limpia. No quedó ninguna venta inválida. El `THROW` final permite que el cliente vea el error original.

---

## 6. Cancelación de la venta commiteada

Para restaurar el stock se ejecutó una transacción de cancelación sobre la venta 52:

1. `UPDATE dbo.venta SET estado = 'cancelada'` (solo si estaba `efectuada`).
2. `+1` a `modelo_motocicleta.stock_disponible` del modelo 11.
3. `+1` a `accesorio.stock` del accesorio 1.
4. `COMMIT`.

### Resultado final

| Campo | Valor |
|---|---|
| `cod_venta` | 52 |
| Estado final | **cancelada** |
| `precio_venta_moto` | 8.500.000,00 |
| `monto_total` | 8.685.000,00 |
| Chasis | `HONCB500F004` |
| Stock modelo 11 | **3** (restaurado) |
| Stock accesorio 1 | **11** (restaurado) |
| Stock accesorio 2 | **11** (sin cambios) |
| Ventas totales | **31** |
| Detalles totales | **39** |
| `XACT_STATE()` | **0** |
| `@@TRANCOUNT` | **0** |

**Salida real:**

```text
Cancelacion OK. Venta 52 quedo en estado cancelada.
FINAL|31|39|3|11|11|1|0|0|0
ESTADO TRAN FINAL|0|0
```

---

## 7. Comparación baseline vs. final

| Métrica | Baseline | Final | Diferencia | Interpretación |
|---|---:|---:|---:|---|
| Ventas | 30 | 31 | **+1** | Queda la venta 52, ahora `cancelada` |
| Detalles | 38 | 39 | **+1** | Queda el detalle de la venta 52 |
| Stock modelo 11 | 3 | 3 | **0** | Restaurado por la cancelación |
| Stock accesorio 1 | 11 | 11 | **0** | Restaurado por la cancelación |
| Stock accesorio 2 | 11 | 11 | **0** | No se modificó |
| Ventas chasis demo | 0 | 1 | **+1** | Evidencia de la venta cancelada |
| Ventas inválidas | 0 | 0 | **0** | Demo 3 no dejó filas |
| Ventas stock insuficiente | 0 | 0 | **0** | Demo 2 no dejó filas |
| Motos ficticias | 0 | 0 | **0** | Demo 2 no dejó filas |

**Chequeos automáticos del script:**

```text
venta_demo_cancelada|stock_modelo_restaurado|stock_accesorio_1_restaurado|stock_accesorio_2_restaurado|sin_venta_stock_insuficiente|sin_detalle_stock_insuficiente|sin_venta_error_integridad
OK|OK|OK|OK|OK|OK|OK
```

---

## 8. Interpretación

1. **`COMMIT` confirma:** la venta 52, su detalle y los descuentos de stock quedaron registrados. Las consultas posteriores los ven.
2. **`ROLLBACK` revierte:** los demos 2 y 3 no dejaron ventas, detalles, motos ficticias ni descuentos de stock. Los conteos se mantuvieron en 31 ventas / 39 detalles, que era el estado posterior al demo 1.
3. **El único cambio permanente es la venta cancelada:** la venta 52 y su detalle quedan como evidencia; el stock se restauró a 3 / 11 / 11. No se borra la venta para poder auditar la operación.
4. **`XACT_STATE()` distingue los casos:** el error de negocio del demo 2 deja la transacción confirmable (`1`); la violación de FK del demo 3 con `XACT_ABORT ON` la deja no confirmable (`-1`). En ambos casos el `ROLLBACK` la limpia (`0`).
5. **El script es repetible:** la limpieza inicial elimina la venta demo anterior y la unidad ficticia, y restaura el stock si hubiera quedado una venta `efectuada`. Al inicio de una nueva ejecución el escenario vuelve al baseline 30 / 38 / 3 / 11 / 11; al finalizar, el script deja nuevamente 31 ventas / 39 detalles con la nueva venta cancelada y el stock restaurado.

---

## 9. Notas técnicas

- La tabla `dbo.venta` tiene el índice filtrado `ux_venta_chasis_vigente`. Por eso el script ejecuta `SET QUOTED_IDENTIFIER ON` y otras opciones requeridas, y `sqlcmd` se invoca con `-I`.
- El error 547 del demo 3 es **intencional**. `sqlcmd` sin `-b` continúa con el siguiente batch y permite llegar a la cancelación final. Si se ejecutara con `-b`, el proceso se detendría en el demo 3.
- El demo 2 usa una unidad ficticia para no chocar con el índice filtrado ni con las ventas reales del lote. La unidad se elimina con el `ROLLBACK`.
- No se modificaron `sql/ddl/`, `sql/dml/` ni `sql/consultas/`.
- La venta 52 queda `cancelada`; si se quiere dejar la base exactamente en el baseline, ejecutar la limpieza inicial del script o eliminar la venta 52 y su detalle después de tomar la evidencia.
