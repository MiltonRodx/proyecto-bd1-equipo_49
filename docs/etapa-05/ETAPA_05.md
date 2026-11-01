# Etapa V: Temas Técnicos

**Sistema de Gestión de Ventas de Motos — "X Motors"** · Base de Datos I · Grupo 49 · FaCENA (UNNE)

> Pregunta central: **¿Cómo hacemos robusta la base de datos?**

---

## 1. Integrantes

Rodriguez Rivas Milton Nahuel · Zacarías Blanco Fernando Iván · Balenzuela Tobías · Veglia Marcos Daniel · Zarate Arturo Alan

---

## 2. Objetivo

Investigar e implementar mecanismos avanzados de SQL Server que mejoren la **robustez, confiabilidad y mantenibilidad** de la base de datos del sistema de ventas. La consigna v2 define 5 temas obligatorios, y para cada uno se presentan: definición y objetivo, ventajas y aplicaciones, implementación en SQL Server Express, caso concreto aplicado al sistema de ventas del equipo, y script de demostración con resultados.

| # | Tema | Problema de negocio que resuelve |
|---|---|---|
| 1 | Procedimientos y funciones almacenadas | Centralizar descuentos, totales y el registro de ventas en una única operación consistente |
| 2 | Manejo de transacciones | Que una venta y su stock no queden a medias (propiedad ACID) |
| 3 | Triggers de auditoría | Responder quién cambió un precio, un estado o un monto, cuándo y con qué valores |
| 4 | Seguridad (usuarios y roles) | Principio de mínimo privilegio: administrador, vendedor y consultor con permisos distintos |
| 5 | Optimización de consultas (índices) | Reportes y búsquedas rápidas cuando el volumen de datos crece (demostrado con 1.000.000 de filas) |

---

## 3. Archivos y estructura

Todo el trabajo vive en [`docs/etapa-05/`](./), un tema por carpeta, cada una con su `investigacion.md` (los 5 puntos de la consigna) y su carpeta `evidencias/`:

```text
docs/etapa-05/
├── ETAPA_05.md                     ← este documento (resumen entregable)
├── README.md                       ← contrato completo de la etapa (objetos, firmas, secuencia)
├── 01-procedimientos-funciones/    ← Tema 1
├── 02-transacciones/               ← Tema 2
├── 03-triggers-auditoria/          ← Tema 3
├── 04-seguridad/                   ← Tema 4
└── 05-indices/                     ← Tema 5
```

**Orden de ejecución sobre una base limpia** (detalle completo y explicado en el [README.md](README.md) §2.2):

| # | Script | Tema |
|---|---|---|
| 1 | `sql/ddl/DDL_Script_X_Motors.sql` + `sql/dml/DML_Script_X_Motors.sql` | Base y lote |
| 2 | `03-triggers-auditoria/01_tablas_auditoria.sql` | 3 |
| 3 | `01-procedimientos-funciones/01_funciones.sql` + `02_procedimientos.sql` | 1 |
| 4 | `02-transacciones/01_sp_registrar_venta.sql` + `02_sp_cambiar_estado_venta.sql` | 2 |
| 5 | `02-transacciones/scripts.sql` (demos ACID) | 2 |
| 6 | `03-triggers-auditoria/02..04_trg_*.sql` (triggers) | 3 |
| 7 | `04-seguridad/01_seguridad.sql` (roles y usuarios permanentes) | 4 |
| 8 | `05-indices/01_indices.sql` (índices del lote) | 5 |
| 9 | `*/evidencias/*_pruebas.sql` (pruebas con `ROLLBACK`) | todos |
| 10 | `05-indices/02_indices_mass_load.sql` + `03_indices_mass_mediciones.sql` (prueba de escala 1M+) | 5 |
| 11 | `04-seguridad/02_seguridad_logins_reales.sql` (demo del profesor con logins efímeros) | 4 |

**Requisitos técnicos:** SQL Server 2016 SP1+ (`CREATE OR ALTER`, `OPENJSON`), compatibilidad 130+. Verificado sobre **SQL Server 2025 Express (Docker)** y sobre SQL Server 2022 (Windows).

**Scripts idempotentes:** `CREATE OR ALTER` (funciones/SP/triggers), `IF OBJECT_ID(...) IS NULL` (tablas), `DROP INDEX IF EXISTS` (índices). Las pruebas de datos corren dentro de `BEGIN TRAN ... ROLLBACK` para conservar el lote de Etapa III.

---

