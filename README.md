# 🏍️ X Motors — Sistema de Gestión de Ventas de Motos · BD1 Grupo 49

[![Etapa V](https://img.shields.io/badge/etapas-I--V%20completas-2EA44F)](#estado-de-las-etapas)
[![SQL Server](https://img.shields.io/badge/SQL%20Server%20Express-2016%20%2B%20·%20verificado%202025-CC2927?logo=microsoftsqlserver&logoColor=white)](#c%C3%B3mo-usar-y-reproducir)
[![T-SQL](https://img.shields.io/badge/lenguaje-T--SQL-blue)](sql/)
[![BD1](https://img.shields.io/badge/Base%20de%20Datos%20I-FaCENA%20·%20UNNE-6A1B9A)](#equipo)
[![Licencia](https://img.shields.io/github/license/MiltonRodx/proyecto-bd1-equipo_49)](LICENSE)

> Proyecto integrador de **Base de Datos I — FaCENA (UNNE)**: base relacional en 3FN para una agencia de motos 0 km (stock por modelo, unidades por chasis, ventas de 1 moto + 0..N accesorios, precios pactados congelados), llevada hasta robustez con temas técnicos de etapa V.

## Equipo

| Integrante | DNI |
|---|---|
| Rodriguez Rivas Milton Nahuel | 47896329 |
| Zacarías Blanco Fernando Iván | 40547162 |
| Balenzuela Tobías | 46775591 |
| Veglia Marcos Daniel | 45845762 |
| Zarate Arturo Alan | 44212316 |

## 📌 Estado de las etapas

| Etapa | Pregunta | Carpeta | Contenido | Estado |
|---|---|---|---|---|
| I. Requerimientos | ¿Qué necesita el negocio? | [`docs/etapa-01/`](docs/etapa-01/) | [`ETAPA_01.md`](docs/etapa-01/ETAPA_01.md) + PDF entregable | ✅ Entregada (04/09) |
| II. Modelado | ¿Cómo representamos la información? | [`docs/etapa-02/`](docs/etapa-02/) | [`ETAPA_02.md`](docs/etapa-02/ETAPA_02.md) + DER + relacional 3FN | ✅ Entregada (11/09) |
| III. Implementación | ¿Cómo construimos la BD? | [`docs/etapa-03/`](docs/etapa-03/) + [`sql/ddl/`](sql/ddl/) + [`sql/dml/`](sql/dml/) | DDL + DML | ✅ Entregada (30/09) |
| IV. Consultas | ¿Cómo obtenemos información? | [`docs/etapa-04/`](docs/etapa-04/) + [`sql/consultas/`](sql/consultas/) | Factura, reporte agregado, consulta avanzada | ✅ Entregada (16/10) |
| V. Temas técnicos | ¿Cómo la hacemos robusta? | [`docs/etapa-05/`](docs/etapa-05/) | [`ETAPA_05.md`](docs/etapa-05/ETAPA_05.md) + investigaciones y evidencias por tema | ✅ Entregada (03/11) |

Documentos fuente por etapa:

* Etapa I: [ETAPA_01.md](docs/etapa-01/ETAPA_01.md) · [PDF entregable](docs/etapa-01/BDI%20Proyecto%20Integrador%20_%20Grupo%2049.pdf)
* Etapa II: [ETAPA_02.md](docs/etapa-02/ETAPA_02.md) · [Esquema relacional (PNG)](docs/etapa-02/esquema_relacional_etapa_02.png) · [ERDPlus](docs/etapa-02/archivos_erdplus/archivo_erdplus_relacional.erdplus) · [Notación Chen (TXT)](docs/etapa-02/notacion_chen_RS.txt) · [PDF](docs/etapa-02/BDI%20Proyecto%20Integrador%20_%20Grupo%2049.pdf)

## 🗂️ Estructura del repositorio

```
proyecto-bd1-equipo_49/
├── README.md
├── docs/               Documentación por etapa (de la I a la V)
│   ├── etapa-01/       Requerimientos y reglas de negocio
│   ├── etapa-02/       DER (Chen/ERDPlus) + modelo relacional 3FN
│   ├── etapa-03/       Documentación del DDL/DML
│   ├── etapa-04/       Documentación de las consultas
│   └── etapa-05/       Temas técnicos: 5 carpetas numeradas, un tema por carpeta
│       ├── 01-procedimientos-funciones/
│       ├── 02-transacciones/
│       ├── 03-triggers-auditoria/
│       ├── 04-seguridad/
│       └── 05-indices/
└── sql/
    ├── ddl/            DDL (15 tablas, PK/FK/CHECK, índices de negocio)
    ├── dml/            DML (lote de prueba)
    └── consultas/      Factura, reportes agregados y consulta avanzada
```

## 🚀 Cómo usar y reproducir

Requisitos: `git`, SQL Server Express 2016 SP1+ (o Docker), `sqlcmd` / SSMS.

```bash
git clone https://github.com/MiltonRodx/proyecto-bd1-equipo_49.git
cd proyecto-bd1-equipo_49
```

### Reconstruir la base `[X MOTORS]`

```bash
# 1. Base + lote (orden obligatorio: DDL asume tablas vacías)
sqlcmd -S <server> -d "X MOTORS" -i sql/ddl/DDL_Script_X_Motors.sql
sqlcmd -S <server> -d "X MOTORS" -i sql/dml/DML_Script_X_Motors.sql

# 2. Temas técnicos (en el orden de docs/etapa-05/README.md §2.2)
for f in docs/etapa-05/03-triggers-auditoria/01_tablas_auditoria.sql \
         docs/etapa-05/01-procedimientos-funciones/01_funciones.sql \
         docs/etapa-05/01-procedimientos-funciones/02_procedimientos.sql \
         docs/etapa-05/02-transacciones/01_sp_registrar_venta.sql \
         docs/etapa-05/02-transacciones/02_sp_cambiar_estado_venta.sql \
         docs/etapa-05/03-triggers-auditoria/02_trg_historial_precio_modelo.sql \
         docs/etapa-05/03-triggers-auditoria/03_trg_auditoria_venta.sql \
         docs/etapa-05/03-triggers-auditoria/04_trg_auditoria_cliente_estado.sql \
         docs/etapa-05/04-seguridad/01_seguridad.sql \
         docs/etapa-05/05-indices/01_indices.sql; do
    sqlcmd -S <server> -d "X MOTORS" -i "$f"
done
```

* **Lectura rápida:** [`docs/etapa-01/ETAPA_01.md`](docs/etapa-01/ETAPA_01.md) → [`ETAPA_02`](docs/etapa-02/ETAPA_02.md) → [`ETAPA_03`](docs/etapa-03/ETAPA-03.md) → [`ETAPA_04`](docs/etapa-04/ETAPA_04.md) → [`ETAPA_05`](docs/etapa-05/ETAPA_05.md).
* **Demostraciones y evidencias:** cada carpeta `*/evidencias/` conserva sus scripts reproducibles y salidas con `@@VERSION`, usuario y fecha; los scripts de datos corren con `ROLLBACK` para conservar el lote.
* **Diagramas:** abrí el PNG directamente o importá el `.erdplus` en ERDPlus; el `.txt` de Etapa II describe el DER en notación Chen.

## 🎯 Lo destacado de la Etapa V

* **Procedimientos y funciones:** la operación completa de venta en `sp_registrar_venta` (descuentos, accesorios vía JSON, stock y errores de negocio `50001–50019`); venta demo verificada con la factura de Etapa IV (`OK`).
* **Transacciones:** demos ACID con `COMMIT`/`ROLLBACK` (stock insuficiente y FK inválida) que nunca dejan ventas parciales.
* **Auditoría:** triggers sobre `modelo_motocicleta`, `venta` y `cliente.estado` con tablas de auditoría propias y soporte multilínea.
* **Seguridad:** 3 roles con principio de mínimo privilegio; la demo de la consigna v2 con logins reales efímeros dio **5/5 pruebas** conforme (2 denegaciones 229, 3 OKs).
* **Índices:** 10 índices de negocio + prueba de escala exigida por la consigna con **1.000.000 de filas**: `Table Scan` (3.585 lecturas, CPU 107 ms) → `Clustered Index Seek` (230) → `Index Seek` con cobertura (162).

## ℹ️ Nota de diseño vigente

`venta.metodo_pago` quedó como `VARCHAR(50)` validado a nivel de aplicación (la tabla normalizada `METODO_PAGO` mencionada en los primeros análisis se descartó para no romper el contrato de etapas anteriores). Los procedimientos de la etapa V (`sp_registrar_venta`) normalizan y validan los métodos de pago admitidos (`efectivo`, `transferencia bancaria`, `tarjeta de credito/debito`, `financiamiento`) con errores de negocio dedicados.

## Licencia

[MIT](LICENSE)

<details>
<summary>Consigna completa del proyecto (Etapas I–V)</summary>

### Presentación y Contexto

El objetivo central es diseñar, normalizar e implementar una base de datos relacional que soporte el ciclo completo de operaciones de venta, garantizando integridad referencial, consistencia y no redundancia.

### Alcance y Restricciones

* Dominio libre de gestión de ventas, con complejidad de 6 a 10 relaciones (justificable si difiere).
* Normalización obligatoria hasta **3FN**.

### Etapa I: Requerimientos y Dominio del Negocio

* Descripción del caso y alcance.
* Reglas de negocio (mínimo 6): gestión de stock, registro de clientes, historial de precios unitarios en el detalle, métodos de pago.

### Etapa II: Modelado Conceptual y Lógico

* DER en notación P. Chen con ERDPlus (entidades, atributos, cardinalidades).
* Modelo relacional con PK/FK.
* Normalización 1FN → 2FN → 3FN documentada.

### Etapa III: Implementación Física

* DDL con PK/FK, tipos y restricciones (`NOT NULL`, `UNIQUE`, `CHECK`).
* DML con 8–10 registros coherentes por tabla.

### Etapa IV: Consultas y Casos de Uso

* Factura/comprobante con subtotales y total.
* Reporte agregado (`GROUP BY`, `SUM`, `COUNT`).
* Consulta avanzada con ≥3 `JOIN` y `HAVING`/subconsultas.

### Etapa V: Temas Técnicos

Procedimientos y funciones, transacciones, triggers de auditoría, seguridad e índices.

| Etapa | Producto | Fecha |
|---|---|---|
| I. Requerimientos | Requerimientos + reglas | viernes 04/09 |
| II. Modelado | DER + relacional + 3FN | viernes 11/09 |
| III. Implementación | DDL + DML | miércoles 30/09 |
| IV. Consultas | SQL + casos de uso | 16/10 |
| V. Temas técnicos | Robustez | 03/11 |

</details>
