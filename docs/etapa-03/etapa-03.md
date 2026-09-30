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
| [`DDL_Script_X_Motors.sql`](../../sql/dll/DDL_Script_X_Motors.sql) | Creación de tablas, restricciones e índices |
| [`DML_Script_X_Motors.sql`](../../sql/dml/DML_Script_X_Motors.sql) | Datos de prueba |

**Orden:** crear la base → ejecutar el DDL → ejecutar el DML. El DDL usa `USE [X MOTORS]` pero no crea la base, así que primero:

```sql
CREATE DATABASE [X MOTORS];
GO
```

Entorno: SQL Server **`[COMPLETAR: versión]`** · Cliente: **`[COMPLETAR: SSMS / Azure Data Studio]`**

## 4. Script DDL

### 4.1 Tablas (15)

- **Personas:** `persona`, `cliente`, `vendedor`, `direccion_cliente`
- **Catálogo:** `modelo_motocicleta`, `motocicleta`, `accesorio`
- **Proveedores:** `proveedor`, `direccion_proveedor`, `provision_motocicleta`, `provision_accesorio`
- **Ventas:** `venta`, `detalle_venta_accesorio`
- **Reglas de negocio:** `cotizacion`, `historial_de_precio`

**`[COMPLETAR: imagen del esquema relacional final]`**

### 4.2 Claves y reglas de borrado

- **PK:** simples (`dni`, `numero_chasis`, `cuit_proveedor`, o `IDENTITY` en modelo, accesorio, venta, cotización e historial) y compuestas en las tablas N:M (`provision_*`, `detalle_venta_accesorio`).
- **`ON DELETE CASCADE`:** solo en `vendedor` y `cliente` (hacia `persona`), `direccion_cliente` y `direccion_proveedor`, porque no tienen sentido sin su entidad principal.
- **`NO ACTION`:** en el resto, para preservar el historial (RN11).
- **`ON UPDATE`:** no declarado (por defecto, `NO ACTION`). **`[COMPLETAR: justificar]`**

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

**Nota:** si cliente y vendedor tienen 8 registros cada uno y no se solapan, `persona` necesita al menos 16.

**Registros cargados por tabla:** **`[COMPLETAR]`**

## 6. Pruebas

| Prueba | Resultado esperado | Resultado obtenido |
|---|---|---|
| Stock negativo en modelo o accesorio | Error de `CHECK` | **`[COMPLETAR]`** |
| Estado inválido en venta o cliente | Error de `CHECK` | **`[COMPLETAR]`** |
| Dos ventas `efectuada` con el mismo chasis | Error de índice único | **`[COMPLETAR]`** |
| Venta `efectuada` sobre un chasis con venta anterior `cancelada` | Permitido | **`[COMPLETAR]`** |
| Venta con un cliente inexistente | Error de FK | **`[COMPLETAR]`** |
| Borrar una persona con ventas | Error de FK | **`[COMPLETAR]`** |

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

**`[COMPLETAR: copiar de la consigna]`**

- [x] Script DDL
- [ ] Script DML (8 a 10 registros por tabla)
- [ ] **`[COMPLETAR]`**

Fecha y medio de entrega: **`30 de septiembre de 2026 | GitHub | Manifiesto individual por AV Moodle.`**
