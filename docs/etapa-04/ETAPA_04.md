# Etapa IV: Consultas y Casos de Uso

**Sistema de Gestión de Ventas de Motos — "X Motors"** · Base de Datos I · Grupo 49 · FaCENA (UNNE)

> Pregunta central: **¿Cómo obtenemos información de valor para el negocio?**

---

## 1. Integrantes

Rodriguez Rivas Milton Nahuel · Zacarías Blanco Fernando Iván · Balenzuela Tobías · Veglia Marcos Daniel · Zarate Arturo Alan

---

## 2. Objetivo

Implementar en **SQL Server** las consultas que resuelven los casos de uso de información del sistema, demostrando dominio de:

- **Consultas parametrizadas** (factura por `cod_venta`)
- **Agregaciones y reportes** (`GROUP BY`, `SUM`, `COUNT`, `HAVING`)
- **Consultas avanzadas** (≥3 `JOIN` + subconsultas / `HAVING`)

---

## 3. Archivos y ejecución

| Archivo | Contenido | Requisito cubierto |
|---|---|---|
| `01_factura.sql` | Factura completa: cabecera (cliente, vendedor, moto), detalle (moto + accesorios), totales + auditoría de integridad | Factura/comprobante con subtotales y total |
| `02_reporte_agregado.sql` | 3 reportes: ventas por vendedor, ventas por modelo, accesorios más vendidos (con filtros de fecha opcionales) | Reporte agregado (`GROUP BY`, `SUM`, `COUNT`) |
| `03_avanzada.sql` | 2 consultas: clientes recurrentes (HAVING), cotizaciones vencidas sin concretar (NOT EXISTS) | Consulta avanzada (≥3 JOIN + HAVING/subconsultas) |

**Orden:** Ejecutar sobre la base `[X MOTORS]` ya poblada con el DML de Etapa III.

---

## 4. Descripción de cada consulta

### 4.1 `01_factura.sql` — Factura / Comprobante de Venta

**Parámetro:** `@cod_venta` (INT)

**Estructura (4 bloques en un solo batch):**

1. **Encabezado** — Datos de la transacción, cliente (con dirección completa), vendedor, resumen de la moto, monto total guardado.
2. **Detalle motocicleta** — Chasis, motor, marca, modelo, cilindrada, color, año, precio congelado (`precio_venta_moto`).
3. **Detalle accesorios** — Descripción, categoría, cantidad, precio pactado, subtotal por línea (ordenados alfabéticamente).
4. **Verificación de integridad** — CTE `AccesoriosCalculados` computa el total de accesorios con precisión `DECIMAL(12,2)` y compara: `precio_venta_moto + total_accesorios = monto_total`. Devuelve `OK` o `DIFERENCIA`.

**Reglas de negocio cubiertas:** RN6 (precio congelado), RN10 (1 moto + 0..N accesorios), RN11 (montos consistentes).

---

### 4.2 `02_reporte_agregado.sql` — Reportes de Gestión

**Parámetros opcionales:** `@fecha_desde` (DATE), `@fecha_hasta` (DATE) — `NULL` = sin filtro.

| Reporte | Descripción | Métricas clave |
|---|---|---|
| **Ventas por vendedor** | Ranking de vendedores por facturación | Total ventas, monto total, ticket promedio |
| **Ventas por modelo** | Performance de cada modelo | Unidades vendidas, monto total, precio promedio, stock actual |
| **Accesorios más vendidos** | Demanda de accesorios | Cantidad total, ingreso total, precio promedio pactado, stock actual |

**Reglas de negocio cubiertas:** RN1/RN2 (stock), RN9 (vendedor responsable), RN10 (accesorios opcionales).

---

### 4.3 `03_avanzada.sql` — Análisis Avanzado de Negocio

#### Consulta 1: Clientes Recurrentes (Fidelización / VIP)
- **JOINs:** 5 (`persona → cliente → venta → motocicleta → modelo_motocicleta`)
- **Cláusula avanzada:** `HAVING COUNT(v.cod_venta) > 1`
- **Métricas:** Total motos compradas, monto histórico, ticket promedio, primera/última compra
- **Regla negocio:** RN4 (historial múltiples compras)
- **Uso:** Programa de fidelización, segmentación VIP

#### Consulta 2: Cotizaciones Vencidas Sin Concretar (Oportunidades Perdidas)
- **JOINs:** 4 (`persona → cliente → cotizacion → modelo_motocicleta`) + subconsulta correlacionada
- **Cláusula avanzada:** `NOT EXISTS` (subconsulta verifica si compró ese modelo)
- **Filtros:** Cotización vencida (`fecha_vencimiento < GETDATE()`) + cliente en estado `interesado` o `en proceso de compra` (RN5)
- **Métricas:** Días desde vencimiento, modelo cotizado, precio cotizado vs precio lista actual, diferencia
- **Regla negocio:** RN12 (cotización 7 días) + RN5 (estado cliente)
- **Uso:** Acción comercial proactiva, recuperación de leads

---

## 5. Decisiones de diseño

| Tema | Decisión |
|---|---|
| **Variable `@cod_venta`** | Declarada una sola vez al inicio del batch (sin `GO` entre SELECTs) para que persista |
| **Precisión monetaria** | `CAST(... AS DECIMAL(12,2))` en todos los cálculos de precios/subtotales |
| **Fechas** | `GETDATE()` para comparar vencimientos en tiempo real (consulta 2 de `03_avanzada.sql`) |
| **Filtros de fecha** | Opcionales (`NULL` = sin filtro) en reportes agregados para flexibilidad |
| **LEFT JOIN** | Usados para incluir items sin movimiento (modelos sin vender, accesorios sin vender) |
| **Auditoría** | Factura valida integridad `monto_total` vs suma calculada (detección temprana de bugs) |

---

## 6. Pruebas realizadas

| Consulta | Caso de prueba | Resultado |
|---|---|---|
| `01_factura.sql` | Venta 1 (con accesorios) | OK — subtotales coinciden, auditoría = OK |
| `01_factura.sql` | Venta 10 (sin accesorios) | OK — accesorios = 0, auditoría = OK |
| `01_factura.sql` | Venta 4 (cancelada) | OK — muestra estado cancelada, montos registrados |
| `02_reporte_agregado.sql` | Sin filtros | OK — 8 vendedores, 10 modelos, 10 accesorios listados |
| `02_reporte_agregado.sql` | Con `@fecha_desde='2026-06-01'` | OK — solo ventas desde junio |
| `03_avanzada.sql` Consulta 1 | Datos actuales | OK — devuelve clientes con >1 compra (ej. DNI 30456781, 35123903) |
| `03_avanzada.sql` Consulta 2 | Datos actuales | OK — devuelve cotizaciones vencidas de clientes sin compra |

---

## 7. Entregables

- [x] `sql/consultas/01_factura.sql` — Factura parametrizada con auditoría
- [x] `sql/consultas/02_reporte_agregado.sql` — 3 reportes de gestión con filtros de fecha
- [x] `sql/consultas/03_avanzada.sql` — 2 consultas avanzadas (HAVING + NOT EXISTS)
- [x] `docs/etapa-04/ETAPA_04.md` — Esta documentación

**Fecha de entrega:** **16 de octubre de 2026** · GitHub · Manifiesto individual por AV Moodle.