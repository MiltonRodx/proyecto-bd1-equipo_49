# Proyecto BD1 - Equipo 49
## Proyecto decidido
Sistema de gestión de ventas de motos.


---
---
## Consigna:
## Presentación y Contexto

El objetivo central del proyecto es diseñar, normalizar e implementar una base de datos relacional que soporte el ciclo completo de operaciones de venta, garantizando la integridad referencial, la consistencia y la no redundancia de la información.

---

## Alcance y Restricciones

### Dominio del problema

Todos los equipos deberán desarrollar un sistema de gestión de ventas de productos o servicios (ej. indumentaria, electrónica, repuestos automotores, librería, etc.), pudiendo seleccionar libremente el dominio específico, siempre que el caso permita satisfacer los requerimientos mínimos establecidos.

### Límite de tablas

El modelo deberá presentar una complejidad suficiente para representar adecuadamente el dominio seleccionado. Como referencia, se espera un esquema de entre 6 y 10 relaciones, pudiendo justificarse una cantidad diferente cuando las características del dominio lo requieran.

### Nivel de normalización

El esquema debe alcanzar obligatoriamente la **Tercera Forma Normal (3FN)**.

---

## Etapas y Entregables

### Etapa I: Requerimientos y Dominio del Negocio

- **Descripción del caso:** Breve introducción al rubro elegido y alcance del sistema.
- **Reglas de Negocio (mínimo 6):** Redacción explícita de las reglas que rigen las operaciones.
  - Debe incluir al menos:
    - Gestión de stock
    - Registro de clientes
    - Historial de precios unitarios en el detalle de compra (para evitar cambios retroactivos)
    - Métodos de pago

### Etapa II: Modelado Conceptual y Lógico

- **Diagrama Entidad-Relación (DER):** Diagrama con entidades, atributos, relaciones y cardinalidades (1:1, 1:N, N:M). Usando notación P. Chen en la herramienta ERDPlus.
- **Transformación al Modelo Relacional:** Notación de tablas con claves primarias (PK) y foráneas (FK).
- **Proceso de Normalización:** Documentación paso a paso de la evolución del modelo:
  1. **1FN:** Eliminación de grupos repetitivos y garantía de atomicidad.
  2. **2FN:** Eliminación de dependencias funcionales parciales en claves compuestas.
  3. **3FN:** Eliminación de dependencias transitivas en atributos no clave.

### Etapa III: Implementación Física (Scripts SQL)

- **Script DDL (Data Definition Language):**
  - Creación de tablas e integridad referencial (PRIMARY KEY, FOREIGN KEY con reglas de borrado/modificación).
  - Definición correcta de tipos de datos (VARCHAR, DECIMAL, DATETIME, etc.) y restricciones (NOT NULL, UNIQUE, CHECK).
- **Script DML (Data Manipulation Language):**
  - Poblado inicial de la base de datos con al menos 8 a 10 registros coherentes por tabla para pruebas.

### Etapa IV: Consultas y Casos de Uso

Desarrollar y probar los scripts SQL para responder a las siguientes necesidades de información:

- **Factura/Comprobante:** Consulta que consolide el encabezado y detalle de una venta, calculando sub-totales por renglón y el total acumulado.
- **Reporte Agregado:** Total de ventas realizadas por cada vendedor o por cada categoría de producto en un rango de fechas (GROUP BY, SUM, COUNT).
- **Consulta de Negocio Avanzada:** Una consulta que combine al menos 3 tablas mediante JOIN y aplique filtros condicionales (HAVING o subconsultas).

### Etapa V: Implementación Temas Técnicos

Investigar e implementar en el motor de bases de datos diferentes componentes, mecanismos y estructuras que aportan valor crítico para que la implementación de la base de datos sea robusta, rápida, segura y fácil de mantener a largo plazo.

- Descripción breve de cada uno de los temas técnicos y fundamentos de aplicación en el caso de estudio desarrollado.
- Script SQL de implementación en el motor de bases de datos.
- Script SQL o resumen explicativo (en caso de corresponder) de demostración de utilización de cada tema técnico implementado.

**Temas técnicos:**
- Procedimientos y funciones almacenadas
- Manejo de transacciones
- Triggers de auditorías
- Seguridad
- Índices (optimización)

---

## Cronograma

| Etapa | Pregunta que responde | Producto | Fecha Entrega |
|-------|----------------------|----------|---------------|
| **I. Requerimientos** | ¿Qué necesita el negocio? | Requerimientos + reglas | viernes 04/09 |
| **II. Modelado** | ¿Cómo representamos la información? | DER + modelo relacional + 3FN | viernes 11/09 |
| **III. Implementación** | ¿Cómo construimos la BD? | DDL + DML | miércoles 30/09 |
| **IV. Consultas** | ¿Cómo obtenemos información? | SQL + casos de uso | — |
| **V. Temas técnicos** | ¿Cómo hacemos la solución más robusta? | Procedimientos, funciones, transacciones, triggers, seguridad e índices | — |

---

## Estructura del Repositorio

```
proyecto-bd1-equipo_XX/
│
├── docs/
│   ├── etapa-01/
│   ├── etapa-02/
│   ├── etapa-03/
│   ├── etapa-04/
│   └── etapa-05/
│
├── sql/
│   ├── ddl/
│   ├── dml/
│   ├── consultas/
│   └── tecnico/
│
├── modelos/
│   └── der/
│
└── README.md
```

---

> **Última modificación:** miércoles, 26 de agosto de 2026, 22:47
