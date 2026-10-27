# Etapa V — Temas técnicos

**Sistema de Gestión de Ventas de Motos — "X Motors"** · Base de Datos I · Grupo 49 · FaCENA (UNNE)

> Pregunta central: **¿Cómo hacemos robusta la base de datos?**
>
> Esta carpeta concentra los objetos de la Etapa V: procedimientos y funciones, transacciones, triggers de auditoría, seguridad e índices. **No se modifican** el DDL, el DML ni las consultas de las etapas I–IV.

---

## 1. Objetivo y alcance

| Tema | Objetivo | Reglas / requisitos |
|---|---|---|
| Procedimientos y funciones | Encapsular cálculos y operaciones repetitivas | RN6, RN10, RN12 |
| Transacciones | Registrar y anular ventas de forma atómica, con control de stock | RN1, RN2, RN11 |
| Triggers de auditoría | Registrar cambios de precio y de estado sin intervención del usuario | RN7, RN11 |
| Seguridad | Separar roles de administración, venta y consulta | RNF1, RNF2, RNF3 |
| Índices | Acelerar reportes y búsquedas por fecha, cliente, vendedor y catálogo | RNF de performance |

**Fuera de alcance:** crear la tabla `METODO_PAGO`, normalizar los valores históricos de `venta.metodo_pago` o modificar los scripts de etapas anteriores. `venta.metodo_pago` sigue siendo `VARCHAR(50)`; los procedimientos nuevos normalizan el valor recibido.

**Requisito técnico:** SQL Server 2016 SP1 o superior (`CREATE OR ALTER` y `OPENJSON`), con nivel de compatibilidad 130 o mayor.

---

## 2. Estructura y orden de ejecución

### 2.1 Estructura acordada

```text
etapa_v/
├── README.md
├── procedimientos_funciones/
│   ├── 01_funciones.sql                 # pendiente de implementación
│   ├── 02_procedimientos.sql            # pendiente de implementación
│   ├── 03_seguridad.sql                 # DDL de soporte: roles, usuarios y permisos
│   ├── 04_indices.sql                   # DDL de soporte: índices de performance
│   └── evidencias/
│       └── .gitkeep
├── transacciones/
│   ├── 01_sp_registrar_venta.sql        # pendiente de implementación
│   ├── 02_sp_cambiar_estado_venta.sql   # pendiente de implementación
│   ├── 03_pruebas_acid.sql              # evidencia de commit / rollback / concurrencia
│   └── evidencias/
│       └── .gitkeep
└── triggers_auditoria/
    ├── 01_tablas_auditoria.sql          # tablas nuevas de auditoría
    ├── 02_trg_historial_precio_modelo.sql
    ├── 03_trg_auditoria_venta.sql
    ├── 04_trg_auditoria_cliente_estado.sql
    └── evidencias/
        └── .gitkeep
```

> **Estado actual:** solo existen este `README.md` y los tres `.gitkeep`. Los archivos `.sql` se incorporan en las ejecuciones siguientes. Seguridad e índices se agrupan en `procedimientos_funciones/` para no ampliar la estructura de tres carpetas acordada; sus evidencias van en `procedimientos_funciones/evidencias/`.

### 2.2 Secuencia obligatoria

| # | Script | Qué hace | ¿Modifica datos? |
|---|---|---|---|
| 1 | `sql/ddl/DDL_Script_X_Motors.sql` | Crea la base `[X MOTORS]` y las 15 tablas base | No |
| 2 | `sql/dml/DML_Script_X_Motors.sql` | Puebla el lote de prueba | Sí (lote inicial) |
| 3 | `etapa_v/triggers_auditoria/01_tablas_auditoria.sql` | Crea `auditoria_venta` y `auditoria_cliente` | No |
| 4 | `etapa_v/procedimientos_funciones/01_funciones.sql` | Crea las funciones `fn_*` | No |
| 5 | `etapa_v/procedimientos_funciones/02_procedimientos.sql` | Crea `sp_actualizar_precio_modelo` y `sp_reporte_ventas_periodo` | No |
| 6 | `etapa_v/transacciones/01_sp_registrar_venta.sql` | Crea `sp_registrar_venta` | No |
| 7 | `etapa_v/transacciones/02_sp_cambiar_estado_venta.sql` | Crea `sp_cambiar_estado_venta` | No |
| 8 | `etapa_v/triggers_auditoria/02_trg_historial_precio_modelo.sql` | Crea el trigger de historial de precios | No |
| 9 | `etapa_v/triggers_auditoria/03_trg_auditoria_venta.sql` | Crea el trigger de auditoría de ventas | No |
| 10 | `etapa_v/triggers_auditoria/04_trg_auditoria_cliente_estado.sql` | Crea el trigger de auditoría de estados del cliente | No |
| 11 | `etapa_v/procedimientos_funciones/03_seguridad.sql` | Crea roles, usuarios y permisos | No |
| 12 | `etapa_v/procedimientos_funciones/04_indices.sql` | Crea los índices de performance | No |
| 13 | `etapa_v/**/evidencias/*_pruebas.sql` | Ejecuta las pruebas y genera evidencias | Sí, con `ROLLBACK` al final |

