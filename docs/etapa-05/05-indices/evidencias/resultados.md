# Resultados — Tema 5: Optimización de consultas (índices)

**Sistema de Gestión de Ventas de Motos — "X Motors"** · Base de Datos I · Grupo 49 · FaCENA (UNNE) · Etapa V

Entorno: **SQL Server 2025 Express** bajo Docker (contenedor `sqlserver`), base `[X MOTORS]`, ejecución del 01/11/2026.

---

## 1. Medición sobre el lote de datos de la Etapa III (pequeño volúmen)

Resumen del ANTES/DESPUÉS sobre las 10 tablas de negocio: ver la tabla completa en
[`investigacion.md` §4](../investigacion.md) y la trazabilidad fila por fila en
[`01_indices_antes_despues.txt`](01_indices_antes_despues.txt).

**Conclusión honesta:** con 30-40 filas por tabla el efecto real de los índices no se ve
(escaneos de 2-9 páginas); los índices quedan creados y el optimizador usa los que le convienen.

## 2. Prueba de escala exigida por la consigna v2 (+1.000.000 de filas)

La consigna pide una tabla de pruebas con **más de un millón de registros** comparando tres
escenarios de acceso. Se ejecutó conforme:

1. `02_indices_mass_load.sql` — carga masiva de **1.000.000 de filas** en una sola sentencia
   (sin inserciones a mano), evidencia en [`02_indices_mass_carga.txt`](02_indices_mass_carga.txt).
2. `03_indices_mass_mediciones.sql` — los tres escenarios con `SHOWPLAN_TEXT` + `STATISTICS IO/TIME`,
   evidencia en [`03_indices_mass_mediciones.txt`](03_indices_mass_mediciones.txt).

### Tabla comparativa final (rango `fecha_venta BETWEEN '2023-01-01' AND '2023-03-31'`)

| Escenario | Tiempo CPU (ms) | Tiempo total (ms) | Lecturas lógicas | Operación principal |
|---|---|---|---|---|
| Sin índice | 107 | 111 | 3.585 | Table Scan |
| Índice agrupado sobre fecha | 9 | 9 | 230 | Clustered Index Seek |
| Índice con cobertura | 9 | 9 | 162 | Index Seek |

`venta_historica_prueba`: 1.000.000 filas cargadas. Consulta filtra **49.393 filas**.

### Resultados esperados (verificados contra la consigna v2)

1. ✅ La consulta sin índices requirió analizar una gran cantidad de registros: `Table Scan`
   con **3.585 lecturas lógicas** (toda la tabla).
2. ✅ El índice sobre la fecha redujo significativamente el trabajo del motor:
   `Clustered Index Seek` con **230 lecturas** (codo del rango, + localización de filas).
3. ✅ El índice con cobertura disminuyó aún más las lecturas: `Index Seek` puro, **162 lecturas**,
   sin acceder a la tabla ni hacer lookup (la consulta literal del escenario 3 solo pide
   `fecha_venta, importe`, todas presentes en el índice).
4. ✅ Los planes de ejecución capturados muestran el cambio esperado:
   `Table Scan` → `Clustered Index Seek` → `Index Seek`.

### Sanity checks

- `idx_previos = 0` al comenzar (punto de partida limpio).
- `filas_filtradas = 49.393` e `importe_total` **idénticos** en los tres escenarios:
  los datos no se modificaron entre corridas.
- El índice creado para el escenario 3 (`ix_venta_historica_prueba_cobertura`) queda activo al final;
  la tabla de pruebas es desechable y no integra el modelo de negocio.

## 3. Convenciones de la ejecución

- Scripts idempotentes: la tabla se dropea/recrea, los índices con `DROP INDEX IF EXISTS`.
- Las capturas incluyen `@@VERSION`, base, usuario y fecha/hora al inicio de cada evidencia.
- Los valores absolutos de tiempo dependen del hardware; las **lecturas lógicas** son la métrica estable.
