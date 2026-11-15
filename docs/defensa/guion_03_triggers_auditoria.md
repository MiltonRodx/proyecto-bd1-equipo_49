# Guion 3 — Triggers y auditoría (3 min)

## Guion hablado

> "Un **trigger** es un bloque de código que la base ejecuta **solo**, cuando alguien hace un `INSERT`, `UPDATE` o `DELETE` sobre una tabla. Nadie lo llama: se dispara solo. Adentro del trigger hay dos tablas temporales: `inserted` trae las filas nuevas y `deleted` las viejas.
>
> El problema que resuelve en X Motors: la consigna pide poder responder 'quién cambió este precio, este estado o este monto, cuándo y con qué valores'. La forma frágil es pedirle a cada aplicación que recuerde escribir el log. La forma correcta es que lo haga la base con triggers: es imposible olvidarlo, porque está del otro lado, en la base.
>
> [Ejecutar demo_03] Todo el demo va dentro de una transacción con `ROLLBACK`, así que la base queda como estaba. Tres casos: uno — actualizo el precio de lista del modelo 1 y **sin llamar a nadie** aparece una fila en `historial_de_precio` con el precio anterior y el nuevo. Además lo ejecuto dos veces con el mismo precio: la segunda no registra nada, porque el trigger compara si el valor cambió de verdad. Dos — hago un `UPDATE` y un `DELETE` sobre `venta` y en `auditoria_venta` aparecen las dos acciones con su usuario y fecha. Tres — cambio el estado de un cliente y queda auditado en `auditoria_cliente`. Después del `ROLLBACK` todo vuelve al estado inicial."

## Líneas clave a señalar (abrir en pestañas)

| Archivo | Líneas | Qué mostrar |
|---|---|---|
| `docs/etapa-05/03-triggers-auditoria/02_trg_historial_precio_modelo.sql` | 19-22 | `AFTER UPDATE` sobre `modelo_motocicleta` |
| `docs/etapa-05/03-triggers-auditoria/02_trg_historial_precio_modelo.sql` | 36-50 | `INSERT ... FROM inserted JOIN deleted`: registra solo si el precio cambió de verdad |
| `docs/etapa-05/03-triggers-auditoria/03_trg_auditoria_venta.sql` | 50-59 | `FULL OUTER JOIN inserted/deleted`: una sola sentencia cubre INSERT, UPDATE y DELETE |
| `docs/etapa-05/03-triggers-auditoria/01_tablas_auditoria.sql` | 32-35 | `usuario` y `fecha_hora` con `DEFAULT USER_NAME()/SYSDATETIME()`: los llena la base, no el trigger |

## Preguntas probables del profesor

1. **¿Qué son `inserted` y `deleted`?** → Tablas lógicas que solo existen dentro del trigger: en un INSERT solo hay `inserted`, en un DELETE solo `deleted`, en un UPDATE hay las dos (`deleted` = antes, `inserted` = después).
2. **¿Trigger AFTER o INSTEAD OF?** → AFTER (o FOR): se ejecuta después de que el cambio ya pasó, solo para registrar. INSTEAD OF reemplazaría la operación.
3. **¿Por qué las tablas de auditoría no tienen claves foráneas?** → Porque la auditoría debe sobrevivir al borrado del dato auditado: si un proveedor se elimina, su auditoría tiene que seguir existiendo (01_tablas_auditoria.sql, comentario inicial).
4. **¿Sirven para varios registros a la vez?** → Sí: están escritos *set-based* con `inserted`/`deleted`, un `UPDATE` de 500 filas genera 500 filas de auditoría en una sola sentencia.
5. **¿Qué pasa si el trigger falla?** → El error deshace la operación que lo disparó (el trigger corre dentro de la transacción de la sentencia).
6. **¿Diferencia entre `historial_de_precio` y `auditoria_venta`?** → `historial_de_precio` es una tabla de **negocio** (RN7: alimenta reportes de evolución de precios); `auditoria_*` son tablas **técnicas** de trazabilidad.

## Glosario mínimo

- **Trigger:** código que se dispara automáticamente ante INSERT/UPDATE/DELETE.
- **inserted / deleted:** tablas virtuales del trigger con las filas nuevas / viejas.
- **AFTER trigger:** se ejecuta tras el cambio; **INSTEAD OF:** lo reemplaza.
- **`UPDATE(col)`:** dentro del trigger, dice si la columna figuró en el SET (aunque el valor no cambie).
- **EXCEPT:** comparación null-safe de dos valores (`NULL vs NULL` = iguales).
- **Set-based:** que trabaja con conjuntos de filas, no fila por fila.
