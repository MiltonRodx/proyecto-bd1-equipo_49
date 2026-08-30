# Etapa I: Requerimientos y Dominio del Negocio

## Descripción del caso

Decidimos implementar un sistema de gestión de ventas aplicado al rubro de motos, pensado para ser utilizado en una agencia de motos. Este rubro se caracteriza por manejar distintos modelos de motos junto con sus respectivos stocks, así como también por requerir un seguimiento detallado de los clientes a lo largo de todo el proceso de compra (interesado, en proceso de compra, comprador).

El sistema busca registrar a los clientes desde el momento en que manifiestan interés en adquirir una moto, permitiendo realizar un seguimiento a lo largo del proceso comercial. Asimismo, se contempla el registro de proveedores, vendedores, métodos de pago y el control del stock disponible por modelo. Un aspecto central del sistema es la conservación del historial de precios unitarios en el detalle de cada compra, de manera que los valores pactados en una operación no se vean alterados por cambios posteriores en el precio de lista.

## Requerimientos

### Funcionales

- RF#1 La base de datos debe permitir registrar clientes (**dni**, nombre, apellido, teléfonos, ciudad, provincia, código postal, dirección).
- RF#2 Un cliente puede comprar de 0 a muchas motos.
- RF#3 Una moto (unidad individual) es comprada solamente por un cliente.
- RF#4 La base de datos debe permitir registrar proveedores (**cuit**, nombre o razón social, teléfonos). El proveedor es siempre una asociación/empresa, nunca una persona física.
- RF#5 La base de datos debe permitir registrar vendedores (**dni**, nombre, apellido, teléfonos, ciudad, provincia).
- RF#6 Toda venta debe quedar asociada al vendedor que la realizó.
- RF#7 La base de datos debe tener una tabla de métodos de pago posibles, con sus respectivos intereses o descuentos.
- RF#8 La base de datos debe permitir registrar modelos de moto (**id_modelo**, marca, modelo, cilindrada, color, año, precio_lista) y llevar el control de stock por modelo.
- RF#9 La base de datos debe permitir registrar accesorios (**id_accesorio**, nombre, categoría (varchar), precio_lista, precio_costo, stock) que puedan ofrecerse como complemento opcional de una compra.
- RF#10 El sistema debe guardar las compras efectuadas junto con su respectivo precio unitario pactado al momento de la operación (tanto de la moto como de cada accesorio incluido).
- RF#11 Una compra debe incluir siempre exactamente una moto; los accesorios asociados a esa compra son opcionales (cero o más).
- RF#12 El sistema debe permitir registrar y consultar el estado de seguimiento de un cliente (interesado, en proceso de compra, comprador).
- RF#13 El sistema debe permitir registrar el estado de una compra (efectuada, cancelada, reembolsada).

### No funcionales

- RNF#1 El sistema debe garantizar que el acceso directo a los datos almacenados esté restringido exclusivamente a administradores del sistema.
- RNF#2 Los clientes no deben tener ningún tipo de acceso ni visibilidad sobre la base de datos: el sistema es una herramienta de gestión interna de la agencia, no un producto de cara al cliente.
- RNF#3 Los vendedores podrían acceder a la información del sistema autenticándose previamente; dado que este es un proyecto de la materia Base de Datos I, este mecanismo de autenticación se plantea a nivel conceptual y no se implementará (no forma parte del alcance ni se desarrollará GUI, backend de autenticación, ni similares).

### De dominio

- RD#1 El stock de un modelo de moto debe ser siempre mayor o igual a cero.
- RD#2 El stock de un accesorio debe ser siempre mayor o igual a cero.
- RD#3 No se puede registrar una compra sobre un modelo de moto cuyo stock disponible sea igual a cero.
- RD#4 El DNI de clientes y vendedores, y el CUIT de proveedores, deben ser numéricos y únicos dentro de sus respectivas tablas.

## Reglas de Negocio

A continuación se detallan las reglas de negocio que rigen las operaciones del sistema.

**Gestión de stock**

1. Cada modelo de moto y cada accesorio tienen asociado un stock actual, el cual debe ser siempre un valor mayor o igual a cero; toda venta concretada descuenta automáticamente del stock la cantidad correspondiente del ítem (moto o accesorio) vendido.
2. No se puede registrar una venta sobre un modelo de moto o un accesorio cuyo stock disponible sea igual a cero.

**Registro de clientes**

3. Un cliente debe estar registrado con su DNI (dato único e irrepetible) antes de poder asociarse a cualquier compra.
4. Un cliente puede tener múltiples motos compradas a lo largo del tiempo, pero cada moto individual (unidad física, no modelo) queda vinculada a un único cliente comprador.
5. Un cliente puede encontrarse en uno de los siguientes estados de seguimiento: interesado, en proceso de compra o comprador; el pasaje al estado "comprador" requiere una compra concretada y registrada en el sistema.

**Historial de precios unitarios**

6. El detalle de una compra debe almacenar el precio unitario efectivamente pactado en el momento de la operación; este valor es independiente del precio de lista vigente del modelo y no se actualiza retroactivamente aunque el precio de lista cambie con posterioridad.
7. Toda modificación al precio de lista de un modelo de moto genera un nuevo registro histórico, sin alterar ni eliminar los precios ya asociados a compras previas.

**Métodos de pago**

8. Toda compra debe estar asociada a un único método de pago vigente al momento de la operación, el cual puede aplicar un recargo o descuento porcentual sobre el precio unitario.

**Proveedores**

9. Toda moto ingresada a stock debe estar asociada a un único proveedor, identificado de forma unívoca por su CUIT, a fin de mantener la trazabilidad del origen de cada unidad. Dado que un proveedor es siempre una asociación o empresa (nunca una persona física), el CUIT corresponde al de la sociedad y es único dentro del sistema.

**Vendedores**

10. Toda venta debe estar asociada a un único vendedor responsable de la operación, a fin de permitir el seguimiento de desempeño y el eventual cálculo de comisiones.

**Accesorios y composición de la compra**

11. Una compra debe incluir siempre una moto: no puede existir una compra sin moto asociada. Los accesorios son opcionales, por lo que una compra puede incluir una moto sola, o una moto junto con uno o más accesorios, cada uno con su propio precio unitario registrado en el detalle de la compra.

**Estado de la compra**

12. Toda compra debe registrar un estado que puede ser: efectuada, cancelada o reembolsada. El estado inicial de toda compra es "efectuada". Si una compra pasa a estado "cancelada" o "reembolsada", el stock de la moto y de los accesorios involucrados debe reintegrarse, y la operación no se elimina del sistema sino que se conserva con su estado actualizado, preservando el historial completo.