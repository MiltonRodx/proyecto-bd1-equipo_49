SELECT
    dbo.fn_precio_con_descuento(8500000.00, 10.00) AS precio_con_10,
    dbo.fn_total_accesorios_venta(5) AS accesorios_venta_5,
    dbo.fn_cotizacion_vigente(33) as cotizacion_vigente,
    dbo.fn_total_venta  (3000000,5) as total_venta,
    dbo.fn_stock_disponible_modelo(25) as modelo_duke,
    dbo.fn_stock_disponible_modelo(11) as modelo_cb500;

    select * from cliente;


    DECLARE @id_cotizacion_generada INT;

-- 2. Ejecutar el procedimiento almacenado
EXEC dbo.sp_generar_cotizacion
    @dni_cliente          = 20111222,            -- Cambia por un DNI real de tu tabla cliente
    @id_modelo            = 1,                   -- Cambia por un ID de modelo real
    @porcentaje_descuento = NULL,                -- Si va en NULL, usa el descuento automático del cliente
    @fecha_emision        = NULL,                -- Si va en NULL, toma la fecha de hoy (GETDATE())
    @id_cotizacion        = @id_cotizacion_generada OUTPUT; -- OBLIGATORIO para capturar el ID

-- 3. (Opcional) Consultar el ID devuelto en la variable
SELECT @id_cotizacion_generada AS IdCotizacionCreada;