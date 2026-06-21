-- ============================================================
--  ACME ERP - Esquema inicial de base de datos (PostgreSQL/RDS)
--  Ejecutar una vez sobre la instancia RDS:
--    psql "host=<endpoint> port=5432 dbname=acme_erp user=acme_app sslmode=require" -f db/init.sql
-- ============================================================

-- Extensión para hashing/UUID
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ---- Usuarios del portal (autenticación + MFA) ----
CREATE TABLE IF NOT EXISTS usuarios (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email         VARCHAR(150) UNIQUE NOT NULL,
    nombre        VARCHAR(120) NOT NULL,
    -- Contraseña almacenada como hash bcrypt (nunca en texto plano)
    password_hash VARCHAR(120) NOT NULL,
    rol           VARCHAR(30)  NOT NULL DEFAULT 'operador',  -- admin | operador | auditor
    -- Secreto TOTP para MFA (base32). NULL si el usuario aún no activa MFA.
    mfa_secret    VARCHAR(64),
    mfa_enabled   BOOLEAN NOT NULL DEFAULT FALSE,
    activo        BOOLEAN NOT NULL DEFAULT TRUE,
    creado_en     TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---- Catálogo de productos (ferretería) ----
CREATE TABLE IF NOT EXISTS productos (
    id          SERIAL PRIMARY KEY,
    sku         VARCHAR(40) UNIQUE NOT NULL,
    nombre      VARCHAR(150) NOT NULL,
    categoria   VARCHAR(80),
    precio_clp  INTEGER NOT NULL CHECK (precio_clp >= 0),
    stock       INTEGER NOT NULL DEFAULT 0 CHECK (stock >= 0),
    creado_en   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---- Registro de auditoría (Accounting del modelo AAA) ----
CREATE TABLE IF NOT EXISTS auditoria_accesos (
    id          BIGSERIAL PRIMARY KEY,
    usuario_id  UUID REFERENCES usuarios(id),
    email       VARCHAR(150),
    accion      VARCHAR(60) NOT NULL,     -- login_ok | login_fail | mfa_fail | logout | acceso_recurso
    ip          INET,
    user_agent  TEXT,
    ts          TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---- Datos de ejemplo ----
-- Password de ejemplo: "Acme2026!" (hash bcrypt valido). Cambiar en producción.
INSERT INTO usuarios (email, nombre, password_hash, rol, mfa_enabled)
VALUES
  ('admin@acme.cl', 'Administrador ACME',
   '$2a$10$ESyR96Xg4KbP4mgyhlqN..KT8W4d7hT7j2i86J4dqNw7nGMWwhk1m', 'admin', FALSE)
ON CONFLICT (email) DO NOTHING;

INSERT INTO productos (sku, nombre, categoria, precio_clp, stock) VALUES
  ('FER-001', 'Taladro percutor 750W',      'Herramientas eléctricas', 49990, 120),
  ('FER-002', 'Juego de llaves 1/2"',        'Herramientas manuales',   24990, 300),
  ('FER-003', 'Cable eléctrico 2,5mm (rollo)','Electricidad',           18990, 540),
  ('FER-004', 'Casco de seguridad',          'EPP',                      8990, 800)
ON CONFLICT (sku) DO NOTHING;

-- Índices de apoyo
CREATE INDEX IF NOT EXISTS idx_auditoria_ts ON auditoria_accesos (ts);
CREATE INDEX IF NOT EXISTS idx_productos_cat ON productos (categoria);
