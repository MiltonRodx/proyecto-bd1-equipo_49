# X Motors — Sistema de Gestión de Ventas de Motos | BD1 Grupo 49

> Base de Datos I — FaCENA (UNNE). Base relacional en 3FN para una agencia de motos 0 km: stock por modelo, unidades por chasis, ventas de 1 moto + 0..N accesorios, precios pactados congelados.

## Equipo

| Integrante | DNI |
|---|---|
| Rodriguez Rivas Milton Nahuel | 47896329 |
| Zacarías Blanco Fernando Iván | 40547162 |
| Balenzuela Tobías | 46775591 |
| Veglia Marcos Daniel | 45845762 |
| Zarate Arturo Alan | 44212316 |

## Estado de las etapas

| Etapa | Pregunta | Carpeta | Contenido | Estado |
|---|---|---|---|---|
| I. Requerimientos | ¿Qué necesita el negocio? | [`docs/etapa-01/`](docs/etapa-01/) | [`ETAPA_01.md`](docs/etapa-01/ETAPA_01.md) + PDF entregable | ✅ Entregada (04/09) |
| II. Modelado | ¿Cómo representamos la información? | [`docs/etapa-02/`](docs/etapa-02/) | [`ETAPA_02.md`](docs/etapa-02/ETAPA_02.md) + DER + relacional 3FN | ✅ Entregada (11/09) |
| III. Implementación | ¿Cómo construimos la BD? | [`docs/etapa-03/`](docs/etapa-03/) + [`sql/ddl/`](sql/ddl/) + [`sql/dml/`](sql/dml/) | DDL + DML | ⏳ Pendiente (30/09) |
| IV. Consultas | ¿Cómo obtenemos información? | [`docs/etapa-04/`](docs/etapa-04/) + [`sql/consultas/`](sql/consultas/) | Factura, reporte agregado, consulta avanzada | ⏳ Pendiente |
| V. Temas técnicos | ¿Cómo la hacemos robusta? | [`docs/etapa-05/`](docs/etapa-05/) + [`sql/tecnico/`](sql/tecnico/) | Procedimientos, transacciones, triggers, seguridad, índices | ⏳ Pendiente |

Documentos fuente por etapa:

* Etapa I: [ETAPA_01.md](docs/etapa-01/ETAPA_01.md) · [PDF entregable](docs/etapa-01/BDI%20Proyecto%20Integrador%20_%20Grupo%2049.pdf)
* Etapa II: [ETAPA_02.md](docs/etapa-02/ETAPA_02.md) · [Esquema relacional (PNG)](docs/etapa-02/ESQUEMA%20RELACIONAL%20ETAPA%202.png) · [ERDPlus](docs/etapa-02/archivo_erdplus_relacional.erdplus) · [Notación Chen (TXT)](docs/etapa-02/Notacion%20chen-%20diagrama%20relacional.txt) · [PDF](docs/etapa-02/BDI%20Proyecto%20Integrador%20_%20Grupo%2049.pdf)

## Estructura del repositorio

```
proyecto-bd1-equipo_49/
├── README.md
├── docs/
│   ├── etapa-01/  ETAPA_01.md + PDF
│   ├── etapa-02/  ETAPA_02.md + PDF + PNG + .erdplus + .txt Chen
│   ├── etapa-03/
│   ├── etapa-04/
│   └── etapa-05/
├── sql/
│   ├── ddl/
│   ├── dml/
│   ├── consultas/
│   └── tecnico/
└── modelos/
    └── der/
```

## Cómo clonar y usar

Requisitos: `git`, visor de PDF/PNG y navegador para [ERDPlus](https://erdplus.com).

```bash
git clone <url-del-repo>
cd proyecto-bd1-equipo_49
ls docs/etapa-01 docs/etapa-02
```

* Lectura rápida: empezá por [`docs/etapa-01/ETAPA_01.md`](docs/etapa-01/ETAPA_01.md) y [`docs/etapa-02/ETAPA_02.md`](docs/etapa-02/ETAPA_02.md).
* Entregables firmados: PDFs en cada carpeta de etapa.
* Diagramas: abrí la imagen PNG directamente o importá el `.erdplus` en ERDPlus; el `.txt` de Etapa II describe el DER en notación Chen.

## Nota de diseño vigente

En Etapa II `VENTA.metodo_pago` es un `VARCHAR`. La tabla normalizada `METODO_PAGO` (con recargo/descuento) se crea en Etapa III. Las Etapas I–II no se modifican por esto.

### Actualización de documentación


Se realizo una revision de la estructura del repositorio y de la documentacion correspondiente a las estapas del proyecto, tambien se verifico la 
organizacion de los archivos y entregrables para facilitar el manejo en siguientes etapas. 

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
| IV. Consultas | SQL + casos de uso | — |
| V. Temas técnicos | Robustez | — |

</details>
