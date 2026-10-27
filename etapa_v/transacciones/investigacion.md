# Investigación — Transacciones en SQL Server

**Proyecto:** X Motors — Sistema de Gestión de Ventas de Motos
**Materia:** Base de Datos I — FaCENA (UNNE) — Grupo 49
**Etapa:** V — Tema 2: Transacciones
**Entorno de prueba:** SQL Server 2025 Express, base `[X MOTORS]`, `sqlcmd` 17.0.1000.7
**Archivos relacionados:** [`scripts.sql`](scripts.sql) · [`evidencias/salida_sqlcmd.txt`](evidencias/salida_sqlcmd.txt) · [`evidencias/resultados.md`](evidencias/resultados.md)

---

## Mapa de la consigna

| Punto solicitado | Sección |
|---|---|
| ACID | [1](#1-acid) |
| `TRY/CATCH` | [2.1](#21-trycatch) |
| `XACT_ABORT` | [2.2](#22-xact_abort) |
| `XACT_STATE` | [2.3](#23-xact_state) |
| `SAVE TRANSACTION` | [3](#3-save-transaction) |
| Nivel de aislamiento | [4](#4-niveles-de-aislamiento) |
| Bloqueos | [5](#5-bloqueos) |

---

## 1. ACID

ACID es el conjunto de propiedades que garantiza que una transacción se trate como una unidad confiable, incluso ante errores, cortes o concurrencia.

### 1.1 Atomicidad (Atomicity)

Una transacción es **todo o nada**. Si una parte falla, se deshacen todas las operaciones anteriores.

En X Motors, una venta implica varias operaciones que deben quedar juntas:

1. Insertar la fila en `venta`.
2. Insertar una o más filas en `detalle_venta_accesorio`.
3. Descontar `modelo_motocicleta.stock_disponible`.
4. Descontar `accesorio.stock`.
5. Actualizar `cliente.estado` a `comprador`.

Si falla el paso 4, no puede quedar la venta registrada con el stock de la moto ya descontado. El `BEGIN TRAN ... COMMIT` agrupa todo; el `ROLLBACK` deshace todo.

**Ejemplo del script:** el demo 2 inserta una unidad ficticia, una venta y un detalle; al detectar stock 0 lanza el error y hace `ROLLBACK`. Al final no queda ninguna de las tres filas.

### 1.2 Consistencia (Consistency)

Una transacción debe llevar la base de un estado válido a otro estado válido, respetando restricciones (`PK`, `FK`, `UNIQUE`, `CHECK`) y reglas de negocio.

En X Motors:

- `venta.numero_chasis` debe existir en `motocicleta` (`fk_venta_motocicleta`).
- `venta.dni_cliente` debe existir en `cliente` (`fk_venta_cliente`).
- `detalle_venta_accesorio.cantidad > 0`.
- `modelo_motocicleta.stock_disponible >= 0` y `accesorio.stock >= 0`.
- Un chasis no puede tener dos ventas `efectuada` a la vez (`ux_venta_chasis_vigente`).
- `monto_total = precio_venta_moto + suma(accesorios)`.

**Ejemplo del script:** el demo 3 intenta insertar una venta con `dni_cliente = 99999999` y un chasis inexistente. La FK `fk_venta_cliente` rechaza la operación con el error 547; el `CATCH` hace `ROLLBACK` y relanza el error.

### 1.3 Aislamiento (Isolation)

Las transacciones concurrentes no deben ver estados intermedios inconsistentes. El nivel de aislamiento define qué anomalías se permiten y cuánto se bloquea.

En X Motors, dos vendedores podrían intentar vender la última unidad del mismo modelo al mismo tiempo. Sin control, ambos podrían leer `stock_disponible = 1`, vender y dejar el stock en `-1`. Para evitarlo, el procedimiento de venta bloquea la fila del modelo con `UPDLOCK, HOLDLOCK` antes de leer y descontar.

**Ejemplo del script:** el demo 1 lee el stock con `UPDLOCK, HOLDLOCK`, valida que sea `>= 1`, inserta la venta y recién después descuenta. El bloqueo se mantiene hasta el `COMMIT`.

### 1.4 Durabilidad (Durability)

Una vez confirmado el `COMMIT`, los cambios deben sobrevivir a un fallo del sistema. SQL Server lo garantiza con el registro de transacciones (*transaction log*) y la recuperación al reiniciar.

**Ejemplo del script:** la venta del demo 1 se confirma con `COMMIT`; luego se consulta y sigue existiendo. Al final se cancela de forma controlada (no se borra), para dejar evidencia y restaurar el stock.

### 1.5 Resumen ACID en X Motors

| Propiedad | Mecanismo | Dónde se ve |
|---|---|---|
| Atomicidad | `BEGIN TRAN` / `COMMIT` / `ROLLBACK` | Venta + detalle + stock |
| Consistencia | `PK`, `FK`, `CHECK`, `UNIQUE`, reglas de negocio | Chasis/cliente válidos, stock no negativo |
| Aislamiento | Nivel de aislamiento + bloqueos | `UPDLOCK, HOLDLOCK` sobre stock |
| Durabilidad | Transaction log | Venta confirmada que persiste |

---

## 2. Manejo de errores: `TRY/CATCH`, `XACT_ABORT` y `XACT_STATE`

### 2.1 `TRY/CATCH`

`TRY...CATCH` permite capturar errores en T-SQL y decidir si se revierte la transacción, se registra el error o se relanza.

```sql
BEGIN TRY
    BEGIN TRANSACTION;

    -- Operaciones de la venta
    INSERT INTO dbo.venta (...) VALUES (...);
    INSERT INTO dbo.detalle_venta_accesorio (...) VALUES (...);
    UPDATE dbo.modelo_motocicleta SET stock_disponible = stock_disponible - 1 WHERE id_modelo = 11;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
```

Funciones útiles dentro del `CATCH`:

| Función | Devuelve |
|---|---|
| `ERROR_NUMBER()` | Número del error |
| `ERROR_MESSAGE()` | Mensaje |
| `ERROR_SEVERITY()` | Severidad |
| `ERROR_STATE()` | Estado |
| `ERROR_LINE()` | Línea donde ocurrió |
| `ERROR_PROCEDURE()` | Procedimiento o trigger |

**Ventaja:** el código de limpieza (`ROLLBACK`) queda en un solo lugar. **Cuidado:** `TRY/CATCH` no captura todos los errores; por ejemplo, algunos errores de compilación o de conexión no entran al `CATCH`.

### 2.2 `XACT_ABORT`

`SET XACT_ABORT` controla qué hace SQL Server ante un error de ejecución.

| Valor | Comportamiento |
|---|---|
| `OFF` (default) | Algunos errores abortan solo la instrucción; la transacción puede seguir abierta y ser confirmable. |
| `ON` | Un error de ejecución aborta el batch y deja la transacción en estado no confirmable; el `CATCH` debe hacer `ROLLBACK`. |

**Recomendación:** usar `SET XACT_ABORT ON` al inicio de procedimientos que modifican datos. Evita que un error intermedio deje una transacción abierta y que el cliente confirme datos parciales.

**Ejemplo del script:** el demo 3 usa `SET XACT_ABORT ON`. La violación de FK deja `XACT_STATE() = -1` y `@@TRANCOUNT = 1` dentro del `CATCH`; después del `ROLLBACK`, ambos vuelven a `0`.

> `XACT_ABORT ON` no reemplaza al `TRY/CATCH`: conviene combinarlos. El `CATCH` hace el `ROLLBACK` explícito y relanza el error con `THROW`.

### 2.3 `XACT_STATE`

`XACT_STATE()` indica si la sesión tiene una transacción activa y si esa transacción se puede confirmar.

| Valor | Significado | Acción recomendada |
|---|---|---|
| `0` | No hay transacción activa | Nada |
| `1` | Hay transacción activa y confirmable | Se puede `COMMIT` o `ROLLBACK` |
| `-1` | Hay transacción activa pero no confirmable | Solo `ROLLBACK`; no se puede `COMMIT` |

Patrón típico:

```sql
BEGIN CATCH
    DECLARE @estado INT = XACT_STATE();

    IF @estado = -1
        PRINT 'Transaccion no confirmable: se debe hacer ROLLBACK';

    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
```

**Ejemplo del script:**

- Demo 2 (error de negocio con `THROW 50004`, `XACT_ABORT OFF`): `XACT_STATE() = 1` y `@@TRANCOUNT = 1` en el `CATCH`; el `ROLLBACK` deja `0 / 0`.
- Demo 3 (violación de FK con `XACT_ABORT ON`): `XACT_STATE() = -1` y `@@TRANCOUNT = 1` en el `CATCH`; el `ROLLBACK` deja `0 / 0`.

### 2.4 `THROW` y `RAISERROR`

| Característica | `THROW` | `RAISERROR` |
|---|---|---|
| Relanza el error original | Sí, con `THROW;` | No directamente |
| Requiere número/mensaje | No si se usa `THROW;` | Sí |
| Respeta `SET XACT_ABORT` | Sí | Sí |
| Uso recomendado | Código nuevo | Compatibilidad con código antiguo |

En el script se usa `THROW 50004, '...', 1` para errores de negocio y `THROW;` para relanzar el error original de la FK.

### 2.5 Patrón recomendado para X Motors

```sql
CREATE OR ALTER PROCEDURE dbo.sp_registrar_venta
    -- parametros...
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1. Validar y bloquear stock
        -- 2. Insertar venta
        -- 3. Insertar detalle
        -- 4. Descontar stock
        -- 5. Actualizar estado del cliente

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH;
END;
```

---

## 3. `SAVE TRANSACTION`

`SAVE TRANSACTION` crea un **punto de guardado** dentro de una transacción. Permite revertir solo una parte de las operaciones, sin perder todo lo anterior.

```sql
BEGIN TRANSACTION;

INSERT INTO dbo.venta (...) VALUES (...);  -- parte que quiero conservar

SAVE TRANSACTION antes_del_detalle;

BEGIN TRY
    INSERT INTO dbo.detalle_venta_accesorio (...) VALUES (...);
    UPDATE dbo.accesorio SET stock = stock - 1 WHERE id_accesorio = 1;
END TRY
BEGIN CATCH
    ROLLBACK TRANSACTION antes_del_detalle;  -- solo deshace el detalle
    PRINT 'No se pudo agregar el accesorio: ' + ERROR_MESSAGE();
END CATCH;

-- La venta sigue existiendo; se puede decidir si se confirma o no.
COMMIT TRANSACTION;
```

### Características importantes

- `SAVE TRANSACTION` **no** confirma nada: solo marca un punto.
- `ROLLBACK TRANSACTION <savepoint>` deshace los cambios posteriores al punto, pero **no** termina la transacción.
- `@@TRANCOUNT` **no cambia** al crear un savepoint.
- Si se hace `ROLLBACK TRANSACTION` sin nombre, se revierte toda la transacción y se termina.
- Los savepoints no se comparten entre sesiones.
- Si la transacción queda no confirmable (`XACT_STATE() = -1`), no alcanza con volver a un savepoint: hay que hacer `ROLLBACK` completo.
- Los savepoints son útiles para operaciones opcionales, como agregar accesorios a una venta ya creada.

**Relación con X Motors:** se podría usar un savepoint para intentar agregar un accesorio y, si no hay stock, revertir solo ese accesorio sin perder la venta de la moto. En el flujo principal se prefiere validar todo antes de insertar, para no dejar una venta sin accesorios por un error evitable.

---

## 4. Niveles de aislamiento

El nivel de aislamiento define qué lecturas puede hacer una transacción mientras otras modifican datos. A más aislamiento, menos anomalías, pero más bloqueos y menos concurrencia.

### 4.1 Anomalías

| Anomalía | Qué ocurre |
|---|---|
| **Lectura sucia** (*dirty read*) | Una transacción lee datos modificados por otra que todavía no confirmó. |
| **Lectura no repetible** (*non-repeatable read*) | Una transacción lee una fila, otra la modifica y confirma, y la primera vuelve a leer un valor distinto. |
| **Lectura fantasma** (*phantom read*) | Una transacción lee un conjunto de filas, otra inserta/borra filas que cumplen el filtro y la primera ve un conjunto distinto. |
| **Actualización perdida** (*lost update*) | Dos transacciones leen el mismo valor y ambas escriben; una sobrescribe a la otra. |

### 4.2 Niveles en SQL Server

| Nivel | Lectura sucia | Lectura no repetible | Fantasma | Comportamiento general |
|---|---|---|---|---|
| `READ UNCOMMITTED` | Sí | Sí | Sí | No toma bloqueos compartidos; usa `NOLOCK` o equivalente. |
| `READ COMMITTED` (default) | No | Sí | Sí | Solo lee datos confirmados; libera bloqueos al terminar la instrucción. |
| `REPEATABLE READ` | No | No | Sí | Mantiene bloqueos compartidos hasta el final de la transacción. |
| `SERIALIZABLE` | No | No | No | Bloqueos de rango; máximo aislamiento, mínima concurrencia. |
| `SNAPSHOT` | No | No | No | Lee una versión consistente al inicio de la transacción; requiere row versioning. |

SQL Server también permite `READ COMMITTED SNAPSHOT` a nivel de base: mantiene el nivel `READ COMMITTED`, pero las lecturas usan versiones en `tempdb` en lugar de bloquear. Es útil para reportes, pero no elimina las carreras de actualización; para el stock se sigue necesitando un bloqueo o una validación atómica.

### 4.3 Elección para X Motors

Para la venta se usa:

```sql
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
```

y se refuerza la sección crítica con bloqueos explícitos:

```sql
SELECT @stock = stock_disponible
FROM dbo.modelo_motocicleta WITH (UPDLOCK, HOLDLOCK)
WHERE id_modelo = 11;
```

¿Por qué no `SERIALIZABLE` para todo?

- `SERIALIZABLE` reduce la concurrencia y aumenta los deadlocks.
- El conflicto real está en la fila de stock del modelo y en el chasis; `UPDLOCK, HOLDLOCK` sobre esas filas alcanza para serializar la operación.
- Para reportes se puede usar `READ COMMITTED` o `SNAPSHOT` según la necesidad de consistencia y el costo de `tempdb`.

---

## 5. Bloqueos

### 5.1 Tipos de bloqueo

| Bloqueo | Símbolo | Uso |
|---|---|---|
| Compartido | `S` | Lectura; varias sesiones pueden leer a la vez. |
| Exclusivo | `X` | Modificación; impide otras lecturas/escrituras. |
| Actualización | `U` | Intención de actualizar; evita conversiones muertas de `S` a `X`. |
| Intención | `IS`, `IX`, `SIX` | Indica que se bloqueará una fila/página dentro de un objeto mayor. |
| Esquema | `Sch-S`, `Sch-M` | Protege el esquema durante compilación o DDL. |
| Rango | `RangeS`, `RangeX` | Protege rangos en `SERIALIZABLE`. |

### 5.2 Granularidad

SQL Server puede bloquear a nivel de fila, página, extensión, tabla o base. Empieza fino y puede escalar si hay demasiados bloqueos. La escalada reduce overhead, pero aumenta la contención.

### 5.3 Sugerencias de bloqueo

| Sugerencia | Efecto |
|---|---|
| `ROWLOCK` | Fuerza bloqueo de fila. |
| `UPDLOCK` | Toma bloqueo de actualización al leer. |
| `HOLDLOCK` | Equivale a `SERIALIZABLE` para esa tabla/consulta; mantiene el bloqueo hasta el final de la transacción. |
| `READPAST` | Salta filas bloqueadas; útil para colas, no para stock. |
| `NOLOCK` | No toma bloqueos compartidos; permite lecturas sucias. **No usar para stock ni montos.** |

### 5.4 Bloqueos en el script

El demo 1 usa:

```sql
SELECT @stock = stock_disponible
FROM dbo.modelo_motocicleta WITH (UPDLOCK, HOLDLOCK)
WHERE id_modelo = 11;
```

- `UPDLOCK` evita que dos sesiones lean el mismo stock y luego intenten actualizarlo a la vez.
- `HOLDLOCK` mantiene el bloqueo hasta el `COMMIT`/`ROLLBACK`, no solo hasta el final de la instrucción.
- El bloqueo se libera al confirmar o revertir la transacción.

### 5.5 Deadlocks

Un deadlock ocurre cuando dos sesiones se bloquean mutuamente y ninguna puede avanzar. SQL Server elige una como víctima y la termina con el error 1205.

Prevención:

1. **Orden consistente de bloqueo:** bloquear siempre `modelo_motocicleta` → `motocicleta` → `accesorio` (por `id_accesorio`) → `venta`.
2. Transacciones cortas: no abrir una transacción y esperar interacción del usuario.
3. Índices adecuados: menos filas leídas, menos bloqueos.
4. Reintentar la transacción víctima con lógica de retry.
5. Usar `SET DEADLOCK_PRIORITY` solo si se necesita que una sesión ceda primero.

Monitoreo:

```sql
-- Bloqueos actuales
SELECT * FROM sys.dm_tran_locks;

-- Sesiones que esperan
SELECT * FROM sys.dm_exec_requests WHERE blocking_session_id <> 0;

-- Información general
EXEC sp_who2;
```

### 5.6 Buenas prácticas para X Motors

- No usar `NOLOCK` para leer stock, precios o montos.
- Bloquear el stock con `UPDLOCK, HOLDLOCK`.
- Validar y descontar en la misma transacción.
- Mantener el orden de bloqueo entre procedimientos.
- Reintentar solo errores transitorios (deadlock 1205, timeout), no errores de negocio.
- Registrar el error y hacer `ROLLBACK` antes de relanzar.

---

## 6. Resumen

| Concepto | Idea clave |
|---|---|
| ACID | Atomicidad, consistencia, aislamiento y durabilidad. |
| `BEGIN TRAN` / `COMMIT` / `ROLLBACK` | Delimitan la unidad transaccional. |
| `TRY/CATCH` | Centraliza el manejo de errores y el `ROLLBACK`. |
| `XACT_ABORT ON` | Aborta el batch y deja la transacción no confirmable ante errores de ejecución. |
| `XACT_STATE()` | `0` sin transacción, `1` confirmable, `-1` no confirmable. |
| `SAVE TRANSACTION` | Punto de guardado para revertir solo una parte. |
| Nivel de aislamiento | `READ COMMITTED` por defecto; `SERIALIZABLE`/`SNAPSHOT` según necesidad. |
| Bloqueos | `UPDLOCK, HOLDLOCK` para stock; orden consistente para evitar deadlocks. |

---

## 7. Referencias

- Microsoft Learn — *Transactions (Transact-SQL)*: <https://learn.microsoft.com/sql/t-sql/language-elements/transactions-transact-sql>
- Microsoft Learn — *SET XACT_ABORT*: <https://learn.microsoft.com/sql/t-sql/statements/set-xact-abort-transact-sql>
- Microsoft Learn — *TRY...CATCH*: <https://learn.microsoft.com/sql/t-sql/language-elements/try-catch-transact-sql>
- Microsoft Learn — *XACT_STATE*: <https://learn.microsoft.com/sql/t-sql/functions/xact-state-transact-sql>
- Microsoft Learn — *SAVE TRANSACTION*: <https://learn.microsoft.com/sql/t-sql/language-elements/save-transaction-transact-sql>
- Microsoft Learn — *SET TRANSACTION ISOLATION LEVEL*: <https://learn.microsoft.com/sql/t-sql/statements/set-transaction-isolation-level-transact-sql>
- Microsoft Learn — *SQL Server transaction locking and row versioning guide*: <https://learn.microsoft.com/sql/relational-databases/sql-server-transaction-locking-and-row-versioning-guide>
- Microsoft Learn — *THROW*: <https://learn.microsoft.com/sql/t-sql/language-elements/throw-transact-sql>
- Microsoft Learn — *RAISERROR*: <https://learn.microsoft.com/sql/t-sql/language-elements/raiserror-transact-sql>