**Reglas de ejecución:**

1. Ejecutar siempre sobre una base recreada con el DDL y poblada con el DML. El DML asume tablas vacías.
2. Los scripts de Etapa V son idempotentes: `CREATE OR ALTER` para funciones, procedimientos y triggers; `IF OBJECT_ID(...) IS NULL` para tablas; `DROP INDEX ... IF EXISTS` + `CREATE INDEX` para índices.
3. Las pruebas de datos se ejecutan dentro de `BEGIN TRAN ... ROLLBACK` para no alterar el lote de Etapa III. Las capturas se toman **antes** del `ROLLBACK`.
4. Los triggers de auditoría se crean después de las tablas de auditoría y antes de ejecutar las pruebas.
5. La seguridad se aplica al final, cuando todos los objetos ya existen.
6. Los índices se crean después de cargar el DML, para medir el antes/después con datos reales.

---

## 3. Inventario de objetos y firmas exactas

### 3.1 Tablas de auditoría

Se crean en `etapa_v/triggers_auditoria/01_tablas_auditoria.sql`. No se agregan FK: la auditoría debe sobrevivir al borrado del registro auditado.

```sql
CREATE TABLE dbo.auditoria_venta (
    id_auditoria     INT IDENTITY(1,1) NOT NULL,
    cod_venta        INT NOT NULL,
    accion           VARCHAR(10) NOT NULL,
    estado_anterior  VARCHAR(30) NULL,
    estado_nuevo     VARCHAR(30) NULL,
    monto_anterior   DECIMAL(12,2) NULL,
    monto_nuevo      DECIMAL(12,2) NULL,
    usuario          VARCHAR(128) NOT NULL
        CONSTRAINT df_auditoria_venta_usuario DEFAULT USER_NAME(),
    fecha_hora       DATETIME2(0) NOT NULL
        CONSTRAINT df_auditoria_venta_fecha DEFAULT SYSDATETIME(),
    CONSTRAINT pk_auditoria_venta PRIMARY KEY (id_auditoria),
    CONSTRAINT ck_auditoria_venta_accion
        CHECK (accion IN ('INSERT', 'UPDATE', 'DELETE'))
);
```

```sql
CREATE TABLE dbo.auditoria_cliente (
    id_auditoria     INT IDENTITY(1,1) NOT NULL,
    dni_cliente      INT NOT NULL,
    estado_anterior  VARCHAR(100) NULL,
    estado_nuevo     VARCHAR(100) NULL,
    usuario          VARCHAR(128) NOT NULL
        CONSTRAINT df_auditoria_cliente_usuario DEFAULT USER_NAME(),
    fecha_hora       DATETIME2(0) NOT NULL
        CONSTRAINT df_auditoria_cliente_fecha DEFAULT SYSDATETIME(),
    CONSTRAINT pk_auditoria_cliente PRIMARY KEY (id_auditoria)
);
```

Índices de apoyo incluidos en el mismo script:

```sql
CREATE INDEX ix_auditoria_venta_cod_venta
    ON dbo.auditoria_venta (cod_venta, fecha_hora DESC);

CREATE INDEX ix_auditoria_cliente_dni
    ON dbo.auditoria_cliente (dni_cliente, fecha_hora DESC);
```

### 3.2 Funciones

Archivo: `etapa_v/procedimientos_funciones/01_funciones.sql`.

```sql
CREATE OR ALTER FUNCTION dbo.fn_precio_con_descuento (
    @precio_venta_moto DECIMAL(12,2),
    @porcentaje        DECIMAL(5,2)
) RETURNS DECIMAL(12,2)
```

- Devuelve el precio de la moto con el descuento aplicado.
- `@porcentaje` se expresa en puntos porcentuales: `10.00` = 10 %.
- Devuelve `NULL` si `@precio_venta_moto < 0` o `@porcentaje` no está entre `0` y `100`.
- **El descuento se aplica al precio de la moto, nunca al `monto_total`.**

```sql
CREATE OR ALTER FUNCTION dbo.fn_total_accesorios_venta (
    @cod_venta INT
) RETURNS DECIMAL(12,2)
```

