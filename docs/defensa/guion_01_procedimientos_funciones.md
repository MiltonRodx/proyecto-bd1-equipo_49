# Guion 1 — Procedimientos y funciones (3 min)

## Guion hablado

> "Un **procedimiento almacenado** es un programa que queda guardado adentro de la base de datos y se ejecuta con un `EXEC`; una **función** recibe parámetros y devuelve un valor, y se puede usar dentro de consultas.
>
> El problema que resuelve en X Motors: registrar una venta toca cinco cosas — la cabecera de la venta, el detalle de accesorios, el stock de la moto, el stock de los accesorios y el estado del cliente. Si cada paso lo escribe una persona a mano, en algún momento alguien olvida uno y la base queda inconsistente. Con `sp_RegistrarVentaCompleta` todo eso pasa en **una sola llamada**, con todas las validaciones adentro.
>
> Las funciones encapsulan las reglas de cálculo: `fn_descuento_cliente` mira el monto acumulado de ventas 'efectuada' y devuelve 10% si superó 10 millones, 5% si superó 5 millones, o 0. `fn_precio_con_descuento` aplica ese porcentaje **solo al precio de la moto**, nunca al total.
>
> [Ejecutar demo_01] Acá muestro dos cosas: primero un caso de error — pido método de pago 'bitcoin' y el SP lo rechaza con el error 50011 **antes** de tocar nada. Y después el caso feliz: una sola llamada crea la venta completa — precio de la moto más el casco —, descuenta stock y el cliente pasa a estado 'comprador'. Al final el demo limpia todo para poder repetirlo."

## Líneas clave a señalar (abrir en pestañas)

| Archivo | Líneas | Qué mostrar |
|---|---|---|
| `docs/etapa-05/01-procedimientos-funciones/01_funciones.sql` | 140-160 | `fn_descuento_cliente`: los `WHEN > 10000000 / > 5000000` (líneas 155-159) |
| `docs/etapa-05/01-procedimientos-funciones/02_procedimientos.sql` | 199-224 | Validaciones de entrada del SP: cliente/vendedor/método de pago con `THROW` |
| `docs/etapa-05/01-procedimientos-funciones/02_procedimientos.sql` | 309-314 | El `INSERT INTO dbo.venta` (la venta nace 'efectuada') |
| `docs/etapa-05/01-procedimientos-funciones/02_procedimientos.sql` | 326-335 | Descuento de stock: `WHERE ac.stock >= a.cantidad` chequea y descuenta en la misma sentencia |

## Preguntas probables del profesor

1. **¿Diferencia entre procedimiento y función?** → El SP se ejecuta con `EXEC` y puede modificar datos; la función devuelve un valor y se usa dentro de un `SELECT` (no puede modificar datos).
2. **¿Por qué el descuento se aplica solo a la moto?** → Regla de negocio del enunciado: el porcentaje se aplica sobre `precio_venta_moto`, nunca sobre `monto_total`.
3. **¿Qué pasa si paso un método de pago inválido?** → `THROW 50011` en la validación de entrada, antes de abrir la transacción: no queda nada a medias.
4. **¿Qué devuelve `fn_descuento_cliente` si el cliente no existe?** → `NULL` (por eso en el SP se hace `ISNULL(..., 0)`).
5. **¿Es reutilizable?** → Sí: `sp_generar_cotizacion` reutiliza esas dos funciones para armar presupuestos con validez de 7 días (RN12).

## Glosario mínimo

- **Procedimiento almacenado (SP):** programa T-SQL guardado en la base, se llama con `EXEC`.
- **Función escalar:** devuelve un solo valor (ej: un precio con descuento).
- **Función con valor de tabla (inline):** devuelve una tabla (`fn_resumen_cliente`).
- **THROW:** lanza un error con número y mensaje propio (nosotros usamos 50001-50019, uno por regla de negocio).
- **@@ROWCOUNT:** cantidad de filas que afectó la última sentencia (lo usamos para detectar "no actualizó nada").
- **Parámetro OUTPUT:** valor que el SP devuelve al que lo llama (ej: el `@cod_venta` creado).