## 4. Tema 1 — Procedimientos y funciones almacenadas

### 4.1 Definición y objetivo

Los **procedimientos almacenados** son programas SQL guardados en el motor que encapsulan múltiples operaciones; las **funciones** reciben parámetros y devuelven un valor o tabla. En X Motors encapsulan las reglas de negocio (descuentos, totales, stock) para que ningún script suelto pueda violarlas.

### 4.2 Ventajas y aplicaciones

Reúso de lógica, código parametrizado, centralización de reglas, seguridad por ejecución (ver Tema 4) y validaciones (`TRY/CATCH`, `THROW`) altijd en el mismo lugar.

### 4.3 Implementación y caso concreto

| Objeto | Qué hace |
|---|---|
| `fn_precio_con_descuento` | Precio de la moto con descuento (`NULL` si entra inválida) |
| `fn_descuento_cliente` | 10% / 5% / 0% según monto acumulado en ventas `efectuada` (el caso `fn_CalcularDescuentoCliente` de la consigna) |
| `fn_resumen_cliente` | Vista de apoyo (ventas, monto acumulado, descuento por cliente) |
| `fn_total_accesorios_venta` / `fn_total_venta` | Componentes de la fórmula RN11: `monto_total = precio_venta_moto + accesorios` |
| `fn_cotizacion_vigente` / `fn_stock_disponible_modelo` | RN12 y stock por modelo |
| `sp_actualizar_precio_modelo` | Cambia `precio_lista` con validación y bloqueo (el trigger de auditoría registra el cambio; ver Tema 3) |
| `sp_reporte_ventas_periodo` | Ranking de vendedores por período con ticket promedio |
| `sp_registrar_venta` | **La operación central**: valida todo, calcula descuento (automático por historial si no se pasa), inserta la venta con JSON de accesorios, descuenta stock y audita los errores 50001–50019 |
| `sp_cambiar_estado_venta` | `efectuada → cancelada/reembolsada` con reintegro de stock único |

**Reglas de negocio aplicadas:** RN6 (congelado de precio), RN10 (1 moto + 0..N accesorios), RN11 (montos), RN12 (vigencia de cotizaciones). Descuento aplicado **solo al precio de la moto**, nunca a los accesorios ni al total.

### 4.4 Script y resultados

`01-procedimientos-funciones/01_funciones.sql` + `02_procedimientos.sql` · evidencias en `01-procedimientos-funciones/evidencias/` (prueba reproducible, salidas SQL Server y Docker, `resultados.md`).

Venta demo `31`: precio lista `8.500.000,00`, 10% de descuento → `precio_venta_moto = 7.650.000,00`, accesorios `227.000,00`, `monto_total = 7.877.000,00`; **factura de Etapa IV devuelve `OK`** sobre la venta demo. Cancelación posterior restauró el stock intacto. Casos negativos (cliente inexistente 50001, chasis ya vendido 50005, JSON inválido 50010, método de pago 50011, etc.) rechazados sin dejar datos parciales.

---

## 5. Tema 2 — Manejo de transacciones

### 5.1 Definición y objetivo

Una transacción es una unidad lógica de trabajo: o todas las operaciones se confirman (`COMMIT`) o ninguna (`ROLLBACK`), garantizando atomidad, consistencia, aislamiento y durabilidad (ACID).

### 5.2 Ventajas y aplicaciones

Una venta toca `venta`, `detalle_venta_accesorio`, `motocicleta`, `modelo_motocicleta.stock_disponible` y el estado del cliente: sin transacción, un error a mitad deja datos incompletos y stock fantasma.

### 5.3 Implementación y caso concreto

- `sp_registrar_venta` y `sp_cambiar_estado_venta` con `SET XACT_ABORT ON`, `BEGIN TRY/BEGIN TRAN/COMMIT`, `ROLLBACK` + `THROW` en el `CATCH`.
- Bloqueo pesimista del stock con `UPDLOCK, HOLDLOCK` y orden fijo de bloqueo de tablas para evitar deadlocks entre ventas concurrentes.
- `scripts.sql` con 3 demos: **COMMIT correcto** (venta + stock descontados), **ROLLBACK por stock insuficiente** (error 50004: la venta no queda), **ROLLBACK por FK inválida** (error 547). Cancelación final restaura el stock.

### 5.4 Script y resultados

`02-transacciones/scripts.sql` · evidencias en `02-transacciones/evidencias/` (salidas `sqlcmd` local y Docker, `resultados.md`).

