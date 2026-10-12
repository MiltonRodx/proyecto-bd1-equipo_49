-- ============================================================================
-- ETAPA III - SCRIPT DML (poblado inicial / lote de prueba) - UNIFICADO
-- Sistema de Gestion de Ventas de Motos - X Motors - Grupo 49
-- Motor: SQL Server. Requiere el script DDL ya ejecutado sobre la base [X MOTORS].
-- (DDL bueno con indice filtrado ux_venta_chasis_vigente, NO el UNIQUE simple).
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
--  * UNIFICADO: base DML_Script_X_Motors.sql (correcto) + 3 lotes corregidos.
--    TOTAL: 50 personas, 28 vendedores, 30 clientes, 30 direcciones cli,
--    32 modelos, 43 motos, 29 proveedores, 29 direcciones prov,
--    35 provision_moto, 33 accesorios, 35 provision_accesorio,
--    30 ventas, 38 detalles, 31 cotizaciones, 34 historiales.
--  * Correcciones: A) DNI 31222333 colisionaba -> Luis pasa a 31222334;
--    stock A 3/2/2/2, venta 11 a 8755000. B) CUIT 14 digitos -> 30300000011..88;
--    8 montos y stocks recalculados; 2 clientes a 'comprador' (RN5).
--    C) 10 personas faltantes agregadas (10667788..11001122, 20666777..21000112);
--    stocks 0 salvo mod.30=1; 7 montos recalculados; sin tildes.
-- ============================================================================

USE [X MOTORS];
GO

SET XACT_ABORT ON; -- revertir automaticamente la transaccion en caso de errores en tiempo de ejecucion
BEGIN TRANSACTION;  -- inicio de transaccion!

-- ==========================================================================
-- 1. PERSONA 
-- RN: dni unico. Lote A: Luis Fernandez pasa a 31222334 por colision con Ana Villalba (31222333). Lote C: se agregan 10 personas faltantes.
-- ==========================================================================
-- Buenos (16)
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
  (39222555, 'Gonzalo', 'Vera', 20392225558, '+54 9 379 425-1655', 'gonzalo.vera@example.com'),
-- Lote A 
  (30111222, 'Juan', 'Perez', 20301112225, '3794551234', 'juan.perez@gmail.com'),
  (32444555, 'Maria', 'Gomez', 27324445559, '3794123456', 'maria.gomez@gmail.com'),
  (28777888, 'Carlos', 'Lopez', 20287778883, '3794987654', 'carlos.lopez@gmail.com'),
  (35666999, 'Ana', 'Martinez', 27356669994, '3794567890', 'ana.martinez@gmail.com'),
  (31222334, 'Luis', 'Fernandez', 20312223342, '3794234567', 'luis.fernandez@gmail.com'),
  (29888777, 'Sofia', 'Ramirez', 27298887776, '3794345678', 'sofia.ramirez@gmail.com'),
-- Lote B 
  (41234567, 'Tobias', 'Balenzuela', 20412345673, '3795126840', 'tobias.balenzuela@correo.com'),
  (39876543, 'Santiago', 'Villalba', 20398765436, '3796237519', 'santiago.villalba@correo.com'),
  (42654321, 'Cyntia', 'Ruiz', 27426543218, '3797348261', 'cyntia.ruiz@correo.com'),
  (38456789, 'Juan', 'Balenzuela', 20384567896, '3798459132', 'juan.balenzuela@correo.com'),
  (43567890, 'Irina', 'Balenzuela', 27435678908, '3799562741', 'irina.balenzuela@correo.com'),
  (37654321, 'Octavio', 'Dorrego', 20376543219, '3791673852', 'octavio.dorrego@correo.com'),
  (40987654, 'Ignacio', 'Arce', 20409876547, '3792784963', 'ignacio.arce@correo.com'),
  (45123456, 'Julian', 'Cabral', 20451234568, '3793895174', 'julian.cabral@correo.com'),
