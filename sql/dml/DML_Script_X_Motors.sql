-- ============================================================================
-- ETAPA III - SCRIPT DML (poblado inicial / lote de prueba)
-- Sistema de Gestion de Ventas de Motos - X Motors - Grupo 49
-- Motor: SQL Server. Requiere el script DDL ya ejecutado sobre la base [X MOTORS].
--
-- NOTAS
--  * Datos ficticios (DNI, CUIL, CUIT, telefonos, emails @example.com).
--  * Sin tildes ni enie a proposito, para evitar problemas de encoding.
--  * Las columnas IDENTITY (modelo, accesorio, venta, cotizacion, historial) NO se
--    insertan: los ids salen 1..N en el orden de insercion, y las FK de este
--    script dependen de eso. Ejecutar sobre tablas vacias (ver bloque de reinicio).
--  * Como el DDL no tiene triggers, la consistencia (stock, monto_total, estado del
--    cliente) esta calculada a mano en estos datos. Las consultas de verificacion
--    del final devuelven 0 filas si todo es coherente.
--  * Todo corre en una transaccion: si algo falla, no queda nada cargado.
-- ============================================================================

USE [X MOTORS];
GO

SET XACT_ABORT ON; -- revertir automaticamente la transaccion en caso de errores en tiempo de ejecucion
BEGIN TRANSACTION;  -- inicio de transaccion!

-- ==========================================================================
-- 1. PERSONA (16 = 8 clientes + 8 vendedores, sin solaparse)
-- ==========================================================================
-- Plantilla: INSERT INTO persona (dni, nombre, apellido, cuil, telefono, email) VALUES (...);
INSERT INTO persona (dni, nombre, apellido, cuil, telefono, email) VALUES
  (30456781, 'Lucia', 'Fernandez', 27304567813, '+54 9 379 410-1100', 'lucia.fernandez@example.com'),
  (28345672, 'Martin', 'Gonzalez', 20283456720, '+54 9 379 411-1137', 'martin.gonzalez@example.com'),
  (35123903, 'Camila', 'Rojas', 27351239037, '+54 9 379 412-1174', 'camila.rojas@example.com'),
  (33987654, 'Sebastian', 'Acosta', 20339876544, '+54 9 379 413-1211', 'sebastian.acosta@example.com'),
  (40234567, 'Valentina', 'Benitez', 27402345671, '+54 9 379 414-1248', 'valentina.benitez@example.com'),
  (27654321, 'Diego', 'Romero', 20276543218, '+54 9 379 415-1285', 'diego.romero@example.com'),
  (38765432, 'Florencia', 'Sosa', 27387654325, '+54 9 379 416-1322', 'florencia.sosa@example.com'),
  (42111222, 'Nicolas', 'Duarte', 20421112222, '+54 9 379 417-1359', 'nicolas.duarte@example.com'),
  (31222333, 'Ana', 'Villalba', 27312223339, '+54 9 379 418-1396', 'ana.villalba@example.com'),
  (29876543, 'Carlos', 'Medina', 20298765436, '+54 9 379 419-1433', 'carlos.medina@example.com'),
  (34567890, 'Julieta', 'Ramirez', 27345678903, '+54 9 379 420-1470', 'julieta.ramirez@example.com'),
  (32109876, 'Federico', 'Aguirre', 20321098760, '+54 9 379 421-1507', 'federico.aguirre@example.com'),
  (36543210, 'Micaela', 'Cabrera', 27365432107, '+54 9 379 422-1544', 'micaela.cabrera@example.com'),
  (30999888, 'Pablo', 'Ortiz', 20309998884, '+54 9 379 423-1581', 'pablo.ortiz@example.com'),
  (37111444, 'Romina', 'Silva', 27371114441, '+54 9 379 424-1618', 'romina.silva@example.com'),
  (39222555, 'Gonzalo', 'Vera', 20392225558, '+54 9 379 425-1655', 'gonzalo.vera@example.com');

-- ==========================================================================
-- 2a. VENDEDOR (8)
-- ==========================================================================
-- Plantilla: INSERT INTO vendedor (dni_vendedor) VALUES (...);
INSERT INTO vendedor (dni_vendedor) VALUES
  (31222333),
  (29876543),
  (34567890),
  (32109876),
  (36543210),
  (30999888),
  (37111444),
  (39222555);

