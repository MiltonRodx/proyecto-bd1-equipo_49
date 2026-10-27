# Tema 1 — Procedimientos y funciones almacenadas

**Sistema de Gestión de Ventas de Motos — "X Motors"**
Base de Datos I · Grupo 49 · FaCENA (UNNE) · Etapa V

---

## 1. Definición y objetivo

### 1.1 ¿Qué son?

Un **procedimiento almacenado** (*stored procedure*) es un programa SQL que se guarda dentro de la base de datos, recibe parámetros, ejecuta una o varias operaciones y puede devolver resultados, mensajes y valores de salida. Se invoca con `EXEC` y forma parte del esquema de la base.

Una **función almacenada** (*user-defined function*) es una rutina que recibe parámetros y devuelve un valor. En SQL Server hay dos formas principales:

- **Función escalar:** devuelve un único valor (por ejemplo, un precio con descuento).
- **Función con valores de tabla (TVF):** devuelve una tabla. Puede ser *inline* (una sola consulta) o *multi-statement* (varias instrucciones).

### 1.2 Objetivo en X Motors

El objetivo es **encapsular las reglas de negocio** que hoy se repiten en consultas y scripts, para que la base de datos sea más robusta y mantenible:

- Calcular el descuento de un cliente según su historial de compras.
- Calcular el precio de la moto con descuento.
- Sumar los accesorios de una venta y controlar que `monto_total` sea correcto.
- Verificar la vigencia de una cotización (7 días corridos).
- Consultar el stock disponible de un modelo.
- Registrar una venta completa de forma atómica.
- Cancelar o reembolsar una venta y reintegrar el stock una sola vez.
- Actualizar el precio de lista de un modelo de forma controlada.
- Generar un reporte de ventas por período y vendedor.

La idea central es que **la regla viva en un solo lugar** y que todos los usuarios y aplicaciones la ejecuten igual.

---

## 2. Ventajas y aplicaciones

### 2.1 Ventajas

| Ventaja | Cómo se aplica en X Motors |
|---|---|
| **Reutilización** | `fn_precio_con_descuento`, `fn_descuento_cliente` y `fn_total_venta` se usan en la venta y en los controles. La factura de Etapa IV es anterior y no invoca estas funciones. |
| **Mantenibilidad** | Si cambia un umbral de descuento, se modifica una función y no todas las consultas. |
| **Centralización de reglas** | La venta, el stock y el estado del cliente se resuelven en `sp_registrar_venta`, no en cada aplicación. |
| **Seguridad** | Un usuario puede recibir solo `EXECUTE` sobre el procedimiento, sin permisos directos sobre las tablas. |
| **Consistencia** | Todos los caminos de venta aplican la misma fórmula y los mismos controles. |
| **Rendimiento** | SQL Server reutiliza planes de ejecución y se reduce el tráfico de red al enviar una sola llamada. |
| **Auditoría y trazabilidad** | Los procedimientos son el punto único por el que pasan las operaciones importantes. |

### 2.2 Aplicaciones típicas

- **Cálculo de descuentos** por historial de compras.
- **Registro de ventas** con cabecera, detalle, stock y estado del cliente.
- **Cancelaciones y reembolsos** con reintegro de stock.
- **Actualización de precios** de catálogo.
- **Reportes parametrizados** por fecha y vendedor.
- **Validaciones de vigencia** de cotizaciones.
- **Consultas de stock** para atención al público.

### 2.3 Procedimiento vs. función

| Aspecto | Procedimiento | Función |
|---|---|---|
| Devuelve | Result sets, mensajes y parámetros `OUTPUT` | Un valor escalar o una tabla |
| ¿Puede modificar datos? | Sí (`INSERT`, `UPDATE`, `DELETE`) | No (solo lectura) |
| ¿Puede usar `TRY/CATCH`? | Sí | No |
| ¿Puede usar transacciones? | Sí | No |
| ¿Se usa en un `SELECT`? | No | Sí |
| Uso en X Motors | Ventas, cancelaciones, precios, reportes | Descuentos, totales, stock, vigencia |