-- Lote C 
  (10111222, 'Carlos', 'Gomez', 20101112229, '1155443322', 'carlos.gomez@xmotors.com'),
  (10222333, 'Mariana', 'Lopez', 27102223334, '1166778899', 'mariana.lopez@xmotors.com'),
  (10333444, 'Esteban', 'Martinez', 20103334445, '1144332211', 'esteban.martinez@xmotors.com'),
  (10444555, 'Lucia', 'Fernandez', 27104445556, '1122334455', 'lucia.fernandez@xmotors.com'),
  (10556677, 'Jorge', 'Perez', 20105566771, '1199887766', 'jorge.perez@xmotors.com'),
  (20111222, 'Juan', 'Perez', 20201112229, '1111223344', 'juan.perez2@gmail.com'),
  (20222333, 'Maria', 'Gimenez', 27202223334, '1122334455', 'maria.gimenez@hotmail.com'),
  (20333444, 'Lucas', 'Silva', 20203334445, '1133445566', 'lucas.silva@yahoo.com'),
  (20444555, 'Florencia', 'Rios', 27204445556, '1144556677', 'florencia.rios@gmail.com'),
  (20555666, 'Diego', 'Medina', 20205556667, '1155667788', 'diego.medina@outlook.com'),
  (10667788, 'Santiago', 'Nunez', 20106677883, '1166112233', 'santiago.nunez@xmotors.com'),
  (10778899, 'Paula', 'Diaz', 27107788990, '1166223344', 'paula.diaz@xmotors.com'),
  (10889900, 'Martin', 'Castro', 20108899007, '1166334455', 'martin.castro@xmotors.com'),
  (10990011, 'Laura', 'Torres', 27109900118, '1166445566', 'laura.torres@xmotors.com'),
  (11001122, 'Andres', 'Ruiz', 20110011229, '1166556677', 'andres.ruiz@xmotors.com'),
  (20666777, 'Carla', 'Sosa', 27206667770, '1166667788', 'carla.sosa@gmail.com'),
  (20777888, 'Hugo', 'Benitez', 20207778881, '1166778899', 'hugo.benitez@gmail.com'),
  (20888990, 'Elena', 'Flores', 27208889902, '1166889900', 'elena.flores@gmail.com'),
  (20999001, 'Ricardo', 'Ojeda', 20209990013, '1166990011', 'ricardo.ojeda@gmail.com'),
  (21000112, 'Nora', 'Aguirre', 27210001124, '1166001122', 'nora.aguirre@gmail.com');

-- ==========================================================================
-- 2a. VENDEDOR 
-- ==========================================================================
-- Plantilla: INSERT INTO vendedor (dni_vendedor) VALUES (...);
INSERT INTO vendedor (dni_vendedor) VALUES
  (31222333), (29876543), (34567890), (32109876), (36543210), (30999888), (37111444), (39222555),
  (30111222), (28777888),
  (41234567), (39876543), (42654321), (38456789), (43567890), (37654321), (40987654), (45123456),
  (10111222), (10222333), (10333444), (10444555), (10556677),
  (10667788), (10778899), (10889900), (10990011), (11001122);

-- ==========================================================================
-- 2b. CLIENTE (30) - estados: interesado / en proceso de compra / comprador
-- RN5: 'comprador' solo si tiene al menos una venta efectuada. Lote B: 39876543 y 42654321 pasan a 'comprador'. Lote C: 20555666 ya queda en 'en proceso de compra'.
-- ==========================================================================
-- Plantilla: INSERT INTO cliente (dni_cliente, estado) VALUES (...);
INSERT INTO cliente (dni_cliente, estado) VALUES
  (30456781, 'comprador'), (28345672, 'comprador'), (35123903, 'comprador'),
  (33987654, 'en proceso de compra'), (40234567, 'comprador'), (27654321, 'comprador'),
  (38765432, 'en proceso de compra'), (42111222, 'interesado'),
  (32444555, 'interesado'), (35666999, 'en proceso de compra'),
  (31222334, 'comprador'), (29888777, 'comprador'),
  (41234567, 'comprador'), (39876543, 'comprador'), (42654321, 'comprador'),
  (38456789, 'comprador'), (43567890, 'interesado'), (37654321, 'comprador'),
  (40987654, 'en proceso de compra'), (45123456, 'comprador'),
  (20111222, 'comprador'), (20222333, 'comprador'), (20333444, 'comprador'),
  (20444555, 'en proceso de compra'), (20555666, 'en proceso de compra'),
  (20666777, 'comprador'), (20777888, 'en proceso de compra'), (20888990, 'interesado'),
  (20999001, 'comprador'), (21000112, 'comprador');