-- ==========================================================================
-- 2b. CLIENTE (8) - estados: interesado / en proceso de compra / comprador
-- ==========================================================================
-- RN5: 'comprador' solo si tiene al menos una venta efectuada.
-- Plantilla: INSERT INTO cliente (dni_cliente, estado) VALUES (...);
INSERT INTO cliente (dni_cliente, estado) VALUES
  (30456781, 'comprador'),
  (28345672, 'comprador'),
  (35123903, 'comprador'),
  (33987654, 'en proceso de compra'),
  (40234567, 'comprador'),
  (27654321, 'comprador'),
  (38765432, 'en proceso de compra'),
  (42111222, 'interesado');

-- ==========================================================================
-- 3. DIRECCION_CLIENTE (8)
-- ==========================================================================
-- Plantilla: INSERT INTO direccion_cliente (dni_cliente, calle, numero, ciudad, provincia, codigo_postal) VALUES (...);
INSERT INTO direccion_cliente (dni_cliente, calle, numero, ciudad, provincia, codigo_postal) VALUES
  (30456781, 'Junin', 450, 'Corrientes', 'Corrientes', 'W3400'),
  (28345672, 'Salta', 1230, 'Corrientes', 'Corrientes', 'W3400'),
  (35123903, 'Av. Armenia', 2100, 'Resistencia', 'Chaco', 'H3500'),
  (33987654, 'Belgrano', 780, 'Goya', 'Corrientes', 'W3450'),
  (40234567, 'Mitre', 95, 'Paso de los Libres', 'Corrientes', 'W3230'),
  (27654321, 'Av. 3 de Abril', 1500, 'Corrientes', 'Corrientes', 'W3400'),
  (38765432, 'San Martin', 320, 'Posadas', 'Misiones', 'N3300'),
  (42111222, 'Rivadavia', 610, 'Presidencia Roque Saenz Pena', 'Chaco', 'H3700');

-- ==========================================================================
-- 4. MODELO_MOTOCICLETA (10) - ids 1..10
-- ==========================================================================
-- stock_disponible = unidades cargadas en motocicleta - unidades con venta 'efectuada'. Modelos 2, 4 y 6 quedan en 0 (prueba de RN2).
-- Plantilla: INSERT INTO modelo_motocicleta (nombre_modelo, marca, cilindrada, color, anio, stock_disponible, precio_lista) VALUES (...);
INSERT INTO modelo_motocicleta (nombre_modelo, marca, cilindrada, color, anio, stock_disponible, precio_lista) VALUES
  ('CB 125F Twister', 'Honda', 125, 'Rojo', 2026, 1, 3850000.00),
  ('XR 150L', 'Honda', 150, 'Negro', 2026, 0, 4900000.00),
  ('Smash 110', 'Gilera', 110, 'Azul', 2026, 1, 2650000.00),
  ('Skua 150', 'Motomel', 150, 'Verde', 2025, 0, 3100000.00),
  ('FZ-S FI 150', 'Yamaha', 150, 'Gris', 2026, 1, 5400000.00),
  ('MT-03', 'Yamaha', 321, 'Azul', 2026, 0, 11200000.00),
  ('RX 200', 'Zanella', 200, 'Blanco', 2025, 1, 3700000.00),
  ('Energy 110', 'Corven', 110, 'Rojo', 2026, 1, 2400000.00),
  ('Rouser NS200', 'Bajaj', 200, 'Negro', 2026, 1, 5900000.00),
  ('Ninja 400', 'Kawasaki', 399, 'Verde', 2026, 1, 14500000.00);

-- ==========================================================================
-- 5. MOTOCICLETA (14 unidades)
-- ==========================================================================
-- Plantilla: INSERT INTO motocicleta (numero_chasis, numero_motor, id_modelo) VALUES (...);
INSERT INTO motocicleta (numero_chasis, numero_motor, id_modelo) VALUES
  ('9C2HON00000000001', 'MOT-HON-000001', 1),
  ('9C2HON00000000002', 'MOT-HON-000002', 1),
  ('9C2HON00000000003', 'MOT-HON-000003', 2),
  ('9C2GIL00000000004', 'MOT-GIL-000004', 3),
  ('9C2GIL00000000005', 'MOT-GIL-000005', 3),
  ('9C2MTM00000000006', 'MOT-MTM-000006', 4),
  ('9C2YAM00000000007', 'MOT-YAM-000007', 5),
  ('9C2YAM00000000008', 'MOT-YAM-000008', 6),
  ('9C2ZAN00000000009', 'MOT-ZAN-000009', 7),
  ('9C2COR00000000010', 'MOT-COR-000010', 8),
  ('9C2COR00000000011', 'MOT-COR-000011', 8),
  ('9C2BAJ00000000012', 'MOT-BAJ-000012', 9),
  ('9C2KAW00000000013', 'MOT-KAW-000013', 10),
  ('9C2KAW00000000014', 'MOT-KAW-000014', 10);

