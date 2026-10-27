# Resultados — Tema 1: Procedimientos y funciones almacenadas

**Sistema:** X Motors · Base de Datos I · Grupo 49 · FaCENA (UNNE)
**Base de datos:** `[X MOTORS]`
**Motor:** SQL Server 2025 Express (compatible con SQL Server Express 2016 SP1 o superior)
**Fecha de ejecución:** 2026-10-27
**Usuario:** `dbo`

Archivos de evidencia:

- `01_funciones_salida.txt` — salida cruda de `sqlcmd` para las funciones.
- `02_procedimientos_salida.txt` — salida cruda de `sqlcmd` para los procedimientos.
- `01_funciones_pruebas.sql` y `02_procedimientos_pruebas.sql` — scripts reproducibles.

---

## 1. Funciones

### 1.1 `fn_precio_con_descuento`

| Entrada | Resultado |
|---|---|
| `8.500.000,00` con 10 % | `7.650.000,00` |
| `8.500.000,00` con 5 % | `8.075.000,00` |
| `8.500.000,00` con 0 % | `8.500.000,00` |
| Precio `-1,00` | `NULL` |
| Porcentaje `101` | `NULL` |

### 1.2 `fn_descuento_cliente`

| Cliente | Ventas efectuadas | Monto acumulado | Descuento |
|---|---|---|---|
| `35123903` | 2 | `$24.945.950,00` | **10,00 %** |
| `30456781` | 2 | `$7.015.000,00` | **5,00 %** |
| `28345672` | 1 | `$2.811.750,00` | **0,00 %** |
| `99999999` (inexistente) | — | — | `NULL` |

> Solo suman las ventas en estado `efectuada`. Las ventas `cancelada` y `reembolsada` no cuentan.

### 1.3 `fn_resumen_cliente`

| Cliente | Cantidad de ventas | Monto acumulado | Descuento |
|---|---|---|---|
| `35123903` | 2 | `$24.945.950,00` | `10,00` |
| `30456781` | 2 | `$7.015.000,00` | `5,00` |
| `28345672` | 1 | `$2.811.750,00` | `0,00` |

### 1.4 `fn_total_accesorios_venta` y `fn_total_venta`

| Consulta | Resultado |
|---|---|
| `fn_total_accesorios_venta(1)` | `$227.000,00` (accesorios 1 y 3) |
| `fn_total_accesorios_venta(10)` | `$0,00` (venta sin detalle) |
| `fn_total_accesorios_venta(9999)` | `NULL` (venta inexistente) |
| `fn_total_venta(3.650.000, 1)` | `$3.877.000,00` |
| `fn_total_venta(3.650.000, 9999)` | `NULL` |

### 1.5 `fn_stock_disponible_modelo`

| Modelo | Stock |
|---|---|
| `11` (CB500F) | `3` |
| `2` (XR 150L) | `0` |
| `9999` (inexistente) | `NULL` |

### 1.6 `fn_cotizacion_vigente`

| Cotización | Resultado |
|---|---|
| `1` (vencida) | `0` |
| `10` (vencida) | `0` |
| `9999` (inexistente) | `NULL` |
| Temporal con vencimiento a 7 días | `1` |

---

## 2. Procedimientos

### 2.1 `sp_actualizar_precio_modelo`

| Prueba | Resultado |
|---|---|
| Modelo 1: `$3.850.000 → $3.950.000` | Actualizado |
| Restauración a `$3.850.000` | Restaurado |
| Modelo `9999` | Error `50017` — Modelo inexistente |
| Precio `-1` | Error `50016` — Precio de modelo invalido |

### 2.2 `sp_reporte_ventas_periodo`

Reporte de ventas efectuadas del 2026 agrupado por vendedor. Ejemplo de filas devueltas:

| DNI vendedor | Vendedor | Cantidad | Monto total | Ticket promedio |
|---|---|---|---|---|
| `43567890` | Irina Balenzuela | 1 | `$15.725.000,00` | `$15.725.000,00` |
| `36546710` | Micaela Cabrera | 1 | `$14.077.750,00` | `$14.077.750,00` |
| `34567890` | Julieta Ramirez | 1 | `$10.868.200,00` | `$10.868.200,00` |
| `29876543` | Carlos Medina | 2 | `$7.867.750,00` | `$3.933.875,00` |

Rango inválido (`desde > hasta`): error `50015` — Rango de fechas invalido.

### 2.3 `sp_registrar_venta` — venta demo con 10 % de descuento

**Datos de entrada:**

```text
Cliente:      35123903 (2 ventas efectuadas, $24.945.950 → 10 %)
Vendedor:     31222333
Chasis:       HONCB500F003 (modelo 11, CB500F, precio lista $8.500.000)
Método pago:  transferencia (se normaliza a "transferencia bancaria")
Accesorios:   1 × Casco integral ABS ($185.000) + 1 × Guantes de cuero ($42.000)
```