-- ==========================================================================
-- 3. DIRECCION_CLIENTE 
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
  (42111222, 'Rivadavia', 610, 'Presidencia Roque Saenz Pena', 'Chaco', 'H3700'),
  (32444555, 'Av. 3 de Abril', 1250, 'Corrientes', 'Corrientes', '3400'),
  (35666999, 'Junin', 850, 'Corrientes', 'Corrientes', '3400'),
  (31222334, 'San Martin', 1450, 'Corrientes', 'Corrientes', '3400'),
  (29888777, 'Espana', 720, 'Resistencia', 'Chaco', '3500'),
  (41234567, 'Calle de Alcala', 184, 'Madrid', 'Madrid', '28009'),
  (39876543, 'Carrer de Valencia', 317, 'Barcelona', 'Barcelona', '08009'),
  (42654321, 'Calle Colon', 42, 'Valencia', 'Valencia', '46004'),
  (38456789, 'Calle San Fernando', 28, 'Sevilla', 'Sevilla', '41004'),
  (43567890, 'Calle Larios', 91, 'Malaga', 'Malaga', '29005'),
  (37654321, 'Calle Mayor', 63, 'Salamanca', 'Salamanca', '37002'),
  (40987654, 'Avenida de Galicia', 116, 'Vigo', 'Pontevedra', '36201'),
  (45123456, 'Calle Alfonso I', 37, 'Zaragoza', 'Zaragoza', '50003'),
  (20111222, 'Av. Corrientes', 1234, 'Capital Federal', 'Buenos Aires', 'C1043'),
  (20222333, 'San Martin', 456, 'Rosario', 'Santa Fe', 'S2000'),
  (20333444, 'Bv. 27 de Febrero', 789, 'Cordoba', 'Cordoba', 'X5000'),
  (20444555, 'Rivadavia', 1500, 'Mendoza', 'Mendoza', 'M5500'),
  (20555666, 'San Lorenzo', 321, 'Salta', 'Salta', 'A4400'),
  (20666777, 'Belgrano', 987, 'San Miguel de Tucuman', 'Tucuman', 'T4000'),
  (20777888, 'Mitre', 654, 'Parana', 'Entre Rios', 'E3100'),
  (20888990, 'Espana', 200, 'Neuquen', 'Neuquen', 'Q8300'),
  (20999001, 'Sarmiento', 1110, 'Mar del Plata', 'Buenos Aires', 'B7600'),
  (21000112, '9 de Julio', 450, 'Corrientes', 'Corrientes', 'W3400');

-- ==========================================================================
-- 4. MODELO_MOTOCICLETA 
-- stock_disponible = unidades cargadas en motocicleta - unidades con venta 'efectuada'. Lote A: 3/2/2/2. Lote B: 0/0/1/0/1/0/0/0. Lote C: 0 salvo id 30 = 1 (cancelada).
-- ==========================================================================
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
  ('Ninja 400', 'Kawasaki', 399, 'Verde', 2026, 1, 14500000.00),
  ('CB500F', 'Honda', 500, 'Rojo', 2025, 3, 8500000.00),
  ('MT-03', 'Yamaha', 321, 'Azul', 2025, 2, 9200000.00),
  ('Dominar 400', 'Bajaj', 373, 'Negro', 2025, 2, 7800000.00),
  ('Z400', 'Kawasaki', 399, 'Verde', 2025, 2, 10500000.00),
  ('Zontes G1-125', 'Zontes', 125, 'Negro', 2024, 0, 4850000.00),
  ('Zontes U1-125', 'Zontes', 125, 'Azul', 2023, 0, 4520000.00),
  ('Montesa Cota 4RT', 'Montesa', 301, 'Rojo', 2025, 1, 8900000.00),
  ('Rieju MRT 125', 'Rieju', 125, 'Blanco', 2024, 0, 5200000.00),
  ('Rieju Aventura 500', 'Rieju', 500, 'Verde', 2025, 1, 11800000.00),
  ('GasGas EC 250', 'GasGas', 250, 'Rojo', 2024, 0, 10500000.00),
  ('GasGas SM 700', 'GasGas', 700, 'Negro', 2025, 0, 15600000.00),
  ('Derbi Senda 125', 'Derbi', 125, 'Amarillo', 2023, 0, 4900000.00),
  ('CB 250 Twister', 'Honda', 250, 'Rojo', 2025, 0, 4500000.00),
  ('FZ-S Fi', 'Yamaha', 150, 'Azul', 2025, 0, 3200000.00),
  ('Duke 200', 'KTM', 200, 'Naranja', 2024, 0, 5800000.00),
  ('Gixxer 250', 'Suzuki', 250, 'Negro', 2025, 0, 4800000.00),
  ('Ns 200', 'Bajaj', 200, 'Amarillo', 2025, 0, 3600000.00),
  ('TVS RTR 200', 'TVS', 200, 'Gris', 2024, 0, 3400000.00),
  ('XR 190L', 'Honda', 190, 'Blanco', 2025, 0, 4100000.00),
  ('MT-03', 'Yamaha', 321, 'Cyan', 2024, 1, 7500000.00),
  ('RC 390', 'KTM', 390, 'Blanco/Naranja', 2024, 0, 8900000.00),
  ('Dominar 400', 'Bajaj', 400, 'Verde', 2025, 0, 6200000.00);