- Suma `cantidad * precio_pactado` de `detalle_venta_accesorio`.
- Devuelve `0.00` si la venta no tiene accesorios.
- Devuelve `NULL` si `@cod_venta` no existe.

```sql
CREATE OR ALTER FUNCTION dbo.fn_total_venta (
    @precio_venta_moto DECIMAL(12,2),
    @cod_venta         INT
) RETURNS DECIMAL(12,2)
```

- Devuelve `@precio_venta_moto + fn_total_accesorios_venta(@cod_venta)`.
- Es la fórmula de control de `venta.monto_total` (RN11).

```sql
CREATE OR ALTER FUNCTION dbo.fn_cotizacion_vigente (
    @id_cotizacion INT
) RETURNS BIT
```

- Devuelve `1` si `CAST(GETDATE() AS DATE) <= fecha_vencimiento`.
- Devuelve `0` si está vencida.
- Devuelve `NULL` si la cotización no existe.
- Implementa RN12: validez de 7 días corridos contada desde `fecha_emision`.

```sql
CREATE OR ALTER FUNCTION dbo.fn_stock_disponible_modelo (
    @id_modelo INT
) RETURNS INT
```

- Devuelve `modelo_motocicleta.stock_disponible`.
- Devuelve `NULL` si el modelo no existe.
- No recalcula el stock: lee la columna mantenida por los procedimientos de venta/anulación.

### 3.3 Procedimientos

Archivo: `etapa_v/procedimientos_funciones/02_procedimientos.sql`.

```sql
CREATE OR ALTER PROCEDURE dbo.sp_actualizar_precio_modelo
    @id_modelo    INT,
    @nuevo_precio DECIMAL(12,2)
```

- Valida que el modelo exista y que `@nuevo_precio > 0`.
- Actualiza `modelo_motocicleta.precio_lista`.
- **No inserta en `historial_de_precio`**: de eso se encarga `trg_historial_precio_modelo`.
- Si el precio no cambia, no hace nada y devuelve un mensaje informativo.

```sql
CREATE OR ALTER PROCEDURE dbo.sp_reporte_ventas_periodo
    @fecha_desde DATE = NULL,
    @fecha_hasta DATE = NULL
```

- Reporte parametrizado de ventas **efectuadas**, agrupado por vendedor.
- `NULL` en cualquiera de los dos parámetros = sin límite por ese extremo.
- Valida `@fecha_desde <= @fecha_hasta` cuando ambos están informados.
- Columnas del result set: `dni_vendedor`, `vendedor`, `cantidad_ventas`, `monto_total`, `ticket_promedio`.

Archivo: `etapa_v/transacciones/01_sp_registrar_venta.sql`.

```sql
CREATE OR ALTER PROCEDURE dbo.sp_registrar_venta
    @dni_cliente          INT,
    @dni_vendedor         INT,
    @numero_chasis        VARCHAR(100),
    @metodo_pago          VARCHAR(50),
    @porcentaje_descuento DECIMAL(5,2) = 0,
    @accesorios_json      NVARCHAR(MAX) = NULL,
    @fecha                DATE = NULL,
    @cod_venta            INT OUTPUT
```

- Registra una venta completa: cabecera + detalle de accesorios + actualización de stock + estado del cliente.
- Es la operación transaccional principal de la Etapa V.
- `@accesorios_json` es un arreglo JSON; `NULL` o `'[]'` significa venta sin accesorios.
- `@fecha` por defecto es la fecha actual (`CAST(GETDATE() AS DATE)`).
- `@cod_venta` devuelve el `cod_venta` generado por `IDENTITY`.

Archivo: `etapa_v/transacciones/02_sp_cambiar_estado_venta.sql`.

```sql
CREATE OR ALTER PROCEDURE dbo.sp_cambiar_estado_venta
    @cod_venta    INT,
    @nuevo_estado VARCHAR(30)
```

- Solo permite la transición `efectuada → cancelada` o `efectuada → reembolsada`.
- No permite volver a `efectuada`, ni cancelar/reembolsar dos veces.
- Reintegra el stock de la moto y de todos los accesorios de la venta.
- El cambio de estado queda auditado por `trg_auditoria_venta`.
- No recibe `@motivo`: el esquema base no tiene columna para ese dato.

### 3.4 Triggers

Archivo: `etapa_v/triggers_auditoria/02_trg_historial_precio_modelo.sql`.

```sql
CREATE OR ALTER TRIGGER dbo.trg_historial_precio_modelo
ON dbo.modelo_motocicleta
AFTER UPDATE
```