---

## 3. Implementación en SQL Server Express

### 3.1 Requisitos y compatibilidad

- SQL Server **2016 SP1 o superior** para `CREATE OR ALTER`.
- Nivel de compatibilidad **130 o mayor** para `OPENJSON` (usado en `sp_registrar_venta`).
- Esquema `dbo.` explícito.
- `SET ANSI_NULLS ON` y `SET QUOTED_IDENTIFIER ON` al inicio de cada script.
- En los procedimientos que modifican `venta`, se fijan además `ANSI_PADDING`, `ANSI_WARNINGS`, `ARITHABORT`, `CONCAT_NULL_YIELDS_NULL` y `NUMERIC_ROUNDABORT` para el índice filtrado.
- Un objeto por lote, separado con `GO`; `CREATE OR ALTER` debe ser la primera instrucción del lote.

La validación se hizo sobre **SQL Server 2025 Express** en Docker. Todos los objetos usados son compatibles con **SQL Server Express 2022** y versiones anteriores con compatibilidad 130+.

### 3.2 Limitaciones de Express relevantes

| Limitación | Impacto en esta etapa |
|---|---|
| Base de datos de hasta 10 GB | No afecta el lote de prueba. |
| Hasta 1 GB de RAM y 4 núcleos | Suficiente para las pruebas; los índices se documentan en el anexo. |
| Sin SQL Agent | La auditoría se resuelve con triggers, no con tareas programadas. |
| Sin TDE | La seguridad se resuelve con roles y permisos, no con cifrado transparente. |
| Sin `OPENROWSET`/consultas distribuidas | No se usan. |

**Lo que sí soporta Express:** procedimientos, funciones escalares y TVF, `TRY/CATCH`, `THROW`, transacciones, `OUTPUT`, `OPENJSON`, triggers, roles y permisos.

### 3.3 Convenciones usadas

```sql
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION dbo.fn_precio_con_descuento (
    @precio_venta_moto DECIMAL(12,2),
    @porcentaje        DECIMAL(5,2)
) RETURNS DECIMAL(12,2)
AS
BEGIN
    IF @precio_venta_moto IS NULL OR @porcentaje IS NULL
        RETURN NULL;

    IF @precio_venta_moto < 0 OR @porcentaje < 0 OR @porcentaje > 100
        RETURN NULL;

    RETURN CAST(@precio_venta_moto * (1.0 - (@porcentaje / 100.0)) AS DECIMAL(12,2));
END;
GO
```

En los procedimientos:

```sql
SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRAN;
    -- operaciones
    COMMIT;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK;
    THROW;
END CATCH
```

### 3.4 Códigos de error de negocio

Se reserva el rango `50001`–`50099`. Los mensajes van sin tildes para evitar problemas de *encoding*.

| Código | Situación |
|---|---|
| `50001` | Cliente inexistente |
| `50002` | Vendedor inexistente |
| `50003` | Chasis inexistente |
| `50004` | Sin stock disponible de la moto |
| `50005` | El chasis ya tiene una venta `efectuada` |
| `50006` | Accesorio inexistente |
| `50007` | Cantidad de accesorio inválida |
| `50008` | Sin stock suficiente de accesorio |
| `50009` | Porcentaje de descuento inválido o mayor al permitido |
| `50010` | JSON de accesorios inválido o con IDs duplicados |
| `50011` | Método de pago inválido |
| `50012` | Venta inexistente |
| `50013` | Transición de estado inválida |
| `50014` | Estado destino inválido |
| `50015` | Rango de fechas inválido |
| `50016` | Precio de modelo inválido |
| `50017` | Modelo inexistente |
| `50018` | Precio de accesorio inválido |
| `50019` | Total o código de venta inconsistente |

---

## 4. Caso concreto aplicado al sistema de ventas

### 4.1 Funciones implementadas

Archivo: [`01_funciones.sql`](01_funciones.sql)