-- ==========================================================================
-- 5. MOTOCICLETA (43 unidades)
-- Lote A 
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
  ('9C2KAW00000000014', 'MOT-KAW-000014', 10),
  ('HONCB500F001', 'HONMOT500001', 11),
  ('HONCB500F002', 'HONMOT500002', 11),
  ('HONCB500F003', 'HONMOT500003', 11),
  ('HONCB500F004', 'HONMOT500004', 11),
  ('YAMMT03001', 'YAMMOT03001', 12),
  ('YAMMT03002', 'YAMMOT03002', 12),
  ('YAMMT03003', 'YAMMOT03003', 12),
  ('BAJDOM40001', 'BAJMOT40001', 13),
  ('BAJDOM40002', 'BAJMOT40002', 13),
  ('KAWZ400001', 'KAWMOT40001', 14),
  ('KAWZ400002', 'KAWMOT40002', 14),
  ('ES-ZON-874521', 'ZON-MTR-583214', 15),
  ('ES-ZON-639847', 'ZON-MTR-741925', 16),
  ('ES-MON-528316', 'MON-MTR-936184', 17),
  ('ES-RIE-417925', 'RIE-MTR-625731', 18),
  ('ES-RIE-753184', 'RIE-MTR-814263', 19),
  ('ES-GAS-286415', 'GAS-MTR-572936', 20),
  ('ES-GAS-941753', 'GAS-MTR-318475', 21),
  ('ES-DER-635829', 'DER-MTR-764218', 22),
  ('CHS89123401', 'MOT98123401', 23),
  ('CHS89123402', 'MOT98123402', 23),
  ('CHS89123403', 'MOT98123403', 24),
  ('CHS89123404', 'MOT98123404', 25),
  ('CHS89123405', 'MOT98123405', 26),
  ('CHS89123406', 'MOT98123406', 27),
  ('CHS89123407', 'MOT98123407', 28),
  ('CHS89123408', 'MOT98123408', 29),
  ('CHS89123409', 'MOT98123409', 30),
  ('CHS89123410', 'MOT98123410', 32);

-- ==========================================================================
-- 6. PROVEEDOR (29)
-- Lote B 
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
  (30711100091, 'Kawasaki Importadora S.R.L.', 'ventas@kawaimport.example.com', '+54 11 4666-1008'),
  (30711223344, 'Motos Argentinas SA', 'ventas@motosargentinas.com', '3794556677'),
  (30722334455, 'Importadora del Litoral SA', 'contacto@importadoralitoral.com', '3794667788'),
  (30733445566, 'Repuestos del Nordeste SRL', 'ventas@repuestosnordeste.com', '3794778899'),
  (30300000011, 'Moto Brasil Distribuidora Ltda', 'contato@motobrasil.com.br', '+551132145678'),
  (30300000022, 'Rodas do Sul Ltda', 'vendas@rodasdoul.com.br', '+555132567890'),
  (30300000033, 'Brasil Moto Pecas Ltda', 'comercial@brasilmoto.com.br', '+552132789456'),
  (30300000044, 'Amazonia Motors Ltda', 'vendas@amazoniamotors.com.br', '+559132456781'),
  (30300000055, 'Paulista Motos Importacao', 'info@paulistamotos.com.br', '+551134678925'),
  (30300000066, 'Sul Brasil Acessorios', 'contato@sulbrasil.com.br', '+555133789214'),
  (30300000077, 'Rio Moto Distribuidora', 'vendas@riomoto.com.br', '+552125689743'),
  (30300000088, 'Brasil Motorcycles Trade', 'trade@brmotorcycles.com.br', '+551136547821'),
  (30711122234, 'Honda Motor de Argentina S.A.', 'contacto@honda.com.ar', '01145678900'),
  (30722233345, 'Yamaha Motor Argentina S.A.', 'ventas@yamaha-motor.com.ar', '01147654321'),
  (30733344456, 'KTM Argentina S.A.', 'info@ktmargentina.com', '01148901234'),
  (30744455567, 'Suzuki Motos Argentina', 'comercial@suzukimotos.com.ar', '01143210987'),
  (30755566678, 'Corven Motors Argentina S.A.', 'info@corven.com.ar', '03482421111'),
  (30766677789, 'Zanella Hnos S.A.C.I.F.', 'atencion@zanella.com.ar', '01141234567'),
  (30777788890, 'Gilera Motors Argentina', 'ventas@gilera.com.ar', '01149876543'),
  (30788899901, 'Imsa Bajaj S.A.', 'contacto@bajaj.com.ar', '01146543210'),
  (30799900012, 'Royal Enfield Argentina', 'info@royalenfield.com.ar', '01142345678'),
  (30700011123, 'TVS Motor Company Arg', 'contacto@tvsargentina.com.ar', '01143456789');

