-- ============================================================================
-- COLCHOCHECK (BETA FASE 1) - SUPER COLCHONES (GNC)
-- Script SQL para Supabase (100% Gratuito)
-- Plazas: ZMG Jalisco, Puerto Vallarta, Tepic, Colima, Manzanillo, Mazatlán, Culiacán, Los Mochis
-- ============================================================================

-- 1. Tabla de Usuarios (Login por No. Colaborador + Password asignado por Admin)
CREATE TABLE IF NOT EXISTS usuarios (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    num_colaborador TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    nombre TEXT NOT NULL,
    rol TEXT NOT NULL CHECK (rol IN ('promotor', 'supervisor', 'ejecutivo', 'admin')),
    plaza TEXT NOT NULL,
    activo BOOLEAN DEFAULT TRUE,
    creado_en TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Catálogo de Sucursales Super Colchones (GNC) con Geocerca de 100 metros
CREATE TABLE IF NOT EXISTS sucursales (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    codigo TEXT UNIQUE NOT NULL,
    nombre TEXT NOT NULL,
    plaza TEXT NOT NULL,
    latitud DOUBLE PRECISION NOT NULL,
    longitud DOUBLE PRECISION NOT NULL,
    radio_geocerca_m INTEGER DEFAULT 100,
    geocerca_activa BOOLEAN DEFAULT TRUE,
    creado_por TEXT DEFAULT 'admin',
    creado_en TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Rol y Visitas de Promotores (Fuerza de Ventas en Piso)
CREATE TABLE IF NOT EXISTS visitas_promotor (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    fecha DATE NOT NULL DEFAULT CURRENT_DATE,
    num_colaborador TEXT NOT NULL REFERENCES usuarios(num_colaborador),
    nombre_promotor TEXT NOT NULL,
    sucursal_codigo TEXT NOT NULL REFERENCES sucursales(codigo),
    nombre_sucursal TEXT NOT NULL,
    plaza TEXT NOT NULL,
    supervisor_asigno TEXT NOT NULL,
    estatus TEXT NOT NULL DEFAULT 'Pendiente' CHECK (estatus IN ('Pendiente', 'En Piso', 'Cerrada', 'Cerrada - Autorizada Admin')),
    hora_entrada TIMESTAMPTZ,
    lat_entrada DOUBLE PRECISION,
    lng_entrada DOUBLE PRECISION,
    distancia_entrada_m INTEGER,
    foto_entrada_url TEXT,
    hora_salida TIMESTAMPTZ,
    lat_salida DOUBLE PRECISION,
    lng_salida DOUBLE PRECISION,
    foto_salida_url TEXT,
    tiempo_efectivo_min INTEGER DEFAULT 0,
    -- Métricas de Fin de Día (Habilitadas tras el cierre de visita)
    afluencia TEXT CHECK (afluencia IN ('Nula', 'Baja', 'Media', 'Alta')),
    ingresos_clientes INTEGER CHECK (ingresos_clientes BETWEEN 0 AND 9999),
    venta_colchones_america VARCHAR(140),
    ventas_competencia VARCHAR(140),
    presupuesto_america VARCHAR(140),
    presupuesto_competencia VARCHAR(140),
    -- Auditoría Admin (Contingencias)
    motivo_contingencia_admin TEXT,
    autorizado_por_admin TEXT,
    creado_en TIMESTAMPTZ DEFAULT NOW()
);

-- 4. Plan Diario de Supervisores (Máx. 10 paradas por día: Sucursal o Folio Garantía)
CREATE TABLE IF NOT EXISTS visitas_supervisor (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    fecha DATE NOT NULL DEFAULT CURRENT_DATE,
    num_supervisor TEXT NOT NULL REFERENCES usuarios(num_colaborador),
    nombre_supervisor TEXT NOT NULL,
    plaza TEXT NOT NULL,
    orden_parada INTEGER NOT NULL CHECK (orden_parada BETWEEN 1 AND 10),
    tipo_visita TEXT NOT NULL CHECK (tipo_visita IN ('Sucursal', 'Garantia')),
    sucursal_codigo TEXT,
    destino_nombre TEXT NOT NULL,
    folio_garantia TEXT,
    dictamen_garantia TEXT,
    fotos_garantia_json JSONB DEFAULT '[]'::jsonb, -- Hasta 6 fotos de verificación de producto
    estatus TEXT NOT NULL DEFAULT 'Pendiente' CHECK (estatus IN ('Pendiente', 'En Curso', 'Cerrada', 'Cerrada - Autorizada Admin')),
    hora_entrada TIMESTAMPTZ,
    lat_entrada DOUBLE PRECISION,
    lng_entrada DOUBLE PRECISION,
    foto_entrada_url TEXT,
    hora_salida TIMESTAMPTZ,
    lat_salida DOUBLE PRECISION,
    lng_salida DOUBLE PRECISION,
    foto_salida_url TEXT,
    tiempo_estancia_min INTEGER DEFAULT 0,
    tiempo_traslado_min INTEGER DEFAULT 0,
    motivo_contingencia_admin TEXT,
    creado_en TIMESTAMPTZ DEFAULT NOW()
);

-- 5. Cierre General del Día del Supervisor (Máx. 1000 caracteres)
CREATE TABLE IF NOT EXISTS cierres_dia_supervisor (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    fecha DATE NOT NULL DEFAULT CURRENT_DATE,
    num_supervisor TEXT NOT NULL REFERENCES usuarios(num_colaborador),
    nombre_supervisor TEXT NOT NULL,
    plaza TEXT NOT NULL,
    comentarios_generales VARCHAR(1000) NOT NULL,
    creado_en TIMESTAMPTZ DEFAULT NOW()
);

-- Semilla inicial de Usuarios Demo para Super Colchones (GNC)
INSERT INTO usuarios (num_colaborador, password_hash, nombre, rol, plaza) VALUES
('1001', 'Promotor2026', 'Luis Fernando Gómez', 'promotor', 'ZMG Jalisco'),
('1002', 'Promotor2026', 'María Elena Vázquez', 'promotor', 'Puerto Vallarta'),
('1003', 'Promotor2026', 'Jorge Alberto Ríos', 'promotor', 'Mazatlán'),
('2001', 'Super2026', 'Ing. Roberto Castañeda', 'supervisor', 'ZMG Jalisco'),
('2002', 'Super2026', 'Lic. Patricia Morales', 'supervisor', 'Pacífico Norte (Mazatlán / Culiacán / Mochis)'),
('3001', 'Directivo2026', 'Dir. Comercial GNC / América', 'ejecutivo', 'Nacional / Todas las Plazas'),
('9999', 'Admin2026', 'Responsable de Cuenta (Administrador)', 'admin', 'Nacional / Todas las Plazas')
ON CONFLICT (num_colaborador) DO NOTHING;

-- Semilla inicial de Sucursales Super Colchones (GNC)
INSERT INTO sucursales (codigo, nombre, plaza, latitud, longitud, radio_geocerca_m, geocerca_activa) VALUES
('GDL-REV', 'Suc. Revolución', 'ZMG Jalisco', 20.6628, -103.3215, 100, TRUE),
('GDL-PAT', 'Suc. Plaza Patria', 'ZMG Jalisco', 20.7121, -103.3782, 100, TRUE),
('GDL-TES', 'Suc. Tesistán / Zapopan Norte', 'ZMG Jalisco', 20.7965, -103.4791, 100, TRUE),
('PVR-FCO', 'Suc. Francisco Villa Vallarta', 'Puerto Vallarta', 20.6401, -105.2219, 100, TRUE),
('TEP-INS', 'Suc. Insurgentes Tepic', 'Tepic', 21.5039, -104.8954, 100, TRUE),
('COL-SEV', 'Suc. Camino Real Colima', 'Colima', 19.2452, -103.7241, 100, TRUE),
('ZLO-BLV', 'Suc. Blvd. Costero Manzanillo', 'Manzanillo', 19.1028, -104.3235, 100, TRUE),
('MZT-MAR', 'Suc. Ejército Mexicano Mazatlán', 'Mazatlán', 23.2261, -106.4189, 100, TRUE),
('CUL-TRR', 'Suc. Tres Ríos Culiacán', 'Culiacán', 24.8142, -107.4018, 100, TRUE),
('LMM-ROS', 'Suc. Rosales Los Mochis', 'Los Mochis', 25.7905, -108.9932, 100, TRUE)
ON CONFLICT (codigo) DO NOTHING;