Verificado: `XACT_STATE()`/`@@TRANCOUNT` correctos antes y después de cada demo; ninguna demo dejó venta parcial (atomicidad), el stock vuelve siempre al valor original.

---

## 6. Tema 3 — Triggers de auditoría

### 6.1 Definición y objetivo

Los triggers son rutinas que el motor ejecuta automáticamente ante `INSERT`/`UPDATE`/`DELETE` sobre una tabla. En X Motors responden: ¿quién cambió un precio, un estado o un monto, cuándo y con qué valores?

### 6.2 Ventajas y aplicaciones

Trazabilidad automática sin código cliente; detección de cambios de los datos sensibles (`venta`, `modelo_motocicleta.precio_lista`, `cliente.estado`) independientemente de que el cambio venga de un SP, un script o un usuario directo.

### 6.3 Implementación y caso concreto

| Objeto | Evento | Almacena |
|---|---|---|
| `trg_historial_precio_modelo` | `AFTER UPDATE` en `modelo_motocicleta` | Precio anterior/nuevo + fecha en `historial_de_precio` (solo si cambia `precio_lista`) |
| `trg_auditoria_venta` | `AFTER INSERT/UPDATE/DELETE` en `venta` | Acción, estado y monto anterior/nuevo en `auditoria_venta` |
| `trg_auditoria_cliente_estado` | `AFTER UPDATE` en `cliente` | Estado anterior/nuevo en `auditoria_cliente` |

Diseño multi-fila (set basado en `inserted`/`deleted`), solo insertan (nunca modifican tablas de negocio), sin recursión. El caso del profe (modificar precio → registro automático) queda cubierto por `trg_historial_precio_modelo` + `sp_actualizar_precio_modelo`.

### 6.4 Script y resultados

`03-triggers-auditoria/01..04_*.sql` · evidencias en `03-triggers-auditoria/evidencias/`.

Ciclo completo demo de venta (`INSERT`/`UPDATE`/`DELETE`) con las tres filas correspondientes en `auditoria_venta`; historial de precios pasó de 34 a 38 filas tras cambios de precio demo; estados del cliente auditaron sus snapshots; un `UPDATE` sin cambio de valor no registra (diseño intencional).

---

## 7. Tema 4 — Seguridad con usuarios y roles

### 7.1 Definición y objetivo

El modelo de seguridad define quién puede hacer qué: **logins** (identidad en el servidor), **usuarios** (identidad en la base) y **roles** (grupos de permisos), bajo el principio de mínimo privilegio. Perfiles reales de X Motors: administrador del sistema, vendedor de salón, consultor telefónico.

### 7.2 Ventajas y aplicaciones

Protección de datos contables/administrativos, permisos agrupados por perfil (no por persona), y acceso de escritura **solo a través de los procedimientos** (no por DML directo sobre tablas).

### 7.3 Implementación y caso concreto

Solo dispongo dos enfoques complementarios:

1. **Enfoque permanente** (`01_seguridad.sql`): 3 roles (`rol_xmotors_admin`, `rol_xmotors_vendedor`, `rol_xmotors_consulta`) + 3 usuarios de prueba `WITHOUT LOGIN` reproducibles sin permisos de sysadmin, probados con `EXECUTE AS USER`. El vendedor tiene `GRANT EXECUTE` sobre los SP de venta y solo lectura del catálogo; la consulta tiene `DENY` de auditoría/historial/administración; el admin tiene el esquema completo.
2. **Enfoque del profesor** (`02_seguridad_logins_reales.sql`): demo con `CREATE LOGIN` reales efímeros (se crean y se destruyen en el mismo script; contraseñas placeholder de demo): admin con `db_owner`, lector con `SELECT` + `GRANT EXECUTE`, y rol de consulta de modelos con/sin miembro.

### 7.4 Script y resultados

Evidencias en `04-seguridad/evidencias/`.

Tabla de las 5 pruebas de la consigna v2 (con logins reales) — **5/5 conforme**:

| Prueba | Usuario | Esperado | Obtenido |
|---|---|---|---|
| `INSERT` directo en `venta` | admin | Correcto | ✅ Exitoso |
| `INSERT` directo en `venta` | lector | Acceso denegado | ✅ Error 229 |
| `EXEC` de SP con `INSERT` | lector | Correcto | ✅ Exitoso (ownership chaining) |
| `SELECT modelo_motocicleta` | con rol | Correcto | ✅ Exitoso |
| `SELECT modelo_motocicleta` | sin rol | Acceso denegado | ✅ Error 229 |

