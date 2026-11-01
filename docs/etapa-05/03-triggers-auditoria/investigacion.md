# Tema 3 — Triggers

**Sistema de Gestión de Ventas de Motos — "X Motors"**
Base de Datos I · Grupo 49 · FaCENA (UNNE) · Etapa V

---

## 1. Definición y objetivo

### 1.1 ¿Qué son?

Un **trigger** (*disparador*) es un bloque de código DML que se ejecuta **automáticamente** cuando se ejecuta una sentencia `INSERT`, `UPDATE` o `DELETE` sobre la tabla a la que está asociado. No lo llama el usuario: lo activa el propio motor ante la operación de datos.

En SQL Server, los triggers `AFTER` (también llamados `FOR`) se disparan **después** de que la operación validó las restricciones y modificó los datos. Los `INSTEAD OF` reemplazan la operación; esta etapa no los usa.

Dentro del trigger hay dos tablas virtuales:

- **`inserted`**: filas tal como quedaron (nuevas o modificadas).
- **`deleted`**: filas tal como estaban antes de la modificación.

| Operación | `inserted` | `deleted` |
|---|---|---|
| `INSERT` | filas nuevas | vacía |
| `UPDATE` | estado posterior | estado anterior |
| `DELETE` | vacía | filas borradas |

### 1.2 Objetivo en X Motors

La pregunta central de la etapa es *"¿cómo hacemos robusta la base?"*. Los triggers aportan la respuesta: **la base registra sola lo que los usuarios no recuerdan registrar**. Los componentes implementados:

1. **`trg_historial_precio_modelo`** (regla de negocio RN7): cada cambio de precio queda en `historial_de_precio`, sin que el administrador tenga que recordarlo. Hoy el precio "congelado" en una venta solo se explica si existe ese historial.
2. **`trg_auditoria_venta`**: toda inserción, cambio de estado o borrado de una venta queda en `auditoria_venta`, con estado anterior/nuevo y monto anterior/nuevo. Es la traza indispensable ante reclamos ("¿quién canceló mi factura?").
3. **`trg_auditoria_cliente_estado`**: los cambios de estado del cliente (`interesado`, `en proceso de compra`, `comprador`) quedan en `auditoria_cliente`, porque ese dato alimenta decisiones comerciales.

Además se crean dos tablas de auditoría, `auditoria_venta` y `auditoria_cliente`, **sin claves foráneas**: si alguien borra una venta o un cliente, la evidencia debe sobrevivir.

---

## 2. Ventajas y aplicaciones

| Ventaja | Cómo se aplica en X Motors |
|---|---|
| **Automatización** | Nadie recuerda insertar el registro de auditoría a mano; el motor lo hace siempre. |
| **Imposible de saltear** | Un `UPDATE` por SSMS, por script o por la aplicación dispara el mismo trigger. |
| **Reglas de negocio automáticas** | RN7 (historial de precios) vive en la base, no en los procedimientos de la aplicación. |
| **Trazabilidad académica** | `usuario_bd` y `fecha_hora` salen de los `DEFAULT`, no dependen del código que escribió cada quien. |
| **Sin contaminar el negocio** | Los triggers solo *leen* `inserted`/`deleted` y solo *insertan* en tablas de auditoría. |
| **Set-based** | Un trigger admite un `UPDATE` de 1 o de 500 filas con el mismo código. |

**Aplicaciones típicas de triggers:** auditoría técnica, tablas de negocio derivadas (historial de precios), control de integridad compleja que las restricciones declarativas no pueden expresar, e invalidación de cachés de aplicación.

**Límite importante acá:** el trigger de precios sí escribe en una tabla de negocio (`historial_de_precio`); el resto son auditoría pura. La distinción es de dominio: `historial_de_precio` salió en las etapas anteriores y alimenta reportes; `auditoria_*` se crearon solo para la trazabilidad de la Etapa V.

---

## 3. Implementación en SQL Server Express

### 3.1 Sintaxis base

```sql
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

USE [X MOTORS];
GO

CREATE OR ALTER TRIGGER dbo.trg_auditoria_cliente_estado
ON dbo.cliente
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM inserted AS i
        JOIN deleted AS d
            ON d.dni_cliente = i.dni_cliente
        WHERE ISNULL(i.estado, '') <> ISNULL(d.estado, '')
    )
    BEGIN
        INSERT INTO dbo.auditoria_cliente (dni_cliente, estado_anterior, estado_nuevo)
        SELECT i.dni_cliente, d.estado, i.estado
        FROM inserted AS i
        JOIN deleted AS d
            ON d.dni_cliente = i.dni_cliente
        WHERE ISNULL(i.estado, '') <> ISNULL(d.estado, '');
    END;
END;
GO
```

Reglas de implementación que aplicamos:

- **`SET NOCOUNT ON` primero:** sin eso, cada inserción de auditoría devuelve "N rows affected" y ensucia la salida de los procedimientos.
- **Guarda de cambio vacío:** en los triggers de estado se consulta si el dato realmente cambió; si el `UPDATE` re-confirma el mismo valor, no se audita nada (verificado en la prueba 3).
- **Multi-fila desde el primer día:** nunca se usa `SELECT @valor = col FROM inserted` suponiendo una fila; se hace `INSERT ... SELECT` sobre las dos tablas virtuales con join por clave, así un `UPDATE ... WHERE dn IN (...)` masivo se audita igual.
- **Sin triggers `INSTEAD OF`:** se mantienen en `AFTER`, que en SQL Server Express es lo natural para auditoría.
- **`RECURSIVE_TRIGGERS` desactivado** (el default de SQL Server): el trigger de auditoría no puede llamarse a sí mismo ninguna vez.
- **Un trigger por evento y por tabla:** en SQL Server preferimos un único trigger `AFTER INSERT, UPDATE, DELETE` sobre `venta` (con ramas `IF EXISTS(inserted AND NOT deleted)` para `INSERT`, etc.) a tres triggers sueltos; el orden de disparo se hace previsiblemente.
- **Creación idempotente de tablas** con `IF OBJECT_ID(...) IS NULL` para que el script sea re-ejecutable en la reconstrucción final de la base (Ejecución 5).

### 3.2 Congelar el `INSERT` antes de llegar a la auditoría

En la corrida final quedó demostrado un detalle fino:

`sp_registrar_venta` calcula `monto_total` **antes** de hacer el `INSERT`. Así, el trigger de auditoría registra la fila con el monto definitivo en su único `INSERT`, y no se genera un segundo registro `UPDATE` spúreo.

La evidencia de esta ejecución tiene dos corridas:

1. **Corrida de validación** con una versión vieja del procedimiento que hacía `INSERT` + `UPDATE venta SET monto_total = fn_total_venta(...)`; el trigger registró ese `UPDATE` intermedio (filas 35/36 de historial es la constancia, y las filas 1, 2 y 3 de auditoría_venta para `cod_venta` = 33).
2. **Corrida final** con el procedimiento actual que ya inserta el total correcto; el trigger registró exactamente un `INSERT`, un `UPDATE` (la cancelación) y un `DELETE` (la limpieza) para `cod_venta` = 34.

Consecuencia metodológica: si un trigger de auditoría muestra cláusulas `UPDATE` que el negocio no debería hacer, el defecto está en el **procedimiento**, no en el trigger. Poner los triggers como observadores neutrales ayuda a detectar el problema en lugar de ocultarlo.

---

## 4. Caso concreto aplicado al sistema de ventas

### 4.1 Tablas de auditoría (sin FK, con DEFAULT de usuario y fecha)

```sql
CREATE TABLE dbo.auditoria_venta (
    id_auditoria     INT IDENTITY(1,1) NOT NULL,
    cod_venta        INT NOT NULL,
    accion           VARCHAR(10) NOT NULL,
    estado_anterior  VARCHAR(30) NULL,
    estado_nuevo     VARCHAR(30) NULL,
    monto_anterior   DECIMAL(12,2) NULL,
    monto_nuevo      DECIMAL(12,2) NULL,
    usuario          VARCHAR(128) NOT NULL DEFAULT USER_NAME(),
    fecha_hora       DATETIME2(0) NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT pk_auditoria_venta PRIMARY KEY (id_auditoria),
    CONSTRAINT ck_auditoria_venta_accion CHECK (accion IN ('INSERT','UPDATE','DELETE'))
);
```

`auditoria_cliente` es análoga con `dni_cliente`, `estado_anterior`, `estado_nuevo`. Ambas llevan índice por clave de negocio + fecha (`ix_auditoria_venta_cod_venta`, `ix_auditoria_cliente_dni`) para consultas tipo "todo lo que pasó con la venta X".

`cod_venta` y `dni_cliente` **no** tienen FK: si la fila original se borra, la auditoría la referencia igual. Ese es un costo consciente (el valor queda huérfano) que equilibra la garantía de no perder la evidencia.

### 4.2 Los tres triggers

| Trigger | Tabla | Evento | Condición de disparo | Destino |
|---|---|---|---|---|
| `trg_historial_precio_modelo` | `modelo_motocicleta` | `AFTER UPDATE` | cambió `precio_lista` | `historial_de_precio` |
| `trg_auditoria_venta` | `venta` | `AFTER INSERT, UPDATE, DELETE` | siempre | `auditoria_venta` |
| `trg_auditoria_cliente_estado` | `cliente` | `AFTER UPDATE` | cambió `estado` | `auditoria_cliente` |

### 4.3 Demostración concreta

**Historial de precios (RN7).** El modelo 1 (CB 125F Twister):

```text
$3.850.000 (precio lista original)
   |  sp_actualizar_precio_modelo(1, 3.950.000)
   v  -> trigger inserta historial id 37: precio_anterior 3.850.000, precio_nuevo 3.950.000
$3.950.000
   |  sp_actualizar_precio_modelo(1, 3.850.000)  (restauración)
   v  -> trigger inserta historial id 38
$3.850.000 (precio final, igual al original)
```