**Resultado:**

| Campo | Valor |
|---|---|
| `cod_venta` generado | `67` |
| `precio_venta_moto` | `$7.650.000,00` |
| Total accesorios | `$227.000,00` |
| `monto_total` | `$7.877.000,00` |
| `estado` | `efectuada` |
| `metodo_pago` | `transferencia bancaria` |
| Stock modelo 11 | `3 → 2` |
| Stock accesorio 1 | `11 → 10` |
| Stock accesorio 3 | `18 → 17` |
| Estado del cliente | `comprador` |
| Control de factura Etapa IV | **`OK`** |

La verificación de factura reproduce la lógica de `sql/consultas/01_factura.sql`:

```text
precio_venta_moto + total_accesorios = monto_total
7.650.000,00       + 227.000,00      = 7.877.000,00   → OK
```

### 2.4 `sp_cambiar_estado_venta` — cancelación y reintegro

| Acción | Resultado |
|---|---|
| Cancelar la venta `67` | `estado = cancelada` |
| Stock modelo 11 | `2 → 3` |
| Stock accesorio 1 | `10 → 11` |
| Stock accesorio 3 | `17 → 18` |
| Segunda cancelación (`reembolsada`) | Error `50013` — Transicion de estado invalida |
| Stock tras el error | Sin cambios (`3`, `11`, `18`) |

La venta demo se eliminó al final (detalle + cabecera) para dejar el lote de Etapa III como estaba. El stock ya había sido reintegrado por la cancelación.

### 2.5 Casos negativos de `sp_registrar_venta`

| Caso | Error esperado | Resultado |
|---|---|---|
| Chasis `HONCB500F001` ya vendido | `50005` | Error `50005` — El chasis ya tiene una venta efectuada |
| Modelo 2 sin stock (chasis `9C2HON00000000003`) | `50004` | Error `50004` — Sin stock disponible de la moto |
| Accesorio 1 con cantidad `9999` | `50008` | Error `50008` — Sin stock suficiente de accesorio |

En los tres casos el procedimiento revierte la transacción y no deja venta, detalle ni descuento de stock. La prueba de accesorios sin stock se ejecutó con `HONCB500F002` para no compartir chasis con la demo de transacciones (`HONCB500F004`).

### 2.6 Regresiones de la revisión

| Caso | Resultado |
|---|---|
| `@metodo_pago = NULL` | Error `50011` — Metodo de pago invalido |
| Accesorio con `precio_pactado = -1` | Error `50018` — Precio de accesorio invalido |
| Cliente con 10 % de descuento y `@porcentaje_descuento = 11` | Error `50009` — Porcentaje de descuento mayor al permitido |
| Venta sin `@porcentaje_descuento` (cliente `35123903`) | Descuento automático del 10 %: `precio_venta_moto = monto_total = $7.650.000,00` |
| Venta con `ANSI_WARNINGS OFF`, `CONCAT_NULL_YIELDS_NULL OFF` y `NUMERIC_ROUNDABORT ON` | `VENTA OK CON OPCIONES HOSTILES`; la venta se canceló y se eliminó al final |
| Cancelación con las mismas opciones hostiles | `CANCEL OK CON OPCIONES HOSTILES`; stock restaurado |

Las opciones SET hostiles se probaron porque el índice filtrado `ux_venta_chasis_vigente` exige `ANSI_WARNINGS`, `CONCAT_NULL_YIELDS_NULL` y `NUMERIC_ROUNDABORT` correctos. El procedimiento fija esas opciones y ejecuta el `INSERT`/`UPDATE` de `venta` mediante `sp_executesql`; así el lote hijo las hereda y no aparece el error `1934`.

---

## 3. Estado final de la base

| Verificación | Valor |
|---|---|
| Ventas nuevas sobre `HONCB500F003` / `HONCB500F002` | `0` |
| Stock modelo 11 | `3` |
| Stock accesorio 1 | `11` |
| Stock accesorio 3 | `18` |
| Precio modelo 1 | `$3.850.000,00` (restaurado) |
| Cliente `35123903` | `comprador` (sin cambios) |

---

## 4. Conclusión

- Las 7 funciones se crearon y devolvieron los valores esperados, incluidos los casos inválidos (`NULL`).
- Los 4 procedimientos se crearon y ejecutaron sin errores inesperados.
- La venta demo respetó la regla de oro: **el descuento se aplicó sobre `precio_venta_moto`**, no sobre `monto_total`.
- La factura de Etapa IV sigue devolviendo `OK`.
- Los casos negativos revirtieron la transacción y no dejaron datos parciales.
- Las regresiones de la revisión (método `NULL`, precio negativo, descuento excesivo y opciones SET hostiles) devolvieron los códigos controlados o completaron la venta sin `1934`.
- La cancelación reintegró el stock una sola vez; la doble cancelación fue rechazada.