- Se dispara solo cuando cambia `precio_lista`.
- Inserta en `historial_de_precio` el precio anterior, el nuevo, la fecha actual y el `id_modelo`.
- Soporta actualizaciones de varias filas en un mismo `UPDATE`.
- No modifica `modelo_motocicleta` (evita recursión).

Archivo: `etapa_v/triggers_auditoria/03_trg_auditoria_venta.sql`.

```sql
CREATE OR ALTER TRIGGER dbo.trg_auditoria_venta
ON dbo.venta
AFTER INSERT, UPDATE, DELETE
```

- Registra en `auditoria_venta` cada `INSERT`, `UPDATE` y `DELETE`.
- Guarda `cod_venta`, acción, estado anterior/nuevo y monto anterior/nuevo.
- Usa `inserted` y `deleted`; está preparado para operaciones multi-fila.
- No modifica `venta`.

Archivo: `etapa_v/triggers_auditoria/04_trg_auditoria_cliente_estado.sql`.

```sql
CREATE OR ALTER TRIGGER dbo.trg_auditoria_cliente_estado
ON dbo.cliente
AFTER UPDATE
```

- Se dispara solo cuando cambia `estado`.
- Registra en `auditoria_cliente` el DNI, estado anterior, estado nuevo, usuario y fecha/hora.
- Soporta actualizaciones multi-fila.

### 3.5 Seguridad

Archivo: `etapa_v/procedimientos_funciones/03_seguridad.sql`.

| Objeto | Tipo | Propósito |
|---|---|---|
| `rol_xmotors_admin` | Rol de base de datos | Administración completa del esquema |
| `rol_xmotors_vendedor` | Rol de base de datos | Operar ventas y consultar catálogo/clientes |
| `rol_xmotors_consulta` | Rol de base de datos | Solo lectura de negocio, sin auditoría ni historial |
| `usr_xmotors_admin` | Usuario sin login | Pruebas de permisos con `EXECUTE AS USER` |
| `usr_xmotors_vendedor` | Usuario sin login | Pruebas de permisos con `EXECUTE AS USER` |
| `usr_xmotors_consulta` | Usuario sin login | Pruebas de permisos con `EXECUTE AS USER` |

**Permisos acordados:**

```text
rol_xmotors_admin
  GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::dbo
  GRANT EXECUTE ON SCHEMA::dbo

rol_xmotors_vendedor
  GRANT SELECT ON OBJECT::dbo.persona
  GRANT SELECT ON OBJECT::dbo.cliente
  GRANT SELECT ON OBJECT::dbo.vendedor
  GRANT SELECT ON OBJECT::dbo.direccion_cliente
  GRANT SELECT ON OBJECT::dbo.modelo_motocicleta
  GRANT SELECT ON OBJECT::dbo.motocicleta
  GRANT SELECT ON OBJECT::dbo.accesorio
  GRANT SELECT ON OBJECT::dbo.venta
  GRANT SELECT ON OBJECT::dbo.detalle_venta_accesorio
  GRANT SELECT ON OBJECT::dbo.cotizacion
  GRANT EXECUTE ON OBJECT::dbo.sp_registrar_venta
  GRANT EXECUTE ON OBJECT::dbo.sp_cambiar_estado_venta
  GRANT EXECUTE ON OBJECT::dbo.sp_reporte_ventas_periodo

rol_xmotors_consulta
  GRANT SELECT ON SCHEMA::dbo
  DENY SELECT ON OBJECT::dbo.historial_de_precio
  DENY SELECT ON OBJECT::dbo.auditoria_venta
  DENY SELECT ON OBJECT::dbo.auditoria_cliente
  DENY EXECUTE ON OBJECT::dbo.sp_registrar_venta
  DENY EXECUTE ON OBJECT::dbo.sp_cambiar_estado_venta
  DENY EXECUTE ON OBJECT::dbo.sp_actualizar_precio_modelo
```

> Los usuarios son `WITHOUT LOGIN` para que el script sea reproducible sin permisos de `sysadmin` y para poder probar con `EXECUTE AS USER`. En producción se mapean a logins reales; el contrato de roles y permisos no cambia.

### 3.6 Índices

Archivo: `etapa_v/procedimientos_funciones/04_indices.sql`.