-- ==========================================================================
-- 6. PROVEEDOR (8)
-- ==========================================================================
-- Plantilla: INSERT INTO proveedor (cuit_proveedor, razon_social, email, telefono) VALUES (...);
INSERT INTO proveedor (cuit_proveedor, razon_social, email, telefono) VALUES
  (30712345671, 'Distribuidora Honda del Litoral S.R.L.', 'ventas@hondalitoral.example.com', '+54 379 442-1001'),
  (30698765432, 'Yamaha Motor Argentina S.A.', 'comercial@yamahamotor.example.com', '+54 11 4321-1002'),
  (30701234563, 'Gilera Motos Mesopotamia S.A.', 'pedidos@gilerameso.example.com', '+54 376 443-1003'),
  (30655544335, 'Motomel Comercial S.A.', 'mayoristas@motomel.example.com', '+54 11 4555-1004'),
  (30644433324, 'Zanella Hnos. y Cia. S.A.', 'ventas@zanella.example.com', '+54 11 4444-1005'),
  (30733322213, 'Corven Motos S.A.', 'distribuidores@corven.example.com', '+54 341 422-1006'),
  (30722211102, 'Bajaj Auto Argentina S.A.', 'info@bajajarg.example.com', '+54 351 433-1007'),
  (30711100091, 'Kawasaki Importadora S.R.L.', 'ventas@kawaimport.example.com', '+54 11 4666-1008');

-- ==========================================================================
-- 7. DIRECCION_PROVEEDOR (8)
-- ==========================================================================
-- Plantilla: INSERT INTO direccion_proveedor (cuit_proveedor, calle, numero, ciudad, provincia, codigo_postal) VALUES (...);
INSERT INTO direccion_proveedor (cuit_proveedor, calle, numero, ciudad, provincia, codigo_postal) VALUES
  (30712345671, 'Av. Ferre', 2450, 'Corrientes', 'Corrientes', 'W3400'),
  (30698765432, 'Av. Libertador', 4500, 'Vicente Lopez', 'Buenos Aires', 'B1638'),
  (30701234563, 'Av. Uruguay', 1800, 'Posadas', 'Misiones', 'N3300'),
  (30655544335, 'Av. Gral. Paz', 7200, 'San Martin', 'Buenos Aires', 'B1650'),
  (30644433324, 'Ruta 8 Km 34', 0, 'Pilar', 'Buenos Aires', 'B1629'),
  (30733322213, 'Bv. Orono', 950, 'Rosario', 'Santa Fe', 'S2000'),
  (30722211102, 'Av. Colon', 3100, 'Cordoba', 'Cordoba', 'X5000'),
  (30711100091, 'Av. Cabildo', 2050, 'CABA', 'Buenos Aires', 'C1428');

-- ==========================================================================
-- 8. PROVISION_MOTOCICLETA (11) - todo modelo con al menos un proveedor (RN8); el modelo 3 tiene dos
-- ==========================================================================
-- Plantilla: INSERT INTO provision_motocicleta (cuit_proveedor, id_modelo) VALUES (...);
INSERT INTO provision_motocicleta (cuit_proveedor, id_modelo) VALUES
  (30712345671, 1),
  (30712345671, 2),
  (30701234563, 3),
  (30655544335, 3),
  (30655544335, 4),
  (30698765432, 5),
  (30698765432, 6),
  (30644433324, 7),
  (30733322213, 8),
  (30722211102, 9),
  (30711100091, 10);

-- ==========================================================================
-- 9. ACCESORIO (10) - ids 1..10
-- ==========================================================================
-- stock = stock inicial - unidades vendidas en ventas 'efectuadas' (las canceladas/reembolsadas se reintegran).
-- Plantilla: INSERT INTO accesorio (descripcion, stock, categoria, precio_lista, precio_costo) VALUES (...);
INSERT INTO accesorio (descripcion, stock, categoria, precio_lista, precio_costo) VALUES
  ('Casco integral ABS', 11, 'casco', 185000.00, 120000.00),
  ('Casco abierto', 11, 'casco', 98000.00, 62000.00),
  ('Guantes de cuero', 18, 'indumentaria', 42000.00, 25000.00),
  ('Campera con protecciones', 9, 'indumentaria', 165000.00, 105000.00),
  ('Baul trasero 35L', 7, 'equipamiento', 78000.00, 48000.00),
  ('Candado de disco', 12, 'seguridad', 36000.00, 21000.00),
  ('Cubre moto impermeable', 9, 'equipamiento', 29000.00, 16000.00),
  ('Kit de herramientas', 6, 'repuesto', 54000.00, 33000.00),
  ('Aceite 10W40 1L', 38, 'repuesto', 14500.00, 9000.00),
  ('Pastillas de freno delanteras', 8, 'repuesto', 38000.00, 24000.00);

