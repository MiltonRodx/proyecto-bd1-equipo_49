# Etapa I: Requerimientos y Dominio del Negocio

**Materia:** Base de Datos I  
**Facultad:** Facultad de Ciencias Exactas y Naturales y Agrimensura (UNNE)  
**Grupo:** 49  
**Nombre del equipo:** “X Motors”  
**Título del tema:** Sistema de Gestión de Ventas de Motos  

---

## 1. Integrantes del Grupo

* **Rodriguez Rivas Milton Nahuel** - DNI: 47896329
* **Zacarías Blanco Fernando Iván** - DNI: 40547162
* **Balenzuela Tobías** - DNI: 46775591
* **Veglia Marcos Daniel** - DNI: 45845762
* **Zarate Arturo Alan** - DNI: 44212316

---

## 1.5 Descripción Completa del Caso

Se desea informatizar la gestión de ventas de una agencia dedicada a la comercialización de motocicletas 0 km.

La agencia dispone de diferentes modelos de motos que pueden ser adquiridas por sus clientes. Los clientes de la agencia siempre serán personas físicas, y consumidores finales.

De cada motocicleta se desea guardar un número de chasis, número de motor, la marca, el modelo, la cilindrada (cc), el precio de venta y la cantidad de unidades disponibles en stock. Cada motocicleta será identificada de manera única con su número de chasis.

De cada cliente se desea registrar un código identificador (DNI de Argentina), nombre, apellidos, CUIL, dirección, teléfono de contacto (un cliente solamente puede ser persona física) y email.

Un cliente puede comprar una o varias motocicletas en la agencia. A lo largo del tiempo, un mismo modelo de motocicleta puede ser comprado por diferentes clientes.

Un cliente solo puede comprar una motocicleta a la vez por compra. Asimismo, cada vez que un cliente realiza la compra de una motocicleta, dicha operación debe quedar registrada en la base de datos, indicando la fecha en la que se realizó la venta y el monto total abonado.

La agencia puede vender cero a varios accesorios al momento de realizarse una compra de una motocicleta. De cada accesorio se desea guardar un código identificador, una descripción y stock disponible.

De cada vendedor se desea conocer el código identificador (DNI Argentina), nombre, apellidos, CUIL, teléfono de contacto y email.

La agencia trabaja con diferentes proveedores que le suministran los vehículos que comercializa. Un proveedor puede suministrar uno o varios modelos de motos y, asimismo, un mismo modelo puede ser suministrado por uno o varios proveedores.

De cada proveedor se desea guardar un código identificador (CUIT), la razón social, email, dirección, ciudad, provincia y número de teléfono. Cada proveedor provee uno o varios modelos específicos de motocicleta.

---

## 1.6 Alcance del Sistema

El alcance de nuestro proyecto tendrá enfoque en los aspectos que a continuación se listan:

### Administración de Unidades e Inventario
* Registro y actualización del catálogo de modelos de motocicletas (marca, modelo, cilindrada, color, año, precio de lista).
* Control y seguimiento del stock disponible por cada modelo.
* Gestión e inventario de accesorios opcionales (cascos, indumentaria, repuestos) asociados a las ventas.

### Gestión de Clientes y Proveedores
* Registro, actualización y consulta de datos personales, fiscales y de contacto de los compradores.

### Procesamiento de Ventas y Facturación
* Emisión y registro de comprobantes de venta.
* Vinculación en cada operación de: el cliente comprador, el vendedor responsable, las unidades vendidas y el precio pactado al momento de la transacción.

### Cobros y Métodos de Pago
* Registro detallado de las transacciones de cobro vinculadas a cada factura.
* Soporte para múltiples formas de pago (efectivo, transferencia bancaria, tarjeta de crédito o financiamiento).

### Reportes Operativos Básicos
* Consultas a la Base de Datos para la toma de decisiones, tales como:
  * Inventario/stock actual de unidades disponibles.
  * Historial de compras y abastecimiento por proveedor.
  * Volúmenes y montos de ventas desglosados por vendedor o por período de tiempo.

---

## 1.7 Reglas de Negocio

### Gestión de Stock
* **RN1:** Cada modelo de moto y cada accesorio tienen asociado un stock actual, el cual debe ser siempre un valor mayor o igual a cero; toda venta concretada descuenta automáticamente del stock la cantidad correspondiente del ítem (modelo de moto o accesorio) vendido.
* **RN2:** No se puede registrar una venta sobre un modelo de moto o un accesorio cuyo stock disponible sea igual a cero.

### Registro de Clientes
* **RN3:** Un cliente debe estar registrado con su DNI (dato único e irrepetible) antes de poder asociarse a cualquier compra.
* **RN4:** Un cliente puede realizar múltiples compras a lo largo del tiempo, quedando registradas las unidades adquiridas de cada modelo.
* **RN5:** Un cliente puede encontrarse en uno de los siguientes estados de seguimiento: interesado, en proceso de compra o comprador; el pasaje al estado "comprador" requiere una compra concretada y registrada en el sistema.