| Índice | Tabla | Claves | Include | Consulta que justifica |
|---|---|---|---|---|
| `ix_venta_fecha_estado` | `venta` | `(fecha, estado)` | `monto_total, dni_cliente, dni_vendedor` | Reportes por rango de fechas |
| `ix_venta_cliente_fecha` | `venta` | `(dni_cliente, fecha)` | `monto_total, estado` | Historial y clientes recurrentes |
| `ix_venta_vendedor_fecha` | `venta` | `(dni_vendedor, fecha)` | `monto_total, estado` | Ranking de vendedores |
| `ix_detalle_venta_accesorio_accesorio` | `detalle_venta_accesorio` | `(id_accesorio)` | `cod_venta, cantidad, precio_pactado` | Accesorios más vendidos |
| `ix_cotizacion_cliente_vencimiento` | `cotizacion` | `(dni_cliente, fecha_vencimiento)` | `precio_cotizado, id_modelo` | Cotizaciones por cliente |
| `ix_cotizacion_vencimiento` | `cotizacion` | `(fecha_vencimiento)` | `dni_cliente, id_modelo, precio_cotizado` | Cotizaciones vencidas |
| `ix_historial_precio_modelo_fecha` | `historial_de_precio` | `(id_modelo, fecha_modificacion DESC)` | `precio_anterior, precio_nuevo` | Evolución de precios |
| `ix_motocicleta_modelo` | `motocicleta` | `(id_modelo)` | `numero_motor` | Stock físico por modelo |
| `ix_provision_motocicleta_modelo` | `provision_motocicleta` | `(id_modelo)` | `cuit_proveedor` | Proveedores por modelo |
| `ix_provision_accesorio_accesorio` | `provision_accesorio` | `(id_accesorio)` | `cuit_proveedor` | Proveedores por accesorio |

Los índices de `auditoria_venta` y `auditoria_cliente` se crean junto con sus tablas en `01_tablas_auditoria.sql`.

---

## 4. Contratos de comportamiento

### 4.1 `sp_registrar_venta`

**Entrada JSON de accesorios:**

```json
[
  { "id_accesorio": 1, "cantidad": 1, "precio_pactado": 185000.00 }
]
```

- Si `precio_pactado` es `NULL` u omitido, se usa `accesorio.precio_lista` del momento.
- No se permiten `id_accesorio` duplicados en el mismo arreglo.
- `cantidad` debe ser `> 0`.
- Si el JSON es `NULL` o `[]`, la venta se registra sin accesorios.

**Métodos de pago canónicos** (el procedimiento aplica `LOWER(LTRIM(RTRIM(...)))` y mapea `transferencia` a `transferencia bancaria`; cualquier otro valor se rechaza con `50011`):

```text
efectivo
transferencia bancaria
tarjeta de credito
tarjeta de debito
financiamiento
```

**Fórmula de la venta:**

```text
precio_venta_moto = fn_precio_con_descuento(modelo_motocicleta.precio_lista, @porcentaje_descuento)
monto_total       = precio_venta_moto + fn_total_accesorios_venta(@cod_venta)
```

> El descuento se aplica **solo** al precio de la moto. No se aplica sobre los accesorios ni sobre `monto_total`. `venta.precio_venta_moto` guarda el precio final de la moto **ya con descuento**; el descuento se calcula sobre `modelo_motocicleta.precio_lista`.
>
> Ejemplo: moto de `8.500.000,00` con `10 %` y accesorio de `185.000,00`:
> `precio_venta_moto = 7.650.000,00` y `monto_total = 7.835.000,00`.
> **No** es `(8.500.000 + 185.000) * 0,90 = 7.816.500,00`.

**Pasos transaccionales:**

1. Validar cliente, vendedor, chasis y método de pago.
2. Leer el modelo y bloquear su fila de stock con `UPDLOCK, HOLDLOCK`.
3. Verificar que `stock_disponible >= 1` y que el chasis no tenga otra venta `efectuada`.
4. Calcular `precio_venta_moto` con el descuento.
5. Insertar `venta` con estado `efectuada` y `monto_total` provisorio igual al precio de la moto.
6. Insertar cada accesorio en `detalle_venta_accesorio`, validando y descontando stock.
7. Actualizar `modelo_motocicleta.stock_disponible = stock_disponible - 1`.
8. Actualizar `cliente.estado = 'comprador'` si corresponde.
9. Recalcular `venta.monto_total` con la suma de accesorios.
10. `COMMIT`; ante cualquier error, `ROLLBACK` y `THROW`.

**Bloqueos y concurrencia:**

- `SET XACT_ABORT ON` y `SET NOCOUNT ON`.
- Bloqueo pesimista de stock con `UPDLOCK, HOLDLOCK`.
- Orden de bloqueo: `modelo_motocicleta` → `motocicleta` → `accesorio` (por `id_accesorio`) → `venta` → `detalle_venta_accesorio` → `cliente`.
- Aislamiento: `READ COMMITTED` (el bloqueo explícito cubre la carrera por el stock).
- La venta de una moto y el descuento de stock ocurren en la misma transacción: no puede quedar una venta sin stock descontado.

