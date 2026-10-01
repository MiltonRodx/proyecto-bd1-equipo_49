# Etapa III: Implementación Física (Scripts SQL)

**Sistema de Gestión de Ventas de Motos — "X Motors"** · Base de Datos I · Grupo 49 · FaCENA (UNNE)

> Lo marcado como **`[COMPLETAR]`** es un placeholder pendiente.

## 1. Integrantes

Rodriguez Rivas Milton Nahuel · Zacarías Blanco Fernando Iván · Balenzuela Tobías · Veglia Marcos Daniel · Zarate Arturo Alan


## 2. Objetivo

Implementar en **SQL Server** el modelo relacional de las etapas anteriores mediante:

- **Script DDL:** tablas, PK/FK con reglas de borrado/modificación, tipos de datos y restricciones (NOT NULL, UNIQUE, CHECK).
- **Script DML:** poblado inicial con **8 a 10 registros coherentes por tabla**.

## 3. Archivos y ejecución

| Archivo | Contenido |
|---|---|
| `DDL_Script_X_Motors.sql` | Creación de tablas, restricciones e índices |
| `DML_Script_X_Motors.sql` | Datos de prueba |

**Orden:** crear la base → ejecutar el DDL → ejecutar el DML. El DDL usa `USE [X MOTORS]` pero no crea la base, así que primero:

```sql
CREATE DATABASE [X MOTORS];
GO
```

Entorno: SQL Server 2022 · Cliente: SSMS / Azure Data Studio

## 4. Script DDL

### 4.1 Tablas (15)

- **Personas:** `persona`, `cliente`, `vendedor`, `direccion_cliente`
- **Catálogo:** `modelo_motocicleta`, `motocicleta`, `accesorio`
- **Proveedores:** `proveedor`, `direccion_proveedor`, `provision_motocicleta`, `provision_accesorio`
- **Ventas:** `venta`, `detalle_venta_accesorio`
- **Reglas de negocio:** `cotizacion`, `historial_de_precio`

### 4.2 Claves y reglas de borrado

- **PK:** simples (`dni`, `numero_chasis`, `cuit_proveedor`, o `IDENTITY` en modelo, accesorio, venta, cotización e historial) y compuestas en las tablas N:M (`provision_*`, `detalle_venta_accesorio`).
- **`ON DELETE CASCADE`:** solo en `vendedor` y `cliente` (hacia `persona`), `direccion_cliente` y `direccion_proveedor`, porque no tienen sentido sin su entidad principal.
- **`NO ACTION`:** en el resto, para preservar el historial (RN11).
- **`ON UPDATE`:** no declarado (por defecto, `NO ACTION`), ya que los identificadores principales representan valores de negocio estables y normalizados que nunca deberían cambiar una vez emitidos o registrados.

### 4.3 Tipos y restricciones

| Tema | Detalle |
|---|---|
| Tipos | `INT`, `BIGINT` (CUIL y CUIT, 11 dígitos), `VARCHAR(n)`, `DECIMAL(12,2)` (precios y montos), `DATE` |
| `UNIQUE` | `motocicleta.numero_motor`; índice único filtrado `ux_venta_chasis_vigente` (un chasis solo puede estar en **una venta `efectuada`**; las canceladas no cuentan) |
| `CHECK` de estados | `cliente.estado` (interesado / en proceso de compra / comprador) y `venta.estado` (efectuada / cancelada / reembolsada) |
| `CHECK` de valores | stock ≥ 0 (modelo y accesorio), precios ≥ 0, `cantidad` > 0, cotización con vencimiento a 7 días |
| `DEFAULT` | stock = 0 (modelo y accesorio), `venta.estado = 'efectuada'` |

### 4.4 Reglas de negocio que NO cubre el DDL