| Función | Tipo | Objetivo |
|---|---|---|
| `fn_precio_con_descuento` | Escalar | Aplica un porcentaje al precio de la moto. |
| `fn_total_accesorios_venta` | Escalar | Suma `cantidad * precio_pactado` de una venta. |
| `fn_total_venta` | Escalar | Calcula `precio_venta_moto + accesorios`. |
| `fn_cotizacion_vigente` | Escalar | Devuelve `1` si la cotización sigue vigente (RN12). |
| `fn_stock_disponible_modelo` | Escalar | Devuelve el stock de un modelo. |
| `fn_descuento_cliente` | Escalar | Devuelve 0 %, 5 % o 10 % según el historial. |
| `fn_resumen_cliente` | Inline TVF | Devuelve cantidad de compras, monto acumulado y descuento. |

**Regla de descuento:**

```text
monto acumulado en ventas 'efectuada' > $10.000.000  -> 10 %
monto acumulado en ventas 'efectuada' >  $5.000.000  ->  5 %
resto                                                ->  0 %
```

Las ventas `cancelada` y `reembolsada` no suman.

### 4.2 Procedimientos implementados

| Archivo | Procedimiento | Objetivo |
|---|---|---|
| [`02_procedimientos.sql`](02_procedimientos.sql) | `sp_actualizar_precio_modelo` | Actualiza el precio de lista de un modelo. |
| [`02_procedimientos.sql`](02_procedimientos.sql) | `sp_reporte_ventas_periodo` | Reporte de ventas efectuadas por vendedor. |
| [`../transacciones/01_sp_registrar_venta.sql`](../transacciones/01_sp_registrar_venta.sql) | `sp_registrar_venta` | Registra una venta completa de forma atómica. |
| [`../transacciones/02_sp_cambiar_estado_venta.sql`](../transacciones/02_sp_cambiar_estado_venta.sql) | `sp_cambiar_estado_venta` | Cancela o reembolsa una venta y reintegra stock. |

### 4.3 `sp_registrar_venta`: la operación central

Firma:

```sql
dbo.sp_registrar_venta
    @dni_cliente          INT,
    @dni_vendedor         INT,
    @numero_chasis        VARCHAR(100),
    @metodo_pago          VARCHAR(50),
    @porcentaje_descuento DECIMAL(5,2) = NULL,
    @accesorios_json      NVARCHAR(MAX) = NULL,
    @fecha                DATE = NULL,
    @cod_venta            INT OUTPUT
```

Pasos:

1. Valida cliente, vendedor, chasis, porcentaje y método de pago.
2. Normaliza el método de pago (`transferencia` → `transferencia bancaria`).
3. Si el porcentaje es `NULL`, toma el descuento por historial de `fn_descuento_cliente`; un valor explícito no puede superar ese máximo.
4. Parsea el JSON de accesorios con `OPENJSON` y rechaza precios negativos (`50018`).
5. Bloquea la moto, el modelo y los accesorios con `UPDLOCK, HOLDLOCK`, en orden ascendente de `id_accesorio`.
6. Verifica stock de la moto y de cada accesorio.
7. Verifica que el chasis no tenga otra venta `efectuada`.
8. Calcula `precio_venta_moto = fn_precio_con_descuento(precio_lista, porcentaje)`.
9. Calcula `monto_total = precio_venta_moto + accesorios` antes de insertar.
10. Inserta la cabecera con el total definitivo y el detalle con el precio pactado congelado.
11. Descuenta stock de la moto y de los accesorios; pasa al cliente a `comprador` (RN5).
12. Verifica `fn_total_venta(precio_venta_moto, cod_venta) = monto_total`; si no coincide, `50019`.
13. `COMMIT`; ante cualquier error, `ROLLBACK` y `THROW`.

**Opciones SET e índice filtrado:** el índice `ux_venta_chasis_vigente` exige `ANSI_WARNINGS`, `CONCAT_NULL_YIELDS_NULL` y `NUMERIC_ROUNDABORT` correctos. El procedimiento fija esas opciones y ejecuta el `INSERT` de `venta` con `sp_executesql`; el lote hijo hereda la configuración y evita el error `1934` aunque el llamador tenga opciones hostiles.