-- ==========================================================================
-- 10. PROVISION_ACCESORIO (11)
-- ==========================================================================
-- Plantilla: INSERT INTO provision_accesorio (cuit_proveedor, id_accesorio) VALUES (...);
INSERT INTO provision_accesorio (cuit_proveedor, id_accesorio) VALUES
  (30712345671, 1),
  (30698765432, 1),
  (30712345671, 2),
  (30701234563, 3),
  (30701234563, 4),
  (30655544335, 5),
  (30644433324, 6),
  (30733322213, 7),
  (30722211102, 8),
  (30698765432, 9),
  (30711100091, 10);

-- ==========================================================================
-- 11. VENTA (10) - ids 1..10: 7 efectuadas, 2 canceladas, 1 reembolsada
-- ==========================================================================
-- monto_total = precio_venta_moto + suma(cantidad * precio_pactado) de sus accesorios.
-- Ventas 4 y 5: mismo chasis; la 4 esta cancelada y la 5 (posterior) efectuada -> valida el indice filtrado.
-- La venta 10 no lleva accesorios (son opcionales, RN10).
-- Plantilla: INSERT INTO venta (fecha, metodo_pago, precio_venta_moto, monto_total, estado, dni_cliente, dni_vendedor, numero_chasis) VALUES (...);
INSERT INTO venta (fecha, metodo_pago, precio_venta_moto, monto_total, estado, dni_cliente, dni_vendedor, numero_chasis) VALUES
  ('2026-03-05', 'transferencia bancaria', 3650000.00, 3877000.00, 'efectuada', 30456781, 31222333, '9C2HON00000000001'),
  ('2026-03-18', 'efectivo', 2600000.00, 2811750.00, 'efectuada', 28345672, 29876543, '9C2GIL00000000004'),
  ('2026-04-09', 'financiamiento', 10700000.00, 10868200.00, 'efectuada', 35123903, 34567890, '9C2YAM00000000008'),
  ('2026-04-22', 'tarjeta de credito', 4900000.00, 5065000.00, 'cancelada', 33987654, 31222333, '9C2HON00000000003'),
  ('2026-05-14', 'transferencia bancaria', 4800000.00, 5056000.00, 'efectuada', 40234567, 29876543, '9C2HON00000000003'),
  ('2026-06-02', 'efectivo', 2400000.00, 2429000.00, 'efectuada', 27654321, 32109876, '9C2COR00000000010'),
  ('2026-06-25', 'tarjeta de credito', 5900000.00, 6052000.00, 'reembolsada', 28345672, 34567890, '9C2BAJ00000000012'),
  ('2026-07-20', 'financiamiento', 13700000.00, 14077750.00, 'efectuada', 35123903, 36543210, '9C2KAW00000000013'),
  ('2026-08-18', 'transferencia bancaria', 3100000.00, 3138000.00, 'efectuada', 30456781, 30999888, '9C2MTM00000000006'),
  ('2026-09-03', 'tarjeta de credito', 5400000.00, 5400000.00, 'cancelada', 30456781, 36543210, '9C2YAM00000000007');

-- ==========================================================================
-- 12. DETALLE_VENTA_ACCESORIO (17)
-- ==========================================================================
-- precio_pactado puede diferir del precio_lista del accesorio (RN6).
-- Plantilla: INSERT INTO detalle_venta_accesorio (cod_venta, id_accesorio, cantidad, precio_pactado) VALUES (...);
INSERT INTO detalle_venta_accesorio (cod_venta, id_accesorio, cantidad, precio_pactado) VALUES
  (1, 1, 1, 185000.00),
  (1, 3, 1, 42000.00),
  (2, 1, 1, 175750.00),
  (2, 6, 1, 36000.00),
  (3, 2, 1, 98000.00),
  (3, 5, 1, 70200.00),
  (4, 4, 1, 165000.00),
  (5, 1, 1, 185000.00),
  (5, 3, 1, 42000.00),
  (5, 9, 2, 14500.00),
  (6, 7, 1, 29000.00),
  (7, 2, 1, 98000.00),
  (7, 8, 1, 54000.00),
  (8, 1, 1, 185000.00),
  (8, 4, 1, 156750.00),
  (8, 6, 1, 36000.00),
  (9, 10, 1, 38000.00);

