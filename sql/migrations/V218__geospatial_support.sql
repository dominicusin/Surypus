-- ============================================================================
-- Geospatial & Location Services
-- ============================================================================

-- Enable PostGIS
CREATE EXTENSION IF NOT EXISTS postgis;

-- Location data
CREATE TABLE IF NOT EXISTS locations (
    location_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID REFERENCES tenants(tenant_id),
    location_name TEXT,
    location_type TEXT CHECK (location_type IN ('warehouse', 'store', 'office', 'vehicle', 'device')),
    coordinates GEOMETRY(Point, 4326),
    address JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Geofences
CREATE TABLE IF NOT EXISTS geofences (
    id SERIAL PRIMARY KEY,
    tenant_id UUID REFERENCES tenants(tenant_id),
    geofence_name TEXT,
    geofence_type TEXT CHECK (geofence_type IN ('polygon', 'circle', 'rectangle')),
    boundaries GEOMETRY,
    alert_enabled BOOLEAN DEFAULT TRUE
);

-- Location tracking
CREATE TABLE IF NOT EXISTS location_tracking (
    id BIGSERIAL PRIMARY KEY,
    entity_id UUID NOT NULL,
    entity_type TEXT,
    location_id UUID REFERENCES locations(location_id),
    coordinates GEOMETRY(Point, 4326),
    recorded_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create location
CREATE OR REPLACE FUNCTION create_location(
    p_tenant_id UUID,
    p_name TEXT,
    p_location_type TEXT,
    p_longitude FLOAT,
    p_latitude FLOAT,
    p_address JSONB DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    v_location_id UUID;
BEGIN
    INSERT INTO locations (tenant_id, location_name, location_type, coordinates, address)
    VALUES (
        p_tenant_id, p_name, p_location_type,
        ST_SetSRID(ST_MakePoint(p_longitude, p_latitude), 4326),
        p_address
    )
    RETURNING location_id INTO v_location_id;
    
    RETURN v_location_id;
END;
$$ LANGUAGE plpgsql;

-- Find nearby locations
CREATE OR REPLACE FUNCTION find_nearby_locations(
    p_longitude FLOAT,
    p_latitude FLOAT,
    p_radius_meters FLOAT DEFAULT 1000
) RETURNS TABLE(location_name TEXT, distance_meters FLOAT) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        l.location_name,
        ST_Distance(l.coordinates::GEOGRAPHY, ST_SetSRID(ST_MakePoint(p_longitude, p_latitude), 4326)::GEOGRAPHY) as distance
    FROM locations l
    WHERE ST_DWithin(l.coordinates::GEOGRAPHY, ST_SetSRID(ST_MakePoint(p_longitude, p_latitude), 4326)::GEOGRAPHY, p_radius_meters)
    ORDER BY distance
    LIMIT 10;
END;
$$ LANGUAGE plpgsql;