### 4.2 `sp_cambiar_estado_venta`

**Transiciones permitidas:**

```text
efectuada → cancelada
efectuada → reembolsada
```

**Pasos transaccionales (mismo orden de bloqueo que `sp_registrar_venta`):**

1. Leer la venta y sus detalles sin bloqueo para obtener el chasis, el modelo y los accesorios.
2. Bloquear `modelo_motocicleta` → `motocicleta` → `accesorio` (por `id_accesorio`), en ese orden.
3. Bloquear la venta con `UPDLOCK, HOLDLOCK` y revalidar que siga en estado `efectuada`.
4. Actualizar `venta.estado` al nuevo estado.
5. Reintegrar `+1` a `modelo_motocicleta.stock_disponible` de la moto vendida.
6. Reintegrar a `accesorio.stock` la cantidad de cada línea de `detalle_venta_accesorio`.
7. `COMMIT`; ante cualquier error, `ROLLBACK` y `THROW`.

**Garantías:**

- El reintegro se hace una sola vez: si la venta ya está cancelada/reembolsada, el procedimiento falla y no vuelve a sumar stock.
- El trigger de auditoría registra el cambio de estado, pero **no** toca el stock.
- No se elimina la fila de `motocicleta`; el índice filtrado `ux_venta_chasis_vigente` permite una nueva venta del mismo chasis solo si la anterior dejó de estar `efectuada`.

### 4.3 `sp_actualizar_precio_modelo`

1. Validar que el modelo exista y que `@nuevo_precio > 0`.
2. Actualizar `modelo_motocicleta.precio_lista`.
3. El trigger `trg_historial_precio_modelo` inserta el registro en `historial_de_precio`.
4. `COMMIT`; ante error, `ROLLBACK` y `THROW`.

No se debe insertar manualmente en `historial_de_precio` al usar este procedimiento: se duplicaría la auditoría.

### 4.4 Funciones

| Función | Entrada inválida | Resultado |
|---|---|---|
| `fn_precio_con_descuento` | precio negativo o porcentaje fuera de `0..100` | `NULL` |
| `fn_total_accesorios_venta` | venta inexistente | `NULL` |
| `fn_total_venta` | precio negativo o venta inexistente | `NULL` |
| `fn_cotizacion_vigente` | cotización inexistente | `NULL` |
| `fn_stock_disponible_modelo` | modelo inexistente | `NULL` |

Las funciones no escriben datos ni usan `TRY/CATCH`. La validación de negocio y el lanzamiento de errores quedan en los procedimientos.

### 4.5 Triggers

| Trigger | Evento | Escribe en | Condición |
|---|---|---|---|
| `trg_historial_precio_modelo` | `AFTER UPDATE` en `modelo_motocicleta` | `historial_de_precio` | `precio_lista` cambió |
| `trg_auditoria_venta` | `AFTER INSERT, UPDATE, DELETE` en `venta` | `auditoria_venta` | Siempre |
| `trg_auditoria_cliente_estado` | `AFTER UPDATE` en `cliente` | `auditoria_cliente` | `estado` cambió |

**Reglas:**

- Los triggers de auditoría solo insertan; nunca actualizan las tablas de negocio.
- Deben funcionar con `inserted`/`deleted` multi-fila.
- No se usan triggers `INSTEAD OF`.
- `RECURSIVE_TRIGGERS` queda desactivado; ningún trigger se llama a sí mismo.
- El usuario y la fecha/hora se completan con los valores por defecto de las tablas de auditoría.

### 4.6 Códigos de error

Rango reservado: `50001`–`50099`. Mensajes sin tildes para evitar problemas de encoding.

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
| `50009` | Porcentaje de descuento inválido |
| `50010` | JSON de accesorios inválido o con IDs duplicados |
| `50011` | Método de pago inválido |
| `50012` | Venta inexistente |
| `50013` | Transición de estado inválida |
| `50014` | Estado destino inválido |
| `50015` | Rango de fechas inválido |
| `50016` | Precio de modelo inválido |
| `50017` | Modelo inexistente |

---

## 5. Datos de prueba asignados

**Regla:** cada tema usa un chasis distinto para no chocar con el lote de Etapa III ni entre pruebas. Todos los chasis de la tabla están libres en el DML actual.

