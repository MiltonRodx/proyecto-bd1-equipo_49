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
**`[COMPLETAR: dónde se implementan (triggers, procedimientos o aplicación)]`**

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

Consultas de los reportes (stock actual, historial de compras, ventas por vendedor, abastecimiento por proveedor): **`[COMPLETAR]`**

## 7. Pendientes y diferencias con etapas anteriores

- Vendedor sin tabla de dirección (RF#4 pide ciudad y provincia). **`[COMPLETAR]`**
- `provision_accesorio` no está en el documento. **`[COMPLETAR]`**
- Un solo `metodo_pago` por venta, sin valores restringidos (el documento habla de múltiples formas de pago). **`[COMPLETAR]`**
- Un solo teléfono por persona y proveedor (el documento usa el plural). **`[COMPLETAR]`**
- Cotización: el `CHECK` exige exactamente 7 días, RN12 dice máximo 7. **`[COMPLETAR]`**
- Sin `UNIQUE` ni validación de 11 dígitos en CUIL y CUIT. **`[COMPLETAR]`**
- Nomenclatura distinta a ERD/RS (`numero_chasis`, `cilindrada`, `monto_total`, `precio_pactado`). **`[COMPLETAR: unificar]`**

## 8. Entregables

- [x] Script DDL
- [x] Script DML (8 a 10 registros por tabla)


Fecha y medio de entrega: **`30 de septiembre de 2026 | GitHub | Manifiesto individual por AV Moodle.`**