-- ==========================================================================
-- 7. DIRECCION_PROVEEDOR 
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
  (30711100091, 'Av. Cabildo', 2050, 'CABA', 'Buenos Aires', 'C1428'),
  (30711223344, 'Ruta Nacional 12', 3500, 'Corrientes', 'Corrientes', '3400'),
  (30722334455, 'Av. Independencia', 2450, 'Corrientes', 'Corrientes', '3400'),
  (30733445566, 'Av. Alberdi', 1800, 'Resistencia', 'Chaco', '3500'),
  (30300000011, 'Avenida Paulista', 1578, 'Sao Paulo', 'Sao Paulo', '01310-200'),
  (30300000022, 'Rua dos Andradas', 845, 'Porto Alegre', 'Rio Grande do Sul', '90020-005'),
  (30300000033, 'Avenida Rio Branco', 326, 'Rio de Janeiro', 'Rio de Janeiro', '20040-001'),
  (30300000044, 'Avenida Djalma Batista', 1145, 'Manaus', 'Amazonas', '69050-010'),
  (30300000055, 'Rua Augusta', 1290, 'Sao Paulo', 'Sao Paulo', '01305-100'),
  (30300000066, 'Rua XV de Novembro', 520, 'Curitiba', 'Parana', '80020-310'),
  (30300000077, 'Rua Visconde de Piraja', 780, 'Rio de Janeiro', 'Rio de Janeiro', '22410-002'),
  (30300000088, 'Avenida Brasil', 2410, 'Campinas', 'Sao Paulo', '13070-170'),
  (30711122234, 'Panamericana', 2500, 'Vicente Lopez', 'Buenos Aires', 'B1636'),
  (30722233345, 'Acceso Oeste', 1200, 'Ituzaingo', 'Buenos Aires', 'B1712'),
  (30733344456, 'Av. Libertador', 4500, 'Capital Federal', 'Buenos Aires', 'C1426'),
  (30744455567, 'Ruta 8', 1500, 'San Martin', 'Buenos Aires', 'B1650'),
  (30755566678, 'Ruta Nacional 9', 98, 'Venado Tuerto', 'Santa Fe', 'S2600'),
  (30766677789, 'Av. Marquez', 3000, 'Tres de Febrero', 'Buenos Aires', 'B1684'),
  (30777788890, 'Camino de Cintura', 4000, '18 de Marzo', 'Buenos Aires', 'B1706'),
  (30788899901, 'Av. Del Libertador', 7200, 'Capital Federal', 'Buenos Aires', 'C1428'),
  (30799900012, 'Dardo Rocha', 800, 'San Isidro', 'Buenos Aires', 'B1642'),
  (30700011123, 'Av. Cordoba', 2200, 'Capital Federal', 'Buenos Aires', 'C1120');

-- ==========================================================================
-- 8. PROVISION_MOTOCICLETA - todo modelo con al menos un proveedor (RN8)
-- ==========================================================================
-- Plantilla: INSERT INTO provision_motocicleta (cuit_proveedor, id_modelo) VALUES (...);
INSERT INTO provision_motocicleta (cuit_proveedor, id_modelo) VALUES
  (30712345671, 1), (30712345671, 2), (30701234563, 3), (30655544335, 3),
  (30655544335, 4), (30698765432, 5), (30698765432, 6), (30644433324, 7),
  (30733322213, 8), (30722211102, 9), (30711100091, 10),
  (30711223344, 11), (30711223344, 12), (30722334455, 13),
  (30722334455, 14), (30733445566, 11), (30733445566, 13),
  (30300000011, 15), (30300000022, 16), (30300000033, 17), (30300000044, 18),
  (30300000055, 19), (30300000066, 20), (30300000077, 21), (30300000088, 22),
  (30711122234, 23), (30722233345, 24), (30733344456, 25), (30744455567, 26),
  (30788899901, 27), (30700011123, 28), (30711122234, 29), (30722233345, 30),
  (30733344456, 31), (30788899901, 32);

-- ==========================================================================
-- 9. ACCESORIO - ids 
-- stock = stock inicial - unidades vendidas en ventas 'efectuadas' (las canceladas/reembolsadas se reintegran).
-- ==========================================================================
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
  ('Pastillas de freno delanteras', 8, 'repuesto', 38000.00, 24000.00),
  ('Casco integral homologado', 20, 'Cascos', 180000.00, 110000.00),
  ('Guantes para motociclista', 30, 'Indumentaria', 75000.00, 45000.00),
  ('Campera de moto', 15, 'Indumentaria', 250000.00, 160000.00),
  ('Baul trasero 45 litros', 10, 'Accesorios', 220000.00, 140000.00),
  ('Parabrisas universal', 12, 'Accesorios', 150000.00, 95000.00),
  ('Casco modular carbono XTR', 18, 'Cascos', 285000.00, 190000.00),
  ('Intercomunicador Bluetooth V6', 13, 'Electronica', 175000.00, 110000.00),
  ('Guantes impermeables touring', 31, 'Indumentaria', 78000.00, 49000.00),
  ('Pantalon reforzado para moto', 16, 'Indumentaria', 215000.00, 145000.00),
  ('Maletas laterales aluminio', 7, 'Equipaje', 480000.00, 325000.00),
  ('Soporte universal para celular', 24, 'Accesorios', 65000.00, 39000.00),
  ('Protector de radiador metalico', 11, 'Proteccion', 135000.00, 85000.00),
  ('Kit de luces auxiliares LED', 20, 'Iluminacion', 125000.00, 79000.00),
  ('Casco Integral MT Helmets', 15, 'Indumentaria', 120000.00, 75000.00),
  ('Campera con protecciones Cordura', 10, 'Indumentaria', 250000.00, 160000.00),
  ('Guantes de cuero invierno', 20, 'Indumentaria', 45000.00, 25000.00),
  ('Traba disco con alarma', 25, 'Seguridad', 35000.00, 18000.00),
  ('Cadenon linga reforzada', 18, 'Seguridad', 28000.00, 14000.00),
  ('Kit de transmision reforzado', 12, 'Repuestos', 90000.00, 50000.00),
  ('Filtro de aire deportivo', 30, 'Repuestos', 15000.00, 8000.00),
  ('Baul maletero 39 litros', 8, 'Equipamiento', 110000.00, 65000.00),
  ('Cargador USB para manillar', 22, 'Accesorios', 18000.00, 9000.00),
  ('Lonas cobertoras impermeables', 14, 'Accesorios', 32000.00, 16000.00);