**Regla de oro:**

```text
CORRECTO:   precio_venta_moto = precio_lista * (1 - porcentaje / 100)
            monto_total       = precio_venta_moto + accesorios

INCORRECTO: monto_total = (precio_venta_moto + accesorios) * (1 - porcentaje / 100)
```

El descuento se aplica **solo** al precio de la moto. Así se mantiene la validación de `sql/consultas/01_factura.sql`:

```text
precio_venta_moto + total_accesorios = monto_total
```

### 4.4 `sp_cambiar_estado_venta`: cancelación y reintegro

Firma:

```sql
dbo.sp_cambiar_estado_venta
    @cod_venta    INT,
    @nuevo_estado VARCHAR(30)
```

Solo permite:

```text
efectuada -> cancelada
efectuada -> reembolsada
```

Reintegra el stock de la moto (`+1`) y de cada accesorio (`+cantidad`) una sola vez. Si la venta ya no está `efectuada`, lanza `50013` y no vuelve a sumar stock.

### 4.5 `sp_actualizar_precio_modelo` y `sp_reporte_ventas_periodo`

- `sp_actualizar_precio_modelo` valida modelo y precio, actualiza `precio_lista` y **no** inserta en `historial_de_precio`: de eso se encarga el trigger de la Ejecución 3.
- `sp_reporte_ventas_periodo` agrupa ventas `efectuada` por vendedor y devuelve `dni_vendedor`, `vendedor`, `cantidad_ventas`, `monto_total` y `ticket_promedio`.

### 4.6 Relación con las reglas de negocio

| Regla | Objeto de la Etapa V |
|---|---|
| RN5 — el cliente pasa a comprador | `sp_registrar_venta` |
| RN6 — precio congelado al vender | `sp_registrar_venta` + `fn_total_venta` |
| RN10 — venta sin accesorios | `sp_registrar_venta` (`@accesorios_json` nulo o `[]`) |
| RN11 — cancelación/reembolso reintegra stock | `sp_cambiar_estado_venta` |
| RN12 — cotización válida 7 días | `fn_cotizacion_vigente` |

---

## 5. Script de demostración y resultados obtenidos

### 5.1 Archivos

| Archivo | Contenido |
|---|---|
| [`01_funciones.sql`](01_funciones.sql) | Creación de las 7 funciones. |
| [`02_procedimientos.sql`](02_procedimientos.sql) | `sp_actualizar_precio_modelo` y `sp_reporte_ventas_periodo`. |
| [`../transacciones/01_sp_registrar_venta.sql`](../transacciones/01_sp_registrar_venta.sql) | `sp_registrar_venta`. |
| [`../transacciones/02_sp_cambiar_estado_venta.sql`](../transacciones/02_sp_cambiar_estado_venta.sql) | `sp_cambiar_estado_venta`. |
| [`evidencias/01_funciones_pruebas.sql`](evidencias/01_funciones_pruebas.sql) | Pruebas reproducibles de funciones. |
| [`evidencias/02_procedimientos_pruebas.sql`](evidencias/02_procedimientos_pruebas.sql) | Pruebas reproducibles de procedimientos. |
| [`evidencias/01_funciones_salida.txt`](evidencias/01_funciones_salida.txt) | Salida cruda de `sqlcmd`. |
| [`evidencias/02_procedimientos_salida.txt`](evidencias/02_procedimientos_salida.txt) | Salida cruda de `sqlcmd`. |
| [`evidencias/resultados.md`](evidencias/resultados.md) | Resumen legible de resultados. |

