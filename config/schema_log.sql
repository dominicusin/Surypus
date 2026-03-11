-- Log Tables
CREATE TABLE IF NOT EXISTS log (id BIGSERIAL PRIMARY KEY, level SMALLINT NOT NULL, message TEXT NOT NULL, source VARCHAR(128), timestamp TIMESTAMPTZ DEFAULT NOW());
CREATE INDEX IF NOT EXISTS idx_log_level ON log(level);
CREATE INDEX IF NOT EXISTS idx_log_timestamp ON log(timestamp);
