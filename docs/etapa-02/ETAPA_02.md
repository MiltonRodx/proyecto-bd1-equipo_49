# Etapa II: Modelado de Datos - Sistema de Gestión "X Motors"

**Materia:** Base de Datos I  
**Facultad:** Facultad de Ciencias Exactas y Naturales y Agrimensura (UNNE)  
**Grupo:** 49  
**Equipo:** X Motors  
**Producto Entregable:** Modelo Entidad-Relación (DER), Modelo Relacional en 3FN y Documentación de Negocio  
**Entrega:** viernes 11/09 · **Pregunta:** ¿Cómo representamos la información?

## Material de esta etapa

| Archivo | Descripción |
|---|---|
| [BDI Proyecto Integrador _ Grupo 49.pdf](BDI%20Proyecto%20Integrador%20_%20Grupo%2049.pdf) | PDF archivado en esta carpeta |
| [ESQUEMA RELACIONAL ETAPA 2.png](ESQUEMA%20RELACIONAL%20ETAPA%202.png) | Diagrama relacional (ver imagen abajo) |
| [archivo_erdplus_relacional.erdplus](archivo_erdplus_relacional.erdplus) | Fuente editable para [ERDPlus](https://erdplus.com) |
| [Notacion chen- diagrama relacional.txt](Notacion%20chen-%20diagrama%20relacional.txt) | DER en notación Chen (texto) |

> Cómo leer: este MD es la lectura rápida. El diagrama válido es el PNG + `.erdplus`. El `.txt` detalla entidades, atributos y cardinalidades.
> Volver al [README general](../../README.md) · Anterior: [Etapa I](../etapa-01/ETAPA_01.md).

## Contenido

* [Presentación de la Etapa II](#-presentación-de-la-etapa-ii)
* [1. Integrantes del Grupo](#1-integrantes-del-grupo)
* [2. Descripción del Dominio del Negocio](#2-descripción-del-dominio-del-negocio)
* [3. Justificación del Modelado Relacional (3FN)](#3-justificación-del-modelado-relacional-3fn)
* [4. Alcance del Sistema](#4-alcance-del-sistema)
* [5. Reglas de Negocio (RN)](#5-reglas-de-negocio-rn)
* [6. Requerimientos de Sistema](#6-requerimientos-de-sistema)
* [7. Diagramas y archivos](#7-diagramas-y-archivos)
* [8. Notas de diseño](#8-notas-de-diseño)

---

## 📌 Presentación de la Etapa II

La **Etapa II: Modelado** tiene como objetivo responder a la pregunta central: **¿Cómo representamos la información del negocio?** 

A partir de los requerimientos y reglas de negocio relevados en la Etapa I, en esta fase construimos y validamos:
1. **Diagrama Entidad-Relación (DER) / Diagrama Relacional:** Modelado gráfico que representa las entidades, atributos, relaciones y cardinalidades del sistema.
2. **Normalización hasta la Tercera Forma Normal (3FN):** Garantía de eliminación de redundancias, anomalías de inserción, actualización y borrado.
3. **Integridad de Datos y Precios Históricos:** Estructuración de tablas de detalle, históricos de precios y cotizaciones con vencimiento para congelar montos pactados y garantizar auditorías.

---

## 1. Integrantes del Grupo

* **Rodriguez Rivas Milton Nahuel** - DNI: 47896329
* **Zacarías Blanco Fernando Iván** - DNI: 40547162
* **Balenzuela Tobías** - DNI: 46775591
* **Veglia Marcos Daniel** - DNI: 45845762
* **Zarate Arturo Alan** - DNI: 44212316

---

## 2. Descripción del Dominio del Negocio

Se informatiza la gestión de ventas de una agencia de motocicletas 0 km. El sistema gestiona inventario por modelo y unidad física (número de chasis único), venta de accesorios opcionales, seguimiento de estados de clientes, control de vendedores responsabiles, trazabilidad de proveedores (empresas) y congelamiento de precios a través de cotizaciones e historiales.

---

## 3. Justificación del Modelado Relacional (3FN)

El diseño relacional presentado en esta etapa cumple de forma estricta con la **Tercera Forma Normal (3FN)**:

* **1FN (Primera Forma Normal):** Todos los atributos son atómicos. Las direcciones de clientes y proveedores se desglosan en entidades dependientes (`DIRECCION_CLIENTE`, `DIRECCION_PROVEEDOR`) para mantener la granularidad.
* **2FN (Segunda Forma Normal):** Todos los atributos no clave dependen funcionalmente de la totalidad de la clave primaria. En las tablas intermedias N:M (`PROVISION_MOTOCICLETA`, `PROVISION_ACCESORIO`, `DETALLE_VENTA_ACCESORIO`), los datos descriptivos como la cantidad o el precio pactado dependen de la clave compuesta.
* **3FN (Tercera Forma Normal):** No existen dependencias transitivas. El congelamiento de precios se resuelve almacenando `precio_venta_pactado` en `VENTA` y `precio_pactado` en `DETALLE_VENTA_ACCESORIO`, haciendo que el historial transaccional sea independiente de futuras modificaciones en el catálogo (`MODELO_MOTOCICLETA.precio_lista`).

---

## 4. Alcance del Sistema

### Administración de Unidades e Inventario
* Catálogo de modelos de motocicletas (marca, cilindrada, color, año, precio de lista).
* Control de stock por modelo e inventario de accesorios opcionales.

### Gestión de Clientes y Proveedores
* Registro de compradores (personas físicas) y proveedores (personas jurídicas / CUIT).

### Procesamiento de Ventas y Facturación
* Registro de comprobantes vinculando cliente, vendedor, unidad vendida (chasis) y accesorios opcionales.

### Cotizaciones y Presupuestos
* Presupuestos con precios congelados por un plazo máximo de 7 días corridos.

---

## 5. Reglas de Negocio (RN)

* **RN1:** Stock $\ge 0$ para modelos y accesorios. Descuento automático tras cada venta.
* **RN2:** Prohibición de venta sin stock disponible.
* **RN3:** Cliente obligatoriamente registrado con DNI único previo a comprar.
* **RN4:** Historial de múltiples compras por cliente a lo largo del tiempo.
* **RN5:** Estado de seguimiento del cliente (`interesado`, `en proceso de compra`, `comprador`).
* **RN6:** Independencia del precio unitario pactado respecto a futuros cambios en el catálogo.
* **RN7:** Registro histórico en `HISTORIAL_DE_PRECIO` ante variaciones en el precio de lista.
* **RN8:** Trazabilidad de origen registrando al menos un proveedor (CUIT) por modelo comercializado mediante la tabla `PROVISION_MOTOCICLETA`.
* **RN9:** Toda venta exige la asignación de un único vendedor responsable.
* **RN10:** Venta obligatoria de exactamente una motocicleta; accesorios de 0 a N opcionales.
* **RN11:** Estado de la venta (`efectuada`, `cancelada`, `reembolsada`). El paso a cancelada/reembolsada reintegra stock automáticamente.
* **RN12:** Cotizaciones con precio congelado durante 7 días corridos desde su emisión.

---

## 6. Requerimientos de Sistema

### Funcionales (RF)
* **RF#1 - RF#5:** Registro de clientes, historial de compras, proveedores (asociación/empresa), vendedores y vinculación vendedora-venta.
* **RF#6 - RF#8:** Registro de modelos con stock automático, accesorios e histórico de compras con precios pactados.
* **RF#9 - RF#11:** Composición de compra (1 moto + N accesorios), estado de seguimiento de cliente y estado de venta.

### No Funcionales (RNF)
* **RNF#1:** Acceso directo a la BD restringido exclusivamente a administradores.
* **RNF#2:** Sin visibilidad ni acceso a la base de datos para clientes (herramienta de gestión interna).
* **RNF#3:** Autenticación de vendedores mediante roles y usuarios del RDBMS.

### De Dominio (RD)
* **RD#1 - RD#2:** `stock_disponible >= 0` en modelos y `stock >= 0` en accesorios.
* **RD#3:** Bloqueo de ventas con stock en cero.
* **RD#4:** Unicidad y formato numérico para DNI (clientes/vendedores) y CUIT (proveedores).

---

## 7. Diagramas y archivos

### Esquema relacional

![Esquema relacional Etapa 2](ESQUEMA%20RELACIONAL%20ETAPA%202.png)

Fuente editable: [archivo_erdplus_relacional.erdplus](archivo_erdplus_relacional.erdplus) (abrir en [ERDPlus](https://erdplus.com)).

Tablas del diagrama: `PERSONA`, `CLIENTE`, `VENDEDOR`, `DIRECCION_CLIENTE`, `DIRECCION_PROVEEDOR`, `PROVEEDOR`, `MODELO_MOTOCICLETA`, `MOTOCICLETA`, `ACCESORIO`, `VENTA`, `DETALLE_VENTA_ACCESORIO`, `PROVISION_MOTOCICLETA`, `PROVISION_ACCESORIO`, `HISTORIAL_DE_PRECIO`, `COTIZACION`.

### DER en notación Chen

Ver [Notacion chen- diagrama relacional.txt](Notacion%20chen-%20diagrama%20relacional.txt): entidades, atributos (PK con `*`), relaciones y cardinalidades (1:1, 1:N, M:N), incluida la herencia `PERSONA → CLIENTE / VENDEDOR`.

## 8. Notas de diseño

* En este modelo `VENTA.metodo_pago` es un `VARCHAR`. La tabla normalizada `METODO_PAGO` se crea en Etapa III.
* El PDF archivado en esta carpeta corresponde al entregable de Etapa I; el entregable de Etapa II es este MD más el PNG, el `.erdplus` y el `.txt`.

---

> Navegación: [README general](../../README.md) · [Etapa I](../etapa-01/ETAPA_01.md)