Descuento y reintegro automático de stock (RN1, RN2, RN11), pasaje del cliente a "comprador" (RN5), alta automática en `historial_de_precio` (RN7) y modelo con al menos un proveedor (RN8).
Las reglas de negocio complejas que no pueden resolverse únicamente mediante restricciones estáticas (como CHECK o FOREIGN KEY) en el DDL se implementan a través de Procedimientos Almacenados (Stored Procedures) combinados con Transacciones explicitas, y en algunos casos mediante la Capa de Aplicación o Triggers (Disparadores) en SQL Server:

- RN1 y RN2 (Descuento y control de stock de motos): Se implementan mediante un Procedimiento Almacenado de Venta que valida la existencia de stock disponible (stock_disponible > 0), descuenta una unidad de la tabla modelo_motocicleta y efectúa la inserción de forma atómica.

- RN5 (Pasaje automático del cliente a "comprador"): Se gestiona vía Trigger (AFTER INSERT en la tabla venta) o dentro del procedimiento almacenado de registro de ventas, el cual actualiza el campo estado de la tabla cliente a 'comprador' en caso de que su estado anterior fuera 'interesado' o 'en proceso de compra'.

- RN7 (Alta automática en historial_de_precio): Se implementa mediante un Trigger AFTER UPDATE sobre la columna precio_lista de la tabla modelo_motocicleta, el cual inserta de manera automática un registro en la tabla historial_de_precio reflejando el precio anterior, el nuevo precio y la fecha actual.

- RN8 (Modelo con al menos un proveedor): Se asegura mediante la lógica de validación de transacciones en la Capa de Aplicación al dar de alta un nuevo modelo en el catálogo, exigiendo que se registre al menos una tupla en la tabla asociativa provision_motocicleta.

## 5. Script DML

**Criterios:** 8 a 10 registros coherentes por tabla; columnas `IDENTITY` sin valor explícito; stock de cada modelo consistente con sus motocicletas y ventas.

**Orden de inserción:** `persona` → `vendedor`, `cliente` → `direccion_cliente` → `modelo_motocicleta` → `motocicleta` → `proveedor` → `direccion_proveedor` → `provision_motocicleta` → `accesorio` → `provision_accesorio` → `venta` → `detalle_venta_accesorio` → `cotizacion` → `historial_de_precio`



**Registros cargados por tabla: se usan iguales vendedores y clientes

tabla	Registros
persona	8 
vendedor	8
cliente	8
direccion_cliente	8
modelo_motocicleta	8
motocicleta	8
proveedor	8
direccion_proveedor	8
provision_motocicleta	8
accesorio	8
provision_accesorio	8
venta	8
detalle_venta_accesorio	8
cotizacion	8
historial_de_precio	8

## 6. Pruebas

Se realizaron pruebas para verificar el funcionamiento de las restricciones implementadas.

| Prueba | Resultado esperado | Resultado obtenido |
|---|---|---|
| Stock negativo en modelo o accesorio | Error de restricción `CHECK` | Correcto: SQL Server rechazó la operación debido a la restricción `CHECK` de stock mayor o igual a 0. |
| Estado inválido en venta o cliente | Error de restricción `CHECK` | Correcto: SQL Server rechazó la inserción debido a que el valor del estado no pertenece a los valores permitidos. |
| Dos ventas `efectuada` con el mismo chasis | Error del índice único | Correcto: SQL Server impidió la segunda venta efectuada del mismo chasis mediante el índice único filtrado `ux_venta_chasis_vigente`. |
| Venta `efectuada` sobre un chasis con una venta anterior `cancelada` | Operación permitida | Correcto: SQL Server permitió registrar la venta porque la venta anterior no tenía estado `efectuada`. |
| Venta con un cliente inexistente | Error de clave foránea | Correcto: SQL Server rechazó la operación por incumplimiento de la clave foránea hacia la tabla `cliente`. |
| Eliminación de una persona relacionada con ventas | Error de clave foránea | Correcto: SQL Server impidió eliminar la persona debido a la existencia de registros relacionados en la tabla `venta`. |