-- ==========================================================================
-- 13. COTIZACION (10) - vencimiento = emision + 7 dias (CHECK del DDL)
-- ==========================================================================
-- Plantilla: INSERT INTO cotizacion (fecha_emision, fecha_vencimiento, precio_cotizado, dni_cliente, id_modelo) VALUES (...);
INSERT INTO cotizacion (fecha_emision, fecha_vencimiento, precio_cotizado, dni_cliente, id_modelo) VALUES
  ('2026-02-25', '2026-03-04', 3650000.00, 30456781, 1),
  ('2026-03-10', '2026-03-17', 2650000.00, 28345672, 3),
  ('2026-04-01', '2026-04-08', 10900000.00, 35123903, 6),
  ('2026-04-15', '2026-04-22', 4900000.00, 33987654, 2),
  ('2026-05-08', '2026-05-15', 4900000.00, 40234567, 2),
  ('2026-05-26', '2026-06-02', 2400000.00, 27654321, 8),
  ('2026-09-24', '2026-10-01', 5400000.00, 38765432, 5),
  ('2026-09-26', '2026-10-03', 5900000.00, 42111222, 9),
  ('2026-09-10', '2026-09-17', 3850000.00, 42111222, 1),
  ('2026-09-28', '2026-10-05', 3700000.00, 38765432, 7);

-- ==========================================================================
-- 14. HISTORIAL_DE_PRECIO (10)
-- ==========================================================================
-- El ultimo precio_nuevo de cada modelo coincide con su precio_lista actual.
-- Plantilla: INSERT INTO historial_de_precio (precio_nuevo, precio_anterior, fecha_modificacion, id_modelo) VALUES (...);
INSERT INTO historial_de_precio (precio_nuevo, precio_anterior, fecha_modificacion, id_modelo) VALUES
  (3650000.00, 3500000.00, '2026-02-10', 1),
  (3850000.00, 3650000.00, '2026-06-20', 1),
  (4900000.00, 4600000.00, '2026-04-05', 2),
  (2650000.00, 2500000.00, '2026-03-01', 3),
  (5400000.00, 5100000.00, '2026-05-12', 5),
  (10900000.00, 10400000.00, '2026-02-20', 6),
  (11200000.00, 10900000.00, '2026-07-15', 6),
  (5900000.00, 5500000.00, '2026-06-01', 9),
  (14000000.00, 13500000.00, '2026-03-15', 10),
  (14500000.00, 14000000.00, '2026-08-10', 10);

COMMIT TRANSACTION;  -- confirmacion de transacción! (usamos la herramienta de transacciones como buena práctica, a pesar de ser una base de datos de prueba)
GO



-- ============================================================================
-- PRUEBAS NEGATIVAS (descomentar de a UNA; cada una debe fallar)
-- ============================================================================
-- N1. Stock negativo                        -> error ck_modelo_stock
-- UPDATE modelo_motocicleta SET stock_disponible = -1 WHERE id_modelo = 1;

-- N2. Estado de venta invalido              -> error ck_venta_estado
-- UPDATE venta SET estado = 'pendiente' WHERE cod_venta = 1;

-- N3. Segunda venta efectuada del mismo chasis (el de la venta 1) -> error ux_venta_chasis_vigente
-- INSERT INTO venta (fecha, metodo_pago, precio_venta_moto, monto_total, estado, dni_cliente, dni_vendedor, numero_chasis)
-- SELECT '2026-09-20', 'efectivo', 1000.00, 1000.00, 'efectuada', 30456781, 31222333, numero_chasis FROM venta WHERE cod_venta = 1;

-- N4. Venta con cliente inexistente         -> error de FK
-- INSERT INTO venta (fecha, metodo_pago, precio_venta_moto, monto_total, estado, dni_cliente, dni_vendedor, numero_chasis)
-- SELECT '2026-09-20', 'efectivo', 1000.00, 1000.00, 'efectuada', 99999999, 31222333, numero_chasis FROM motocicleta WHERE id_modelo = 5;

-- N5. Numero de motor repetido              -> error uq_motocicleta_numero_motor
-- INSERT INTO motocicleta (numero_chasis, numero_motor, id_modelo)
-- SELECT 'CHASIS-DUPLICADO-01', numero_motor, id_modelo FROM motocicleta WHERE id_modelo = 1;

-- N6. Cotizacion con vencimiento a 10 dias  -> error ck_cotizacion_validez_7_dias
-- INSERT INTO cotizacion (fecha_emision, fecha_vencimiento, precio_cotizado, dni_cliente, id_modelo)
-- VALUES ('2026-09-01', '2026-09-11', 1000.00, 30456781, 1);

-- N7. Borrar una persona con ventas         -> error de FK (cliente -> venta, sin cascada)
-- DELETE FROM persona WHERE dni = 30456781;