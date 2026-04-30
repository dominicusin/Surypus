-- Phase 6 minor guard: verify projection handler exists for a given projection and event type
CREATE OR REPLACE FUNCTION projection_handler_guard(p_projection_name text, p_event_type text)
RETURNS boolean AS $$
DECLARE
  v_exists boolean;
BEGIN
  SELECT EXISTS (
     SELECT 1
     FROM projections p
     JOIN projection_handlers ph ON ph.projection_id = p.projection_id
     WHERE p.projection_name = p_projection_name
       AND ph.event_type = p_event_type
  ) INTO v_exists;
  RETURN v_exists;
END;
$$ LANGUAGE plpgsql;
