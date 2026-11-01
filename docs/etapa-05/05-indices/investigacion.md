# Tema 5 — Optimización de consultas (índices)

**Sistema de Gestión de Ventas de Motos — "X Motors"**
Base de Datos I · Grupo 49 · FaCENA (UNNE) · Etapa V

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

`01_indices.sql` crea los 10 índices declarados en el contrato (`docs/etapa-05/README.md` §3.6), con guard `IF NOT EXISTS` sobre `sys.indexes`, columnas explícitas en la clave e `INCLUDE` para las columnas cubiertas.

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

- Script: [`01_indices.sql`](01_indices.sql)
- Consultas de medición: [`evidencias/01_indices_consultas.sql`](evidencias/01_indices_consultas.sql)
- Evidencia ANTES/DESPUÉS completa (incluye el `DROP` inicial, la corrida sin índices, la corrida con índices y las DMVs): [`evidencias/01_indices_antes_despues.txt`](evidencias/01_indices_antes_despues.txt)

Las 10 tablas quedan con sus índices y **ninguna consulta de Etapa IV cambió de comportamiento externo**: los resultados de las mismas son idénticos antes y después.
