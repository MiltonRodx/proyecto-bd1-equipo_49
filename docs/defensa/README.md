# Defensa individual — X Motors (Etapa V)

Material listo para la defensa individual: 1 tema al azar, 3-4 minutos,
en la computadora, sin presentaciones. Para cada tema hay un **demo SQL**
(que se ejecuta con F5 y deja la base como estaba) y un **guion hablado**.

## Orden recomendado de estudio

1. **Guion 1** (procedimientos) — es la base: `sp_RegistrarVentaCompleta` vuelve a aparecer en transacciones y en seguridad.
2. **Guion 2** (transacciones) — reutiliza ese SP; entender la atomicidad de la venta.
3. **Guion 3** (triggers) — la auditoría registra lo que hacen los SPs.
4. **Guion 4** (seguridad) — los vendedores solo operan por los SPs del tema 1.
5. **Guion 5** (índices) — tema más independiente; memorizar la tabla 3585 → 230 → 162 lecturas de la prueba de escala.

Si te toca un tema al azar, es probable que el profesor pida relación con otro:
los puntos de contacto están anotados en cada guion.

## Qué abrir en cada pestaña antes de la defensa

| Pestaña | Contenido |
|---|---|
| 1 | `docs/defensa/demo_01..05` (5 archivos, uno por tema) |
| 2 | `docs/etapa-05/01-procedimientos-funciones/02_procedimientos.sql` (ir a las líneas del guion 1 y 2) |
| 3 | `docs/etapa-05/02-transacciones/02_sp_cambiar_estado_venta.sql` (guion 2) |
| 4 | `docs/etapa-05/03-triggers-auditoria/02_..sql` y `03_..sql` (guion 3) |
| 5 | `docs/etapa-05/04-seguridad/01_seguridad.sql` (guion 4) |
| 6 | `docs/etapa-05/05-indices/01_indices.sql` + `evidencias/resultados.md` (guion 5) |
| 7 | Pestaña **Mensajes** visible junto a Resultados (para STATISTICS IO y errores) |

## Checklist previo (10 minutos)

- [ ] Base `[X MOTORS]` con DDL + DML de las etapas I-IV (`sql/ddl/`, `sql/dml/`).
- [ ] Ejecutados, en orden: `01_funciones.sql`, `02_procedimientos.sql` (tema 1),
      `02_sp_cambiar_estado_venta.sql` (tema 2), `01..04` de `03-triggers-auditoria` (tema 3),
      `01_seguridad.sql` (tema 4), `01_indices.sql` (tema 5).
- [ ] Conexión probada: `SELECT COUNT(*) FROM dbo.venta;` → devuelve filas (anotar cuántas para comparar después).
- [ ] Correr una vez `demo_02_transacciones.sql` completo para dejar la base lista y confirmar que no hay errores.

## Datos que usan los demos (todos del lote real del DML)

- Cliente `42111222` (Nicolás Duarte, estado `interesado`) — sin ventas, descuento 0.
- Vendedor `31222333` (Ana Villalba).
- Moto `9C2HON00000000002` (modelo 1: Honda CB 125F Twister, stock 1) — sin venta `efectuada`.
  El precio de lista del modelo 1 puede variar si el lote fue actualizado; el demo muestra el que esté en la base.
  Verificar con: `SELECT precio_lista FROM dbo.modelo_motocicleta WHERE id_modelo = 1;`
- Accesorio `1` (Casco integral ABS, stock 11, lista $185.000).
- Si tu lote difiere (otro DML), revisar estos valores antes de correr.

## Advertencias

- Los demos 1 y 2 **borran su venta demo al final** (limpieza explícita); si quedan filas
  en `auditoria_venta` es intencional: la auditoría no se borra (convención del proyecto).
- El demo 3 usa `ROLLBACK`: deja la base idéntica.
- El demo 4 requiere `01_seguridad.sql` (los roles son permanentes; el aviso te dice si falta).
- El demo 5 solo hace SELECTs.