> **Equivalencia con los nombres de la consigna.** La consigna de la Ejecución 1 pedía `scripts.sql` y `evidencias/salida_sqlcmd.txt`. Para respetar el contrato de archivos ya commiteado en la Ejecución 0, el contenido se repartió así:
>
> - `scripts.sql` → [`01_funciones.sql`](01_funciones.sql) + [`02_procedimientos.sql`](02_procedimientos.sql) + [`../transacciones/01_sp_registrar_venta.sql`](../transacciones/01_sp_registrar_venta.sql) + [`../transacciones/02_sp_cambiar_estado_venta.sql`](../transacciones/02_sp_cambiar_estado_venta.sql).
> - `salida_sqlcmd.txt` → [`evidencias/01_funciones_salida.txt`](evidencias/01_funciones_salida.txt) + [`evidencias/02_procedimientos_salida.txt`](evidencias/02_procedimientos_salida.txt).
> - `DetalleAccesorioTipo` (TVP) → reemplazado por el parámetro `@accesorios_json` con `OPENJSON`, equivalente funcional y sin necesidad de crear un tipo en la base.

### 5.2 Resultados de las funciones

| Prueba | Resultado |
|---|---|
| `fn_precio_con_descuento(8.500.000, 10)` | `7.650.000,00` |
| `fn_precio_con_descuento(8.500.000, 5)` | `8.075.000,00` |
| `fn_precio_con_descuento(8.500.000, 0)` | `8.500.000,00` |
| `fn_precio_con_descuento(-1, 10)` | `NULL` |
| `fn_precio_con_descuento(8.500.000, 101)` | `NULL` |
| `fn_descuento_cliente(35123903)` | `10,00` |
| `fn_descuento_cliente(30456781)` | `5,00` |
| `fn_descuento_cliente(28345672)` | `0,00` |
| `fn_descuento_cliente(99999999)` | `NULL` |
| `fn_resumen_cliente(35123903)` | 2 ventas · `$24.945.950` · 10 % |
| `fn_total_accesorios_venta(1)` | `$227.000,00` |
| `fn_total_venta(3.650.000, 1)` | `$3.877.000,00` |
| `fn_stock_disponible_modelo(11)` | `3` |
| `fn_cotizacion_vigente(1)` | `0` (vencida) |
| `fn_cotizacion_vigente(9999)` | `NULL` |

### 5.3 Resultados de la venta demo

**Entrada:**

```text
Cliente:      35123903 (2 ventas efectuadas, $24.945.950 → 10 %)
Vendedor:     31222333
Chasis:       HONCB500F003 (modelo 11, CB500F, precio lista $8.500.000)
Método pago:  transferencia (normalizado a "transferencia bancaria")
Accesorios:   1 × Casco integral ABS ($185.000) + 1 × Guantes de cuero ($42.000)
```

**Salida:**

| Campo | Valor |
|---|---|
| `cod_venta` | `67` |
| `precio_venta_moto` | `$7.650.000,00` |
| Total accesorios | `$227.000,00` |
| `monto_total` | `$7.877.000,00` |
| `estado` | `efectuada` |
| Stock modelo 11 | `3 → 2` |
| Stock accesorio 1 | `11 → 10` |
| Stock accesorio 3 | `18 → 17` |
| Estado del cliente | `comprador` |
| Control de factura Etapa IV | **`OK`** |

### 5.4 Resultados de la cancelación

| Acción | Resultado |
|---|---|
| Cancelar la venta `67` | `estado = cancelada` |
| Stock modelo 11 | `2 → 3` |
| Stock accesorio 1 | `10 → 11` |
| Stock accesorio 3 | `17 → 18` |
| Segunda cancelación | Error `50013` |
| Stock tras el error | Sin cambios (`3`, `11`, `18`) |

La venta demo se eliminó al final para dejar el lote de Etapa III como estaba.

### 5.5 Casos negativos

| Caso | Error | Resultado |
|---|---|---|
| Chasis `HONCB500F001` ya vendido | `50005` | Rechazado, sin venta nueva |
| Modelo 2 sin stock | `50004` | Rechazado, sin venta nueva |
| Accesorio 1 con cantidad `9999` | `50008` | Rechazado, sin venta nueva |
| Método de pago `NULL` | `50011` | Rechazado, sin venta nueva |
| Accesorio con precio `-1` | `50018` | Rechazado, sin venta nueva |
| Descuento explícito mayor al permitido | `50009` | Rechazado, sin venta nueva |