| Tema | Chasis reservado | Modelo | Cliente | Vendedor | Accesorio | Prueba esperada |
|---|---|---|---|---|---|---|
| Procedimientos y funciones | `HONCB500F002` | 11 — CB500F | `30456781` | `31222333` | `1` × 1 | Venta con 10 % de descuento: `precio_venta_moto = 7.650.000,00`, `monto_total = 7.835.000,00` |
| Transacciones | `YAMMT03002` | 12 — MT-03 2025 | `28345672` | `29876543` | `8` × 1 | `COMMIT` correcto y prueba de `ROLLBACK` con accesorio inexistente o cantidad `9999` |
| Triggers y auditoría | `KAWZ400001` | 14 — Z400 | `40234567` | `32109876` | `2` × 1 | Venta + cancelación: stock de modelo `+1`, stock de accesorio `+1`, auditoría `INSERT` y `UPDATE` |
| Concurrencia | `9C2KAW00000000014` | 10 — Ninja 400 | `35123903` | `34567890` | — | Dos sesiones simultáneas: solo una venta `efectuada`; la otra recibe `50004` o `50005` |
| Funciones sin venta | — | — | — | — | — | `fn_cotizacion_vigente` con cotizaciones existentes; `fn_stock_disponible_modelo` con modelos del DML |
| Seguridad | — | — | — | — | — | `EXECUTE AS USER` sobre `usr_xmotors_vendedor` y `usr_xmotors_consulta` |
| Índices | — | — | — | — | — | `SET STATISTICS IO/TIME ON` y plan de ejecución antes/después |

**Chasis adicionales reservados para pruebas de Etapa V** (no usar en otros temas):

```text
HONCB500F002        (modelo 11, stock 3)
HONCB500F003        (modelo 11, stock 3)
YAMMT03002          (modelo 12, stock 2)
YAMMT03003          (modelo 12, stock 2)
KAWZ400001          (modelo 14, stock 2)
9C2KAW00000000014   (modelo 10, stock 1)
9C2ZAN00000000009   (modelo 7,  stock 1)
9C2COR00000000011   (modelo 8,  stock 1)
BAJDOM40001         (modelo 13, stock 2)
ES-MON-528316       (modelo 17, stock 1, venta cancelada)
CHS89123409         (modelo 30, stock 1, venta cancelada)
```

**Datos existentes que se usan como contexto:**

- Clientes: `30456781`, `28345672`, `40234567`, `35123903`, `27654321`, `38765432`, `42111222`.
- Vendedores: `31222333`, `29876543`, `32109876`, `34567890`, `36543210`, `30999888`, `37111444`.
- Accesorios con stock: `1` (11), `2` (11), `8` (6).

**Limpieza:** las pruebas deben ejecutarse con `BEGIN TRAN ... ROLLBACK`. Si alguna prueba se confirma, limpiar en este orden:

1. `DELETE FROM dbo.detalle_venta_accesorio WHERE cod_venta = @cod_venta;`
2. `DELETE FROM dbo.venta WHERE cod_venta = @cod_venta;`
3. Reponer `modelo_motocicleta.stock_disponible` y `accesorio.stock` según corresponda.
4. No borrar `auditoria_venta` ni `historial_de_precio`: son evidencia de la prueba.

---

## 6. Convenciones de código

| Tema | Convención |
|---|---|
| Nombres | `snake_case`, en minúsculas; sin tildes ni `ñ` en scripts SQL |
| Prefijos | `fn_` funciones, `sp_` procedimientos, `trg_` triggers, `ix_` índices, `pk_`/`fk_`/`ck_`/`uq_`/`df_` restricciones |
| Esquema | `dbo.` explícito en todos los objetos |
| Creación | `CREATE OR ALTER` para funciones, procedimientos y triggers; `IF OBJECT_ID(...) IS NULL` para tablas; `DROP INDEX ... IF EXISTS` + `CREATE INDEX` para índices |
| Batch | Un objeto por batch, separado con `GO`; `CREATE OR ALTER` debe ser la primera instrucción del batch |
| Encabezado | `SET ANSI_NULLS ON;` y `SET QUOTED_IDENTIFIER ON;` |
| Procedimientos | `SET NOCOUNT ON;` y `SET XACT_ABORT ON;` al inicio |
| Errores | `BEGIN TRY ... BEGIN TRAN ... COMMIT ... END TRY BEGIN CATCH IF @@TRANCOUNT > 0 ROLLBACK; THROW; END CATCH` |
| Errores de negocio | `THROW 500xx, 'mensaje sin tildes', 1;` |
| Dinero | `DECIMAL(12,2)`; totales agregados `DECIMAL(14,2)`; porcentajes `DECIMAL(5,2)` |
| Fechas | `DATE` para días; `DATETIME2(0)` para auditoría |
| Consultas | Columnas explícitas, sin `SELECT *`; `ORDER BY` solo cuando el resultado lo requiera |
| Transacciones | Cortas, sin interacción con el usuario; un solo `COMMIT` y `ROLLBACK` en el `CATCH` |
| Auditoría | Los triggers solo insertan; el usuario y la fecha salen de los `DEFAULT` de las tablas |
| Seguridad | Roles con permisos mínimos; usuarios de prueba `WITHOUT LOGIN`; sin contraseñas en el repositorio |
| Evidencias | `.sql` reproducible + `.txt` de salida o `.png` de SSMS, con fecha, usuario y `@@VERSION` |