-- ==========================================================================
-- 10. PROVISION_ACCESORIO 
-- ==========================================================================
-- Plantilla: INSERT INTO provision_accesorio (cuit_proveedor, id_accesorio) VALUES (...);
INSERT INTO provision_accesorio (cuit_proveedor, id_accesorio) VALUES
  (30712345671, 1), (30698765432, 1), (30712345671, 2), (30701234563, 3),
  (30701234563, 4), (30655544335, 5), (30644433324, 6), (30733322213, 7),
  (30722211102, 8), (30698765432, 9), (30711100091, 10),
  (30711223344, 11), (30711223344, 12), (30722334455, 13),
  (30722334455, 14), (30733445566, 15), (30733445566, 11),
  (30300000011, 16), (30300000022, 17), (30300000033, 18), (30300000044, 19),
  (30300000055, 20), (30300000066, 21), (30300000077, 22), (30300000088, 23),
  (30711122234, 24), (30722233345, 25), (30733344456, 26), (30744455567, 27),
  (30755566678, 28), (30766677789, 29), (30777788890, 30), (30788899901, 31),
  (30799900012, 32), (30700011123, 33);

-- ==========================================================================
-- 11. VENTA  - ids 1..30: 23 efectuadas, 5 canceladas, 2 reembolsadas
-- monto_total = precio_venta_moto + suma(cantidad * precio_pactado) de sus accesorios.
-- Ventas 4 y 5: mismo chasis; la 4 esta cancelada y la 5 (posterior) efectuada -> valida el indice filtrado.
-- Lotes B y C con montos recalculados (ver encabezado).
-- ==========================================================================
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
  ('2026-09-03', 'tarjeta de credito', 5400000.00, 5400000.00, 'cancelada', 30456781, 36543210, '9C2YAM00000000007'),
  ('2026-09-10', 'Transferencia', 8500000.00, 8755000.00, 'efectuada', 31222334, 30111222, 'HONCB500F001'),
  ('2026-09-15', 'Tarjeta de credito', 9200000.00, 9275000.00, 'efectuada', 29888777, 28777888, 'YAMMT03001'),
  ('2026-01-17', 'Transferencia', 4850000.00, 5125000.00, 'efectuada', 41234567, 39876543, 'ES-ZON-874521'),
  ('2026-02-28', 'Tarjeta de credito', 4520000.00, 4685000.00, 'efectuada', 38456789, 42654321, 'ES-ZON-639847'),
  ('2026-03-14', 'Efectivo', 8900000.00, 9044000.00, 'cancelada', 43567890, 37654321, 'ES-MON-528316'),
  ('2026-04-09', 'Transferencia', 5200000.00, 5405000.00, 'efectuada', 37654321, 40987654, 'ES-RIE-417925'),
  ('2026-05-22', 'Tarjeta de debito', 11800000.00, 12250000.00, 'reembolsada', 40987654, 45123456, 'ES-RIE-753184'),
  ('2026-06-11', 'Efectivo', 10500000.00, 10620000.00, 'efectuada', 45123456, 41234567, 'ES-GAS-286415'),
  ('2026-07-26', 'Transferencia', 15600000.00, 15725000.00, 'efectuada', 39876543, 43567890, 'ES-GAS-941753'),
  ('2026-08-19', 'Tarjeta de credito', 4900000.00, 5130000.00, 'efectuada', 42654321, 38456789, 'ES-DER-635829'),
  ('2026-03-01', 'Transferencia', 4500000.00, 4620000.00, 'efectuada', 20111222, 10111222, 'CHS89123401'),
  ('2026-03-02', 'Tarjeta de Credito', 3200000.00, 3235000.00, 'efectuada', 20222333, 10222333, 'CHS89123402'),
  ('2026-03-03', 'Efectivo', 5800000.00, 6050000.00, 'efectuada', 20333444, 10333444, 'CHS89123403'),
  ('2026-03-04', 'Transferencia', 4800000.00, 4980000.00, 'efectuada', 20666777, 10444555, 'CHS89123404'),
  ('2026-03-05', 'Tarjeta de Debito', 3600000.00, 3635000.00, 'efectuada', 20999001, 10556677, 'CHS89123405'),
  ('2026-03-06', 'Transferencia', 3400000.00, 3490000.00, 'efectuada', 21000112, 10667788, 'CHS89123406'),
  ('2026-03-07', 'Efectivo', 4100000.00, 4115000.00, 'efectuada', 20111222, 10778899, 'CHS89123407'),
  ('2026-03-08', 'Tarjeta de Credito', 7500000.00, 7610000.00, 'efectuada', 20222333, 10889900, 'CHS89123408'),
  ('2026-03-09', 'Transferencia', 8900000.00, 8972000.00, 'cancelada', 20333444, 10990011, 'CHS89123409'),
  ('2026-03-10', 'Efectivo', 6200000.00, 6232000.00, 'efectuada', 20666777, 11001122, 'CHS89123410');