El precio restaurado no borra nada del historial: la evolución queda completa, que es el objetivo de RN7.

**Auditoría de venta.** Venta demo con el chasis reservado del tema (`KAWZ400001`, modelo 14 Z400, cliente `40234567`, vendedor `32109876`, accesorio 2 × Casco abierto `$98.000`), `cod_venta` = 34:

```text
INSERT   : estado efectuada   , monto_nuevo    = 10.598.000
UPDATE 1 : efectuada -> cancelada, monto 10.598.000 en ambos
DELETE   : cancelada -> (nada)  , monto_anterior = 10.598.000
```

Tras cada paso se consulta `auditoria_venta` con `SELECT` filtrado por `cod_venta` (evidencia en `salida_sqlcmd.txt`): en la prueba 2 la fila 1 es `INSERT`, en la prueba 3 se agregan las filas 2 y 3 como `UPDATE` (cancelación) y `DELETE` (limpieza). A medida que pasa el tiempo, la auditoría acumula y nunca se contrae.

**Auditoría de estado del cliente.** Cliente `42111222` (Nicolás Duarte):

```text
interesado → comprador : 1 fila (estado_anterior interesado, estado_nuevo comprador)
comprador → comprador  : 0 filas (el trigger detecta que no cambió)
comprador → interesado : 1 fila (restauración)
```

---

## 5. Script y resultados

### 5.1 Scripts

| Archivo | Contenido |
|---|---|
| [`01_tablas_auditoria.sql`](01_tablas_auditoria.sql) | `auditoria_venta`, `auditoria_cliente` y sus índices (idempotente) |
| [`02_trg_historial_precio_modelo.sql`](02_trg_historial_precio_modelo.sql) | Trigger `AFTER UPDATE` sobre precio de modelo |
| [`03_trg_auditoria_venta.sql`](03_trg_auditoria_venta.sql) | Trigger `AFTER INSERT, UPDATE, DELETE` sobre venta |
| [`04_trg_auditoria_cliente_estado.sql`](04_trg_auditoria_cliente_estado.sql) | Trigger `AFTER UPDATE` sobre estado de cliente |
| [`evidencias/01_pruebas_triggers.sql`](evidencias/01_pruebas_triggers.sql) | Script de demostración reproducible |

### 5.2 Resultados

| Verificación | Resultado |
|---|---|
| Las 2 tablas de auditoría se crearon sin FK y con `DEFAULT` de usuario/fecha | ✔ |
| Los 3 triggers existen y están habilitados | ✔ |
| Cambio de precio del modelo 1 → 1 fila en `historial_de_precio` por cada paso | ✔ (total 34 → 38) |
| INSERT de la venta demo → 1 fila en `auditoria_venta` con monto definitivo | ✔ |
| Cancelación de la venta demo → 1 fila `UPDATE` `efectuada→cancelada` | ✔ |
| Borrado de la venta demo (limpieza) → 1 fila `DELETE` | ✔ |
| Cambio de estado del cliente 42111222 → filas en `auditoria_cliente` por cada cambio real | ✔ |
| `UPDATE` sin cambio de estado → 0 filas nuevas | ✔ |
| Stock del modelo 14 y del accesorio 2 restaurado | ✔ (2 y 11) |
| Precio del modelo 1 restaurado a `$3.850.000` | ✔ |

### 5.3 Evidencias

- [`evidencias/salida_sqlcmd.txt`](evidencias/salida_sqlcmd.txt) — corrida completa con fecha, usuario y `@@VERSION`.
- [`evidencias/01_historial_precio.txt`](evidencias/01_historial_precio.txt), [`evidencias/02_auditoria_venta.txt`](evidencias/02_auditoria_venta.txt), [`evidencias/03_auditoria_cliente.txt`](evidencias/03_auditoria_cliente.txt) — extractos por trigger.
- [`evidencias/resultados.md`](evidencias/resultados.md) — resumen legible con las tablas de arriba.

### 5.4 Conclusión

La consigna se cubre en los cinco puntos:

1. **Definición y objetivo:** trigger = código que dispara el motor ante `INSERT`/`UPDATE`/`DELETE`; en X Motors, todo lo que el negocio debía recordar (RN7) y toda actividad sobre ventas/clientes queda registrado por sí mismo.
2. **Ventajas:** automaticidad, imposibilidad de saltear, trazabilidad con autor y fecha/hora, capa técnica separada del negocio.
3. **Implementación en Express:** `CREATE OR ALTER TRIGGER`, `AFTER`, `inserted`/`deleted`, `SET NOCOUNT ON`, guardas de cambio vacío, triggers set-based, tablas de auditoría idempotentes sin FK.
4. **Caso concreto:** RN7 con precio del modelo 1, ciclo de vida completo de una venta (`KAWZ400001`) con su triple `INSERT`/`UPDATE`/`DELETE`, y ciclo de estado del cliente `42111222`.
5. **Script y resultados:** 5 scripts reproducibles + 4 evidencias verificadas sobre la misma corrida.