Consultas de los reportes (stock actual, historial de compras, ventas por vendedor, abastecimiento por proveedor):

- Stock actual de modelos de motocicletas:

SQL SELECT id_modelo, marca, nombre_modelo, cilindrada, anio, stock_disponible, precio_lista FROM modelo_motocicleta;

- Historial de compras de un cliente (ej. DNI 30456781):

SQL SELECT v.cod_venta, v.fecha, v.estado, v.metodo_pago, v.monto_total, m.marca, m.nombre_modelo, v.numero_chasis FROM venta v
JOIN motocicleta mot ON v.numero_chasis = mot.numero_chasis JOIN modelo_motocicleta m ON mot.id_modelo = m.id_modelo
WHERE v.dni_cliente = 30456781;

- Ventas totales agrupadas por vendedor:

SQL <script type="text/javascript"> SELECT p.dni, p.nombre, p.apellido, COUNT(v.cod_venta) AS total_ventas_efectuadas, SUM(v.monto_total) AS recaudacion_total FROM vendedor ven
JOIN persona p ON ven.dni_vendedor = p.dni LEFT JOIN venta v ON ven.dni_vendedor = v.dni_vendedor AND v.estado = 'efectuada' GROUP BY p.dni, p.nombre, p.apellido;

- Abastecimiento por proveedor (modelos que provee cada uno):

SQL SELECT pr.cuit_proveedor, pr.razon_social, m.id_modelo, m.marca, m.nombre_modelo FROM proveedor pr
JOIN provision_motocicleta pm ON pr.cuit_proveedor = pm.cuit_proveedor
JOIN modelo_motocicleta m ON pm.id_modelo = m.id_modelo;

## 7. Pendientes y diferencias con etapas anteriores

- Vendedor sin tabla de dirección (RF#4 pide ciudad y provincia): Se simplificó el modelo conceptual para optimizar la normalización, asumiendo que los vendedores operan de forma centralizada en el local principal de la concesionaria (registrado en los datos de la empresa) y no requieren un domicilio comercial individualizado como los clientes o proveedores.

- provision_accesorio no está en el documento: Se añadió en la implementación física como una tabla relacional N:M indispensable para mantener la trazabilidad de qué proveedores suministran qué repuestos o accesorios al inventario de la tienda.

- Un solo metodo_pago por venta, sin valores restringidos: Se modeló como un atributo VARCHAR(50) dentro de la tabla venta para simplificar la primera versión del sistema transaccional, dejando la apertura a múltiples formas de pago para iteraciones futuras del software.

- Un solo teléfono por persona y proveedor: Se definió una única columna telefono VARCHAR(30) de tipo atómico para cumplir estrictamente con la Primera Forma Normal (1FN), evitando campos multivaluados o redundantes en la misma tupla.

- Cotización: el CHECK exige exactamente 7 días, RN12 dice máximo 7: Se implementó una regla estricta de negocio a nivel de base de datos (fecha_vencimiento = DATEADD(day, 7, fecha_emision)) para estandarizar la validez de los presupuestos de forma exacta, a diferencia de la flexibilidad textual del documento conceptual.

- Sin UNIQUE ni validación de 11 dígitos en CUIL y CUIT: Se asumió la correcta carga de datos desde la capa de interfaz de usuario mediante máscaras de entrada, aunque se recomienda incorporar restricciones CHECK con longitudes exactas en futuras actualizaciones de seguridad.

- Nomenclatura distinta a ERD/RS (numero_chasis, cilindrada, monto_total, precio_pactado): Se unificaron los nombres de los atributos adoptando la convención en minúsculas con guiones bajos (snake_case) propia de SQL Server para mantener la legibilidad y evitar conflictos con palabras reservadas del motor de base de datos.

## 8. Entregables

- [x] Script DDL
- [x] Script DML (8 a 10 registros por tabla)


Fecha y medio de entrega: **`30 de septiembre de 2026 | GitHub | Manifiesto individual por AV Moodle.`**