-- ==========================================================================
-- 12. DETALLE_VENTA_ACCESORIO 
-- precio_pactado puede diferir del precio_lista del accesorio (RN6).
-- ==========================================================================
-- Plantilla: INSERT INTO detalle_venta_accesorio (cod_venta, id_accesorio, cantidad, precio_pactado) VALUES (...);
INSERT INTO detalle_venta_accesorio (cod_venta, id_accesorio, cantidad, precio_pactado) VALUES
  (1, 1, 1, 185000.00), (1, 3, 1, 42000.00),
  (2, 1, 1, 175750.00), (2, 6, 1, 36000.00),
  (3, 2, 1, 98000.00), (3, 5, 1, 70200.00),
  (4, 4, 1, 165000.00),
  (5, 1, 1, 185000.00), (5, 3, 1, 42000.00), (5, 9, 2, 14500.00),
  (6, 7, 1, 29000.00),
  (7, 2, 1, 98000.00), (7, 8, 1, 54000.00),
  (8, 1, 1, 185000.00), (8, 4, 1, 156750.00), (8, 6, 1, 36000.00),
  (9, 10, 1, 38000.00),
  (11, 11, 1, 180000.00), (11, 12, 1, 75000.00), (12, 12, 1, 75000.00),
  (13, 16, 1, 275000.00), (14, 17, 1, 165000.00), (15, 18, 2, 72000.00),
  (16, 19, 1, 205000.00), (17, 20, 1, 450000.00), (18, 21, 2, 60000.00),
  (19, 22, 1, 125000.00), (20, 23, 2, 115000.00),
  (21, 24, 1, 120000.00), (22, 27, 1, 35000.00), (23, 25, 1, 250000.00),
  (24, 26, 2, 90000.00), (25, 28, 1, 35000.00), (26, 29, 1, 90000.00),
  (27, 30, 1, 15000.00), (28, 31, 1, 110000.00), (29, 32, 2, 36000.00),
  (30, 33, 1, 32000.00);

-- ==========================================================================
-- 13. COTIZACION  - vencimiento = emision + 7 dias (CHECK del DDL)
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
  ('2026-09-28', '2026-10-05', 3700000.00, 38765432, 7),
  ('2026-09-01', '2026-09-08', 8500000.00, 32444555, 11),
  ('2026-09-05', '2026-09-12', 9200000.00, 35666999, 12),
  ('2026-09-15', '2026-09-22', 7800000.00, 32444555, 13),
  ('2025-11-03', '2025-11-10', 4700000.00, 41234567, 15),
  ('2025-11-19', '2025-11-26', 4400000.00, 39876543, 16),
  ('2025-12-02', '2025-12-09', 8750000.00, 42654321, 17),
  ('2025-12-18', '2025-12-25', 5100000.00, 38456789, 18),
  ('2026-01-07', '2026-01-14', 11500000.00, 43567890, 19),
  ('2026-01-25', '2026-02-01', 10200000.00, 37654321, 20),
  ('2026-02-13', '2026-02-20', 15100000.00, 40987654, 21),
  ('2026-03-01', '2026-03-08', 4750000.00, 45123456, 22),
  ('2026-02-01', '2026-02-08', 4500000.00, 20111222, 23),
  ('2026-02-02', '2026-02-09', 3200000.00, 20222333, 24),
  ('2026-02-03', '2026-02-10', 5800000.00, 20333444, 25),
  ('2026-02-04', '2026-02-11', 4800000.00, 20444555, 26),
  ('2026-02-05', '2026-02-12', 3600000.00, 20555666, 27),
  ('2026-02-06', '2026-02-13', 3400000.00, 20666777, 28),
  ('2026-02-07', '2026-02-14', 4100000.00, 20777888, 29),
  ('2026-02-08', '2026-02-15', 7500000.00, 20888990, 30),
  ('2026-02-09', '2026-02-16', 8900000.00, 20999001, 31),
  ('2026-02-10', '2026-02-17', 6200000.00, 21000112, 32);