En el enfoque permanente: denegaciones 229 verificadas en DML directo sobre auditoría/historial y ventas que solo el SP puede registrar (`EXEC` permitido via chaining). **Limitación documentada:** el SP con `INSERT` vía `sp_executesql` requiere `WITH EXECUTE AS OWNER` para el chaining de lotes dinámicos (véase la observación honesta del `investigacion.md` del tema).

---

## 8. Tema 5 — Optimización de consultas con índices

### 8.1 Definición y objetivo

Un índice es una estructura auxiliar (árbol B+) con copias ordenadas de pocas columnas y punteros a la fila: las consultas que filtran por esas columnas llegan por **seek** en lugar de recorrer toda la tabla.

### 8.2 Ventajas y aplicaciones

Menos lecturas y tiempos de respuesta en búsquedas por cliente, vendedor, fechas de reportes, cotizaciones vencidas, evolución de precios. Costo: ocupan espacio y penalizan levemente `INSERT/UPDATE/DELETE`.

### 8.3 Implementación y caso concreto

- **Sobre el modelo real** (`01_indices.sql`): 10 índices idempotentes justificados por las consultas de Etapa IV (reportes por fecha/estado, historial de cliente, ranking de vendedor, accesorios más vendidos, cotizaciones por cliente/vencidas, evolución de precios, stock físico, proveedores).
- **Prueba de escala exigida por la consigna v2** (`02_indices_mass_load.sql` + `03_indices_mass_mediciones.sql`): tabla desechable `venta_historica_prueba` con **1.000.000 de filas** cargadas en una sola sentencia (patrón `ROW_NUMBER()` + `CROSS JOIN` del propio guía), medición del trimestre 2023 en tres escenarios.

### 8.4 Script y resultados

Evidencias en `05-indices/evidencias/` (salidas con `SET STATISTICS IO/TIME` + plan textual `SHOWPLAN_TEXT`).

**Resultado de la prueba de escala (49.393 filas filtradas, tabla comparativa de la consigna):**

| Escenario | Tiempo CPU (ms) | Total (ms) | Lecturas lógicas | Operación principal |
|---|---|---|---|---|
| Sin índice | 107 | 111 | 3.585 | Table Scan |
| Índice agrupado sobre fecha | 9 | 9 | 230 | Clustered Index Seek |
| Índice con cobertura (`INCLUDE`) | 9 | 9 | 162 | Index Seek |

Los 4 resultados esperados por la consigna se verifican: Table Scan masivo → reducción drástica con el índice por fecha → mínimo con el de cobertura → planes con cambio de Scan a Seek. Sobre el lote chico de Etapa III la diferencia no se ve (2–9 páginas); la prueba de escala demuestra empíricamente por qué los índices de negocio de `01_indices.sql` están bien elegidos para el crecimiento real.

---

## 9. Resultados globales y estado de entrega

| Tema | Objetos | Resultado clave |
|---|---|---|
| 1. Procedimientos y funciones | 7 funciones + 4 SP | Venta demo `31` OK contra factura de Etapa IV; errores 50001–50019 controlados |
| 2. Transacciones | 2 SP transaccionales + demos ACID | `COMMIT`/`ROLLBACK` verificados con `XACT_STATE()`; ninguna venta parcial |
| 3. Triggers | 2 tablas de auditoría + 3 triggers | Ciclo completo `INSERT/UPDATE/DELETE` auditado; historial de precios 34→38 filas |
| 4. Seguridad | 3 roles + 3 usuarios permanentes + demo de logins efímeros | 5/5 pruebas del profe conforme + denegaciones 229 verificadas |
| 5. Índices | 10 índices + prueba de escala 1M+ | 3.585 → 230 → 162 lecturas lógicas (Table Scan → Seek) |

- El lote de Etapa III queda intacto tras todas las demos (31 ventas, stocks originales).
- El DDL/DML/consultas de las etapas I–IV **no fueron modificados** (`METODO_PAGO` sigue fuera de alcance: `venta.metodo_pago` es `VARCHAR(50)`).
- Base de verificación final: **SQL Server 2025 Express (Docker)**, recreada desde cero con DDL + DML + todos los scripts de esta etapa, sin errores.
- La etapa fue entregada el 27/10/2026; las demos 10 y 11 de la secuencia (prueba de escala de índices y logins reales) se agregaron el 01/11/2026 como complementos de la consigna v2.
