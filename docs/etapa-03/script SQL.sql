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