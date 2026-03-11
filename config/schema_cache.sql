-- Cache Tables
CREATE TABLE IF NOT EXISTS cache (id BIGSERIAL PRIMARY KEY, cache_key VARCHAR(256) NOT NULL, cache_value TEXT NOT NULL, expires_at TIMESTAMPTZ, created_at TIMESTAMPTZ DEFAULT NOW());
CREATE INDEX IF NOT EXISTS idx_cache_key ON cache(cache_key);
