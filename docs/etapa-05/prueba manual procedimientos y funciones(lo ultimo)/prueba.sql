//Probando funciones
SELECT dbo.fn_precio_con_descuento(1000000.00, 10);   -- 900000.00
SELECT dbo.fn_precio_con_descuento(1000000.00, 150);  -- NULL (porcentaje inválido)
SELECT dbo.fn_descuento_cliente(<un_dni>);
SELECT * FROM dbo.fn_resumen_cliente(<un_dni>);