En todos los casos la transacción se revirtió y no quedaron filas parciales. La prueba de accesorios sin stock usa `HONCB500F002` para no compartir chasis con la demo de transacciones (`HONCB500F004`).

### 5.6 Nota sobre los datos de prueba

El `README.md` de la Ejecución 0 asignaba al tema 1 el cliente `30456781` y el chasis `HONCB500F002`, esperando un descuento del 10 %. Al verificar los datos reales, `30456781` acumula `$7.015.000` en ventas `efectuada`, por lo que le corresponde **5 %**, no 10 %. Para demostrar el umbral del 10 % se usó el cliente `35123903` (2 ventas, `$24.945.950`) y el chasis `HONCB500F003`, tal como indica la consigna de la Ejecución 1. El cálculo de `$7.650.000` y `$7.877.000` es correcto para ese cliente. `HONCB500F002` quedó reservado para la prueba negativa de stock de accesorios.

### 5.7 Conclusión

La implementación cumple los cinco puntos de la consigna:

1. **Definición y objetivo:** procedimientos y funciones que encapsulan reglas de negocio.
2. **Ventajas y aplicaciones:** reutilización, mantenibilidad, seguridad y consistencia.
3. **Implementación en Express:** `CREATE OR ALTER`, `TRY/CATCH`, `THROW`, `OPENJSON`, `OUTPUT`, transacciones y bloqueos.
4. **Caso concreto:** venta, cancelación, descuentos, stock, cotizaciones y reportes de X Motors.
5. **Script y resultados:** scripts reproducibles y evidencias reales en `evidencias/`.

El descuento se aplicó sobre `precio_venta_moto`, la factura de Etapa IV sigue devolviendo `OK` y los casos negativos no dejaron datos parciales.

---

# Anexo A — Seguridad

> Los temas obligatorios (funciones, transacciones y triggers) van antes; este anexo incorpora el eje de seguridad (RNF1, RNF2, RNF3) con los mismos 5 puntos de la consigna.

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

`03_seguridad.sql` crea roles, usuarios y permisos de forma idempotente (`IF NOT EXISTS` sobre `sys.database_principals`). Todo lo probado usa `EXECUTE AS USER` + `REVERT`, lo que no exige cuentas de servidor ni contraseñas.

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

- Script: [`03_seguridad.sql`](03_seguridad.sql)
- Pruebas reproducibles: [`evidencias/03_seguridad_pruebas.sql`](evidencias/03_seguridad_pruebas.sql)
- Salida completa con fecha y usuario: [`evidencias/03_seguridad_salida.txt`](evidencias/03_seguridad_salida.txt)

---

# Anexo B — Índices

## 1. Definición y objetivo

Un **índice** es una estructura auxiliar (en SQL Server, un árbol B+) que mantiene copias ordenadas de pocas columnas con un puntero a la fila completa.Sirve para que las consultas que filtran/juntas/ordenan por esas columnas lleguen a los resultados por **seek** en lugar de escaner toda la tabla.

En X Motors el dataset actual ocupa 30–40 filas por tabla (1–9 páginas). A esa escala **ningún índice muestra su verdadero valor**: el objetivo es dejar creados y puestos los índices correctos para el tipo de consultas que la etapa III/IV acotó (reportes por fecha, ranking por vendedor, cotizaciones por vencimiento, evolución de precios), tal como se utilizarián si el lote creciera tres órdenes de magnitud.

## 2. Ventajas y aplicaciones

| Ventaja | Se refleja en |
|---|---|
| Menos lecturas en consultas filtradas | índice de entrada por rango de fechas en `venta` |
| Menos I/O con `INCLUDE` (covering) | no hay que ir a buscar la fila completa porque las columnas pedidas ya están en el índice |
| Mejores ordenamientos | `ORDER BY` alineado con la cola del índice (por ejemplo, `historial_de_precio` DESC) |
| Menos trabas para el optimizador | el estimador elige seek en lugar de escanear cuando sí conviene |

