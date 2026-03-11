-- Location Tables
CREATE TABLE IF NOT EXISTS location (id BIGSERIAL PRIMARY KEY, code VARCHAR(16) NOT NULL, name VARCHAR(128) NOT NULL, ltype SMALLINT DEFAULT 0, parent_id BIGINT REFERENCES location(id), address TEXT, flags INTEGER DEFAULT 0, UNIQUE(code));
CREATE INDEX IF NOT EXISTS idx_location_parent ON location(parent_id);