-- ==========================================================================
-- 14. HISTORIAL_DE_PRECIO 
-- El ultimo precio_nuevo de cada modelo coincide con su precio_lista actual.
-- ==========================================================================
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
  (14500000.00, 14000000.00, '2026-08-10', 10),
  (8500000.00, 8000000.00, '2026-08-01', 11),
  (8500000.00, 8200000.00, '2026-09-01', 11),
  (9200000.00, 8900000.00, '2026-08-15', 12),
  (9200000.00, 9000000.00, '2026-09-05', 12),
  (7800000.00, 7500000.00, '2026-09-01', 13),
  (10500000.00, 10000000.00, '2026-09-10', 14),
  (4850000.00, 4550000.00, '2025-10-12', 15),
  (4520000.00, 4250000.00, '2025-10-25', 16),
  (8900000.00, 8400000.00, '2025-11-08', 17),
  (5200000.00, 4900000.00, '2025-11-21', 18),
  (11800000.00, 10900000.00, '2025-12-05', 19),
  (10500000.00, 9800000.00, '2025-12-19', 20),
  (15600000.00, 14800000.00, '2026-01-11', 21),
  (4900000.00, 4600000.00, '2026-01-28', 22),
  (4500000.00, 4200000.00, '2026-01-15', 23),
  (3200000.00, 2950000.00, '2026-01-15', 24),
  (5800000.00, 5400000.00, '2026-01-20', 25),
  (4800000.00, 4500000.00, '2026-01-20', 26),
  (3600000.00, 3300000.00, '2026-01-25', 27),
  (3400000.00, 3100000.00, '2026-01-25', 28),
  (4100000.00, 3800000.00, '2026-01-28', 29),
  (7500000.00, 7000000.00, '2026-02-01', 30),
  (8900000.00, 8300000.00, '2026-02-01', 31),
  (6200000.00, 5800000.00, '2026-02-05', 32);

COMMIT TRANSACTION;  -- confirmacion de transacción! (usamos la herramienta de transacciones como buena práctica, a pesar de ser una base de datos de prueba)
GO

-- ============================================================================
-- PRUEBAS NEGATIVAS (descomentar de a UNA; cada una debe fallar)
-- ============================================================================
-- N1. Stock negativo -> error ck_modelo_stock
-- UPDATE modelo_motocicleta SET stock_disponible = -1 WHERE id_modelo = 1;
-- N2. Estado de venta invalido -> error ck_venta_estado
-- UPDATE venta SET estado = 'pendiente' WHERE cod_venta = 1;
-- N3. Segunda venta efectuada del mismo chasis -> error ux_venta_chasis_vigente
-- INSERT INTO venta (fecha, metodo_pago, precio_venta_moto, monto_total, estado, dni_cliente, dni_vendedor, numero_chasis)
-- VALUES ('2026-09-20', 'efectivo', 1000.00, 1000.00, 'efectuada', 30456781, 31222333, '9C2HON00000000001');
-- N4. Venta con cliente inexistente -> error de FK
-- INSERT INTO venta (fecha, metodo_pago, precio_venta_moto, monto_total, estado, dni_cliente, dni_vendedor, numero_chasis)
-- VALUES ('2026-09-20', 'efectivo', 1000.00, 1000.00, 'efectuada', 99999999, 31222333, '9C2YAM00000000007');
-- N5. Numero de motor repetido -> error uq_motocicleta_numero_motor
-- INSERT INTO motocicleta (numero_chasis, numero_motor, id_modelo)
-- VALUES ('CHASIS-DUPLICADO-01', 'MOT-HON-000001', 1);
-- N6. Cotizacion con vencimiento a 10 dias -> error ck_cotizacion_validez_7_dias
-- INSERT INTO cotizacion (fecha_emision, fecha_vencimiento, precio_cotizado, dni_cliente, id_modelo)
-- VALUES ('2026-09-01', '2026-09-11', 1000.00, 30456781, 1);
-- N7. Cliente con estado invalido -> error ck_cliente_estado (usar DNI nuevo, no existente)
-- INSERT INTO persona (dni, nombre, apellido, cuil, telefono, email)
-- VALUES (99988877, 'Test', 'Check', 20999888771, '0000000000', 'test@example.com');
-- INSERT INTO cliente (dni_cliente, estado) VALUES (99988877, 'vendido');


