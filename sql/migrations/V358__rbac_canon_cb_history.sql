-- V358__rbac_canon_cb_history.sql
-- Create canonicalization circuit-breaker history log
CREATE TABLE IF NOT EXISTS rbac.canon_cb_history (
  id BIGSERIAL PRIMARY KEY,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  old_state VARCHAR(20),
  new_state VARCHAR(20),
  details JSONB
);

CREATE OR REPLACE FUNCTION rbac.log_cb_transition(_old TEXT, _new TEXT, _details JSONB DEFAULT '{}'::JSONB) RETURNS VOID AS $$
BEGIN
  INSERT INTO rbac.canon_cb_history (old_state, new_state, details) VALUES (_old, _new, _details);
END;
$$ LANGUAGE plpgsql;
