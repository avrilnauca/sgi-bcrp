-- SGI-BCRP | Esquema fisico (PostgreSQL 15)
CREATE SCHEMA IF NOT EXISTS sgi;
SET search_path TO sgi;

CREATE TABLE tipo_incidente (
  id SMALLINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  nombre VARCHAR(80) NOT NULL UNIQUE,
  categoria VARCHAR(40) NOT NULL,
  regla_clasificacion VARCHAR(255),
  activo BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE entidad_financiera (
  id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  razon_social VARCHAR(150) NOT NULL,
  codigo_bcrp VARCHAR(10) NOT NULL UNIQUE,
  estado_conexion VARCHAR(15) NOT NULL DEFAULT 'DESCONECTADO'
    CHECK (estado_conexion IN ('ACTIVO','ALERTA','DESCONECTADO'))
);

CREATE TABLE usuario (
  id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  nombre VARCHAR(120) NOT NULL,
  correo VARCHAR(120) NOT NULL UNIQUE,
  rol VARCHAR(15) NOT NULL CHECK (rol IN ('ANALISTA','ADMINISTRADOR')),
  activo BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE incidente (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  codigo VARCHAR(12) NOT NULL UNIQUE,
  fecha_registro TIMESTAMPTZ NOT NULL DEFAULT now(),
  fecha_fin TIMESTAMPTZ,
  id_tipo_incidente SMALLINT REFERENCES tipo_incidente(id),
  id_entidad INTEGER NOT NULL REFERENCES entidad_financiera(id),
  estado VARCHAR(12) NOT NULL DEFAULT 'NUEVO'
    CHECK (estado IN ('NUEVO','EN_PROCESO','RESUELTO','REPORTADO')),
  severidad VARCHAR(10) CHECK (severidad IN ('BAJA','MEDIA','ALTA','CRITICA')),
  descripcion TEXT,
  origen_deteccion VARCHAR(10) NOT NULL CHECK (origen_deteccion IN ('AUTOMATICO','MANUAL')),
  CHECK (fecha_fin IS NULL OR fecha_fin >= fecha_registro)
);

CREATE TABLE historial_estado (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  id_incidente BIGINT NOT NULL REFERENCES incidente(id),
  estado_anterior VARCHAR(12),
  estado_nuevo VARCHAR(12) NOT NULL,
  fecha TIMESTAMPTZ NOT NULL DEFAULT now(),
  id_usuario INTEGER REFERENCES usuario(id)  -- NULL = accion del sistema
);

CREATE TABLE servicio_externo (
  id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  id_entidad INTEGER NOT NULL UNIQUE REFERENCES entidad_financiera(id),
  endpoint VARCHAR(255) NOT NULL,
  estado VARCHAR(15) NOT NULL DEFAULT 'INACTIVO',
  ultima_sincronizacion TIMESTAMPTZ,
  credencial_cifrada BYTEA
);

CREATE TABLE auditoria (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  id_usuario INTEGER REFERENCES usuario(id),
  accion VARCHAR(40) NOT NULL,
  tabla VARCHAR(40) NOT NULL,
  id_registro BIGINT,
  fecha TIMESTAMPTZ NOT NULL DEFAULT now(),
  ip VARCHAR(45)
);

-- Indices para las consultas del RF05 y el historial
CREATE INDEX idx_incidente_estado ON incidente (estado);
CREATE INDEX idx_incidente_entidad_fecha ON incidente (id_entidad, fecha_registro DESC);
CREATE INDEX idx_historial_incidente ON historial_estado (id_incidente, fecha);

-- Seguridad: minimo privilegio
REVOKE ALL ON SCHEMA public FROM PUBLIC;
-- Cambiar la contrasena antes de ejecutar; no subirla al repositorio
CREATE ROLE sgi_app LOGIN PASSWORD '<definir-en-gestor-de-secretos>';
GRANT USAGE ON SCHEMA sgi TO sgi_app;
GRANT SELECT, INSERT, UPDATE ON incidente, tipo_incidente, entidad_financiera,
  usuario, servicio_externo TO sgi_app;
GRANT SELECT, INSERT ON historial_estado, auditoria TO sgi_app;  -- sin UPDATE/DELETE