**Regla de oro del descuento:**

```text
CORRECTO:   precio_venta_moto = precio_lista * (1 - porcentaje / 100)
            monto_total       = precio_venta_moto + accesorios

INCORRECTO: monto_total = (precio_venta_moto + accesorios) * (1 - porcentaje / 100)
```

---

## 7. Evidencias

Cada carpeta `evidencias/` conserva su `.gitkeep` para que Git versione la estructura aunque todavía no haya archivos.

**Nombres previstos:**

| Carpeta | Archivos |
|---|---|
| `procedimientos_funciones/evidencias/` | `01_funciones_pruebas.sql`, `01_funciones_salida.txt`, `02_procedimientos_pruebas.sql`, `02_procedimientos_salida.txt`, `03_seguridad_pruebas.sql`, `03_seguridad_salida.txt`, `04_indices_antes_despues.txt` |
| `transacciones/evidencias/` | `01_venta_commit.txt`, `02_rollback.txt`, `03_concurrencia_sesion_a.txt`, `03_concurrencia_sesion_b.txt` |
| `triggers_auditoria/evidencias/` | `01_historial_precio.txt`, `02_auditoria_venta.txt`, `03_auditoria_cliente.txt` |

**Contenido mínimo de cada evidencia:**

1. `SELECT @@VERSION;`, `SELECT DB_NAME();`, `SELECT USER_NAME();` y `SELECT SYSDATETIME();`.
2. Script ejecutado y resultado obtenido.
3. Para transacciones: cantidad de filas afectadas, `@@TRANCOUNT` antes/después y mensaje de error si corresponde.
4. Para triggers: `SELECT` de la tabla de auditoría antes y después del cambio.
5. Para índices: `SET STATISTICS IO ON; SET STATISTICS TIME ON;` y plan de ejecución antes/después.

---

## 8. Verificación de la estructura

Desde la raíz del repositorio:

```powershell
# 1. Estructura
Get-ChildItem -Recurse -Force etapa_v | Select-Object FullName, Length

# 2. Los tres .gitkeep existen y están vacíos
Get-ChildItem -Recurse -Force etapa_v -Filter .gitkeep | Select-Object FullName, Length

# 3. Los archivos locales siguen ignorados
git check-ignore -v plan_etapa5.md etapa5_guia_oficial.md

# 4. Estado del repositorio
git status --short
```

Resultado esperado:

```text
etapa_v\procedimientos_funciones\evidencias\.gitkeep
etapa_v\transacciones\evidencias\.gitkeep
etapa_v\triggers_auditoria\evidencias\.gitkeep

.gitignore:2:etapa5_guia_oficial.md    etapa5_guia_oficial.md
.gitignore:3:plan_etapa5.md             plan_etapa5.md

?? etapa_v/
```

En Git Bash también se puede usar:

```bash
tree etapa_v
git check-ignore -v plan_etapa5.md etapa5_guia_oficial.md
```

---

## 9. Recordatorios

1. **No modificar** `sql/ddl/`, `sql/dml/`, `sql/consultas/` ni la documentación de las etapas I–IV. La Etapa V agrega objetos desde `etapa_v/`.
2. **No crear `METODO_PAGO`** en esta etapa: `venta.metodo_pago` sigue siendo `VARCHAR(50)`. Si se decide normalizar, será un cambio posterior que impacta DDL, DML y consultas.
3. **El descuento se aplica sobre `precio_venta_moto`, no sobre `monto_total`.**
4. **`monto_total = precio_venta_moto + accesorios`**; el precio de la moto ya incluye el descuento.
5. **El stock se descuenta en la misma transacción de la venta** y se reintegra una sola vez al cancelar o reembolsar.
6. **Los triggers de auditoría no modifican tablas de negocio.**
7. **Las pruebas se ejecutan con `ROLLBACK`** para conservar el lote de Etapa III; las capturas se toman antes del rollback.
8. **No versionar** `plan_etapa5.md` ni `etapa5_guia_oficial.md`; siguen en `.gitignore`.
9. **No commitear contraseñas** ni logins reales; los usuarios de prueba son `WITHOUT LOGIN`.

---

## 10. Commit sugerido

```text
(add) etapaV: crear estructura base y contrato de objetos
```
