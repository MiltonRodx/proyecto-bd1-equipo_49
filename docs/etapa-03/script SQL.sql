create table persona (
dni int not null,
nombre varchar(100)not null,
apellido varchar (100)not null,
cuil bigint not null,
telefono varchar (30) not null,
email varchar (100) not null,
constraint pk_persona_dni primary key (dni)
);

create table vendedor (
dni_vendedor int not null,
constraint pk_vendedor_dni_vendedor primary key 
(dni_vendedor),
constraint fk_vendedor_dni_vendedor foreign key 
(dni_vendedor) references persona(dni) on delete cascade
);

create table cliente (
dni_cliente int not null,
estado varchar (100) not null,
constraint ck_cliente_estado check (estado in ('interesado','en proceso de compra', 'comprador')),
constraint pk_vendedor_dni_cliente primary key 
(dni_cliente),
constraint fk_vendedor_dni_cliente foreign key 
(dni_cliente) references persona(dni) on delete cascade
);

create table modelo_motocicleta (
id_modelo int not null identity (1,1),
nombre_modelo varchar (100) not null,
marca varchar (100) not null,
cilindrada int  not null,
color varchar (50) not null,
anio int not null,
stock_disponible int not null constraint df_modelo_motocicleta_stock_disponible
default 0,
precio_lista decimal (10,2) not null,
CONSTRAINT pk_modelo_motocicleta PRIMARY KEY (id_modelo),
CONSTRAINT ck_modelo_stock CHECK (stock_disponible >= 0)
);

create table motocicleta (
  numero_chasis varchar(100) not null,
  numero_motor varchar(100) not null,
  id_modelo int not null,
  constraint pk_motocicleta primary key (numero_chasis),
  constraint fk_motocicleta_modelo_motocicleta foreign key (id_modelo) 
  references modelo_motocicleta(id_modelo),
  constraint uq_motocicleta_numero_motor unique (numero_motor)
);

create table venta (
  cod_venta int not null identity(1,1),
  fecha date not null,
  metodo_pago varchar(50) not null,
  precio_venta_moto decimal(12,2) not null,
  monto_total decimal(12,2) not null,
  estado varchar(30) not null constraint df_venta_estado default 'efectuada',
  dni_cliente int not null,
  dni_vendedor int not null,
  numero_chasis varchar(100) not null,
  constraint pk_venta primary key (cod_venta),
  constraint ck_venta_estado check (estado in ('efectuada', 'cancelada', 'reembolsada')),
  constraint fk_venta_cliente foreign key (dni_cliente) 
    references cliente(dni_cliente),
  constraint fk_venta_vendedor foreign key (dni_vendedor) 
    references vendedor(dni_vendedor),
  constraint fk_venta_motocicleta foreign key (numero_chasis) 
    references motocicleta(numero_chasis),
  constraint uq_venta_numero_chasis unique (numero_chasis)
);

create table direccion_cliente (
  dni_cliente int not null,
  calle varchar(100) not null,
  numero int not null,
  ciudad varchar(100) not null,
  provincia varchar(100) not null,
  codigo_postal varchar(10) not null,
  constraint pk_direccion_cliente primary key (dni_cliente),
  constraint fk_direccion_cliente_dni_cliente foreign key (dni_cliente) 
    references cliente(dni_cliente) on delete cascade
);

create table proveedor (
  cuit_proveedor bigint not null,
  razon_social varchar(100) not null,
  email varchar(100) not null,
  telefono varchar(30) not null,
  constraint pk_proveedor primary key (cuit_proveedor)
);

create table direccion_proveedor (
  cuit_proveedor bigint not null,
  calle varchar(100) not null,
  numero int not null,
  ciudad varchar(100) not null,
  provincia varchar(100) not null,
  codigo_postal varchar(10) not null,
  constraint pk_direccion_proveedor primary key (cuit_proveedor),
  constraint fk_direccion_proveedor_cuit_proveedor foreign key (cuit_proveedor) 
    references proveedor(cuit_proveedor) on delete cascade
);

create table provision_motocicleta (
  cuit_proveedor bigint not null,
  id_modelo int not null,
  constraint pk_provision_motocicleta primary key (cuit_proveedor, id_modelo),
  constraint fk_provision_motocicleta_cuit_proveedor foreign key (cuit_proveedor) 
    references proveedor(cuit_proveedor),
  constraint fk_provision_motocicleta_id_modelo foreign key (id_modelo) 
    references modelo_motocicleta(id_modelo)
);

create table accesorio (
  id_accesorio int not null identity(1,1),
  descripcion varchar(255) not null,
  stock int not null constraint df_accesorio_stock default 0,
  categoria varchar(50) not null,
  precio_lista decimal(12,2) not null,
  precio_costo decimal(12,2) not null,
  constraint pk_accesorio primary key (id_accesorio),
  constraint ck_accesorio_stock check (stock >= 0),
  constraint ck_accesorio_precio_lista check (precio_lista >= 0),
  constraint ck_accesorio_precio_costo check (precio_costo >= 0)
);

create table provision_accesorio (
  cuit_proveedor bigint not null,
  id_accesorio int not null,
  constraint pk_provision_accesorio primary key (cuit_proveedor, id_accesorio),
  constraint fk_provision_accesorio_cuit_proveedor foreign key (cuit_proveedor) 
    references proveedor(cuit_proveedor),
  constraint fk_provision_accesorio_id_accesorio foreign key (id_accesorio) 
    references accesorio(id_accesorio)
);

create table detalle_venta_accesorio (
  cod_venta int not null,
  id_accesorio int not null,
  cantidad int not null,
  precio_pactado decimal(12,2) not null,
  constraint pk_detalle_venta_accesorio primary key (cod_venta, id_accesorio),
  constraint fk_detalle_venta_accesorio_venta foreign key (cod_venta) 
    references venta(cod_venta),
  constraint fk_detalle_venta_accesorio_accesorio foreign key (id_accesorio) 
    references accesorio(id_accesorio),
  constraint ck_detalle_venta_accesorio_cantidad check (cantidad > 0),
  constraint ck_detalle_venta_accesorio_precio check (precio_pactado >= 0)
);

create table cotizacion (
  id_cotizacion int not null identity(1,1),
  fecha_emision date not null,
  fecha_vencimiento date not null,
  precio_cotizado decimal(12,2) not null,
  dni_cliente int not null,
  id_modelo int not null,
  constraint pk_cotizacion primary key (id_cotizacion),
  constraint fk_cotizacion_dni_cliente foreign key (dni_cliente) 
    references cliente(dni_cliente),
  constraint fk_cotizacion_id_modelo foreign key (id_modelo) 
    references modelo_motocicleta(id_modelo),
  constraint ck_cotizacion_precio check (precio_cotizado >= 0),
  constraint ck_cotizacion_validez_7_dias check (fecha_vencimiento = dateadd(day, 7, fecha_emision))
);

create table historial_de_precio (
  id_historial int not null identity(1,1),
  precio_nuevo decimal(12,2) not null,
  precio_anterior decimal(12,2) not null,
  fecha_modificacion date not null,
  id_modelo int not null,
  constraint pk_historial_de_precio primary key (id_historial),
  constraint fk_historial_de_precio_id_modelo foreign key (id_modelo) 
    references modelo_motocicleta(id_modelo),
  constraint ck_historial_precio_nuevo check (precio_nuevo >= 0),
  constraint ck_historial_precio_anterior check (precio_anterior >= 0)
);