El costo se paga en escrituras: cada `INSERT`/`UPDATE` también actualiza todos los índices. Por eso el anexo crea solo 10 índices (los que cubren consultas reales) y no uno por columna.

## 3. Implementación en SQL Server Express

`04_indices.sql` crea los 10 índices declarados en el contrato (`etapa_v/README.md` §3.6), con guard `IF NOT EXISTS` sobre `sys.indexes`, columnas explícitas en la clave e `INCLUDE` para las columnas cubiertas.

```sql
CREATE INDEX ix_venta_fecha_estado
    ON dbo.venta (fecha, estado)
    INCLUDE (monto_total, dni_cliente, dni_vendedor);
```

Los nombres siguen la convención de la etapa (`ix_`), no llevan `WHERE` (salvo el índice filtrado `ux_venta_chasis_vigente` que ya existía) y son índices no agrupados, para no mover el clustering físico (que sostiene las FKs).

## 4. Caso concreto y medición ANTES/DESPUÉS

El anexo corrió `SET STATISTICS IO ON; SET STATISTICS TIME ON` sobre 5 consultas representativas (reporte por vendedor y período, historial por cliente, ranking de vendedor, accesorios más vendidos, stock físico, cotizaciones por vencimiento, proveedores por accesorio). Resultado honesto sobre el lote actual:

| Consulta | Tabla dominante | ANTES | DESPUÉS |
|---|---|---|---|
| Ranking de vendedores 2026 | `venta` | 2 páginas | 2 páginas |
| Historial de un cliente | `venta` | 2 páginas | 6 páginas |
| Ranking de un vendedor | `venta` | 2 páginas | 2 páginas |
| Accesorios más vendidos | `detalle_venta_accesorio` | 2 páginas | 2 páginas |
| Cotizaciones de un cliente | `cotizacion` | 2 páginas | 4 páginas |
| Cotizaciones vencidas | `cotizacion` | 2 páginas | 2 páginas |
| Historial de precios de un modelo | `historial_de_precio` | 2 páginas | 2 páginas |
| Stock físico por modelo (anti-join con `venta`) | `venta`/`motocicleta` | 9 + 2 | 9 + 2 |
| Proveedores por accesorio | `provision_accesorio` | 7 páginas | 6 páginas |

Es poca tabla: la lectura lógica se mide en unidades de página (cada tabla entera cabe en 2 páginas, en algunos casos hasta 6 con el monto de cabecera); el optimizador elige el plan barato y muchas veces sigue escaneando. Los `DMV` (`sys.dm_db_index_usage_stats`) confirman que **los índices se usan** cuando dan ventaja (por ejemplo `ix_cotizacion_cliente_vencimiento`, `ix_motocicleta_modelo`, `ix_provision_accesorio_accesorio` con `user_seeks = 1`, y `ix_detalle_venta_accesorio_accesorio` aparece como scan en la consulta de agregación), pero también que hay índices aún no elegidos por plan (por ejemplo los tres de `venta`) porque con 30 filas el escaneo del agrupado cuesta igual o menos. `sys.dm_db_missing_index_details` a la fecha no sugiere índices faltantes adicionales sobre las columnas del anexo.

**Conclusión honesta de la medición:** con el lote de prueba no se puede demostrar una mejora dramática; se demuestra que (a) los índices existen, (b) el optimizador los usa en varias consultas, y (c) la diferencia real aparecerá con órdenes de magnitud de más datos, que es cuando el scan del agrupado dejará de ser el plan más barato.

## 5. Script y resultados

- Script: [`04_indices.sql`](04_indices.sql)
- Consultas de medición: [`evidencias/04_indices_consultas.sql`](evidencias/04_indices_consultas.sql)
- Evidencia ANTES/DESPUÉS completa (incluye el `DROP` inicial, la corrida sin índices, la corrida con índices y las DMVs): [`evidencias/04_indices_antes_despues.txt`](evidencias/04_indices_antes_despues.txt)

Las 10 tablas quedan con sus índices y **ninguna consulta de Etapa IV cambió de comportamiento externo**: los resultados de las mismas son idénticos antes y después.