### Historial de Precios Unitarios
* **RN6:** El detalle de una compra debe almacenar el precio unitario efectivamente pactado en el momento de la operación; este valor es independiente del precio de lista vigente del modelo y no se actualiza retroactivamente aunque el precio de lista cambie con posterioridad.
* **RN7:** Toda modificación al precio de lista de un modelo de moto genera un nuevo registro histórico, sin alterar ni eliminar los precios ya asociados a compras previas.

### Proveedores
* **RN8 (Trazabilidad y Suministro por Proveedor):** Cada modelo de motocicleta comercializado en la agencia debe estar asociado al menos a un proveedor registrado, identificado de forma unívoca por su CUIT, a fin de mantener la trazabilidad del origen y abastecimiento del inventario. Dado que un proveedor es siempre una empresa o sociedad (nunca una persona física), el CUIT es único en el sistema y se vincula con los modelos de motocicletas mediante la tabla de provisión correspondiente.

### Vendedores
* **RN9:** Toda venta debe estar asociada a un único vendedor responsable de la operación, a fin de permitir el seguimiento de desempeño y el eventual cálculo de comisiones.

### Accesorios y Composición de la Compra
* **RN10:** Una compra debe incluir siempre una moto: no puede existir una compra sin moto asociada. Los accesorios son opcionales, por lo que una compra puede incluir una moto sola, o una moto junto con uno o más accesorios, cada uno con su propio precio unitario registrado en el detalle de la compra.

### Estado de la Compra
* **RN11:** Toda compra debe registrar un estado que puede ser: efectuada, cancelada o reembolsada. El estado inicial de toda compra es "efectuada". Si una compra pasa a estado "cancelada" o "reembolsada", el stock de la moto y de los accesorios involucrados debe reintegrarse, y la operación no se elimina del sistema sino que se conserva con su estado actualizado, preservando el historial completo.

### Cotizaciones y Presupuestos
* **RN12:** Un cliente puede solicitar una cotización antes de concretar la compra. Los precios unitarios pactados en una cotización se mantendrán congelados por un plazo máximo de 1 semana (7 días corridos) desde su fecha de emisión.

---

## 1.8 Requerimientos

### Requerimientos Funcionales (RF)
* **RF#1:** La base de datos debe permitir registrar clientes (dni, nombre, apellido, teléfonos, ciudad, provincia, código postal, dirección).
* **RF#2:** El sistema debe permitir registrar y consultar el historial de compras y modelos adquiridos por cada cliente.
* **RF#3:** La base de datos debe permitir registrar proveedores (cuit, nombre o razón social, teléfonos). El proveedor es siempre una asociación/empresa, nunca una persona física.
* **RF#4:** La base de datos debe permitir registrar vendedores (dni, nombre, apellido, teléfonos, ciudad, provincia).
* **RF#5:** Toda venta debe quedar asociada al vendedor que la realizó.
* **RF#6:** La base de datos debe permitir registrar modelos de moto (nombre_modelo, marca, modelo, cilindrada, color, año, precio_lista, stock_disponible) y llevar el control automático del stock disponible por modelo.
* **RF#7:** La base de datos debe permitir registrar accesorios (id_accesorio, nombre, categoría (varchar), precio_lista, precio_costo, stock) que puedan ofrecerse como complemento opcional de una compra.
* **RF#8:** El sistema debe guardar las compras efectuadas junto con su respectivo precio unitario pactado al momento de la operación (tanto de la moto como de cada accesorio incluido).
* **RF#9:** Una compra debe incluir siempre exactamente una moto; los accesorios asociados a esa compra son opcionales (cero o más).
* **RF#10:** El sistema debe permitir registrar y consultar el estado de seguimiento de un cliente (interesado, en proceso de compra, comprador).
* **RF#11:** El sistema debe permitir registrar el estado de una compra (efectuada, cancelada, reembolsada).

### Requerimientos No Funcionales (RNF)
* **RNF#1:** El sistema debe garantizar que el acceso directo a los datos almacenados esté restringido exclusivamente a administradores del sistema.
* **RNF#2:** Los clientes no deben tener ningún tipo de acceso ni visibilidad sobre la base de datos: el sistema es una herramienta de gestión interna de la agencia, no un producto de cara al cliente.
* **RNF#3:** Los vendedores podrían acceder a la información del sistema autenticándose previamente (con usuarios generados en el RDBMS).

### Requerimientos de Dominio (RD)
* **RD#1:** El stock de un modelo de moto debe ser siempre mayor o igual a cero.
* **RD#2:** El stock de un accesorio debe ser siempre mayor o igual a cero.
* **RD#3:** No se puede registrar una compra sobre un modelo de moto cuyo stock disponible sea igual a cero.
* **RD#4:** El DNI de clientes y vendedores, y el CUIT de proveedores, deben ser numéricos y únicos dentro de sus respectivas tablas.
