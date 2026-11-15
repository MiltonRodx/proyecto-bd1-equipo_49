# Guion 5 — Índices y optimización (3 min)

## Guion hablado

> "Un **índice** es una estructura ordenada — un árbol B — que le permite al motor encontrar las filas sin recorrer la tabla completa. En SQL Server hay dos tipos: el **clustered** es el orden físico de la tabla (una por tabla) y los **nonclustered** son estructuras aparte que apuntan a las filas.
>
> El problema en X Motors: los reportes filtran `venta` por fecha y estado, o por cliente. Sin índice el motor hace un **table scan**: lee la tabla entera. Con índice hace un **index seek**: va directo a las filas del rango.
>
> [Ejecutar demo_05] El demo hace tres cosas. Uno — lista los índices sobre `venta`, están construidos por las columnas del filtro y con `INCLUDE` de las columnas que el reporte lee, así el seek no tiene que ir a buscar nada a la tabla. Dos — con `SET STATISTICS IO` muestra los *logical reads* en la pestaña Mensajes: la cantidad de páginas que leyó. Tres — fuerza el índice con un hint para comparar. Un detalle honesto: con 30 filas el optimizador a veces elige el scan, porque leer 30 filas a mano es más barato que abrir el árbol del índice. Por eso hicimos la **prueba de escala**: cargamos un millón de filas en `venta_historica_prueba` y ahí la diferencia es real: sin índice 3585 lecturas y 107 ms; con índice clusterizado 230 lecturas y 9 ms; con el índice de cobertura, 162 lecturas. Table Scan → Clustered Index Seek → Index Seek con cobertura."

## Líneas clave a señalar (abrir en pestañas)

| Archivo | Líneas | Qué mostrar |
|---|---|---|
| `docs/etapa-05/05-indices/01_indices.sql` | 20-24 | `ix_venta_fecha_estado`: clave `(fecha, estado)` + `INCLUDE (monto_total, ...)` |
| `docs/etapa-05/05-indices/01_indices.sql` | 27-31 | `ix_venta_cliente_fecha`: historial por cliente |
| `docs/etapa-05/05-indices/evidencias/resultados.md` | 32-34 | Tabla de la prueba de 1M de filas: 3585 → 230 → 162 lecturas |
| `docs/etapa-05/05-indices/02_indices_mass_load.sql` | (abrir) | Carga de 1.000.000 de filas en una sola sentencia |

## Preguntas probables del profesor

1. **¿Clustered vs nonclustered?** → Clustered define el orden físico de la tabla (una por tabla); nonclustered es una estructura aparte con punteros a las filas (varias por tabla). En el plan se ve `Clustered Index Seek` vs `Index Seek`.
2. **¿Qué es INCLUDE?** → Columnas extra guardadas en el índice pero que no forman parte del orden. Sirven para que el índice sea de **cobertura**: el reporte lee todo del índice y no visita la tabla (`Index Seek` puro).
3. **¿Por qué con pocas filas el optimizador ignora el índice?** → Costo: estimar que leer 30 filas linealmente es más barato que buscar en el árbol. El índice se justifica con volumen.
4. **¿Qué son logical reads?** → Cantidad de páginas (8 KB) leídas desde el buffer pool; la métrica que compara queries con `SET STATISTICS IO`.
5. **¿Qué es el table scan vs index seek?** → Scan = leer todo; seek = entrar directo al punto del árbol.
6. **¿Los índices tienen costo?** → Sí: ocupan espacio y cada INSERT/UPDATE debe mantenerlos; por eso creamos los que cubren los reportes reales, no 20 al azar.

## Glosario mínimo

- **Índice (árbol B):** estructura ordenada para buscar sin recorrer todo.
- **Clustered:** define el orden físico; la tabla misma.
- **Nonclustered:** estructura aparte con punteros a las filas.
- **Index seek / scan:** buscar directo / recorrer completo.
- **Covering index (INCLUDE):** índice que contiene todas las columnas que la consulta necesita.
- **Logical reads:** páginas de 8 KB leídas en memoria (métrica de `STATISTICS IO`).
- **Plan de ejecución (Ctrl+M):** el camino que eligió el optimizador.
