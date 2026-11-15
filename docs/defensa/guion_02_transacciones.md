# Guion 2 — Transacciones (3 min)

## Guion hablado

> "Una **transacción** es un grupo de operaciones que viajan como una sola unidad: o se confirman todas con `COMMIT`, o no se confirma ninguna con `ROLLBACK`. Esto es la **A de ACID, atomicidad**.
>
> En X Motors el problema es claro: una venta inserta en `venta` y `detalle`, y descuenta el stock de la moto y de los accesorios. Imaginen que la venta se confirma pero al descontar un accesorio no hay stock: quedaría una venta registrada con el stock mal descontado. Con la transacción, ese `ROLLBACK` deshace **todo**.
>
> [Ejecutar demo_02] El demo muestra cuatro momentos. Momento 1: pido 9999 cascos — el SP ya había insertado la venta cuando descubre que no alcanza, y el `ROLLBACK` deja los conteos iguales: no quedó nada. Momento 2: venta correcta — `COMMIT`, stock baja y la venta queda. Momento 3: la cancelación — es el inverso, `sp_cambiar_estado_venta` cambia el estado y devuelve el stock de moto y accesorios en una sola transacción. Momento 4: cancelo **dos veces** — la segunda sale con error 50013 y el stock no se devuelve dos veces, porque el `UPDATE` solo actúa si la venta sigue 'efectuada'.
>
> Dos detalles técnicos: usamos `SET XACT_ABORT ON` para que ante un error grave SQL Server deje la transacción imposible de confirmar, y en el `CATCH` hacemos `ROLLBACK` si `@@TRANCOUNT > 0` y relanzamos con `THROW`. Y para que dos ventas simultáneas no se pisen el stock, bloqueamos la fila del modelo con `UPDLOCK` antes de leerla."

## Líneas clave a señalar (abrir en pestañas)

| Archivo | Líneas | Qué mostrar |
|---|---|---|
| `docs/etapa-05/01-procedimientos-funciones/02_procedimientos.sql` | 241-242 | `BEGIN TRY / BEGIN TRAN` en `sp_RegistrarVentaCompleta` |
| `docs/etapa-05/01-procedimientos-funciones/02_procedimientos.sql` | 356-363 | `CATCH`: `ROLLBACK` + `THROW` (deshace todo y relanza) |
| `docs/etapa-05/02-transacciones/02_sp_cambiar_estado_venta.sql` | 84-89 | `UPDATE ... WHERE estado = 'efectuada'`: chequeo y cambio en la misma sentencia (evita devolver stock dos veces) |
| `docs/etapa-05/02-transacciones/02_sp_cambiar_estado_venta.sql` | 91-103 | Los dos UPDATE de stock + `COMMIT` (los tres cambios viajan juntos) |

## Preguntas probables del profesor

1. **¿Qué garantiza ACID?** → Atomicidad (todo o nada), Consistencia (respeta PK/FK/CHECK), Aislamiento (no veo estados intermedios de otros), Durabilidad (lo confirmado sobrevive a un corte, lo garantiza el transaction log).
2. **¿Qué es `XACT_ABORT ON`?** → Ante un error de ejecución, aborta y deja la transacción **no confirmable** (`XACT_STATE() = -1`): solo se puede `ROLLBACK`. Evita transacciones colgadas a medias.
3. **¿Qué es `@@TRANCOUNT`?** → Contador de transacciones abiertas en la sesión. En el `CATCH` hacemos `ROLLBACK` solo si es `> 0`.
4. **¿Por qué `UPDLOCK`?** → Si dos vendedores venden la última unidad a la vez, ambos podrían leer stock 1. `UPDLOCK` bloquea la fila del modelo al leerla: el segundo espera y después ya no encuentra stock.
5. **¿Por qué no `SERIALIZABLE` para toda la base?** → Mataría la concurrencia y provocaría más deadlocks. El conflicto real es la fila de stock: bloquear solo esa fila alcanza.

## Glosario mínimo

- **COMMIT / ROLLBACK:** confirmar o deshacer la transacción completa.
- **`SET XACT_ABORT ON`:** un error grave deja la transacción no confirmable (obliga al `ROLLBACK`).
- **`XACT_STATE()`:** 0 = sin transacción, 1 = confirmable, -1 = no confirmable.
- **`@@TRANCOUNT`:** cuántas transacciones hay abiertas en la sesión.
- **`UPDLOCK` / `HOLDLOCK`:** hints de bloqueo; `UPDLOCK` toma bloqueo de actualización al leer, `HOLDLOCK` lo mantiene hasta el COMMIT.
- **Deadlock:** dos sesiones se bloquean mutuamente; SQL Server elige una víctima (error 1205).
- **Savepoint (`SAVE TRANSACTION`):** punto de guardado para deshacer solo una parte.
