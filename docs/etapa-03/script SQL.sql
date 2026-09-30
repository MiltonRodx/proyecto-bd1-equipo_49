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

