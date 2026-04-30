-- ============================================================================
-- Advanced Notification System
-- ============================================================================

-- Notification templates
CREATE TABLE IF NOT EXISTS notification_templates (
    id SERIAL PRIMARY KEY,
    template_name TEXT UNIQUE NOT NULL,
    title_template TEXT,
    body_template TEXT NOT NULL,
    channels TEXT[] DEFAULT ARRAY['email'],
    variables JSONB DEFAULT '[]',
    is_active BOOLEAN DEFAULT TRUE
);

-- Notification preferences
CREATE TABLE IF NOT EXISTS user_notification_prefs (
    user_id UUID REFERENCES users(user_id),
    channel TEXT,
    enabled BOOLEAN DEFAULT TRUE,
    quiet_hours_start TIME,
    quiet_hours_end TIME,
    PRIMARY KEY(user_id, channel)
);

-- Preference default
INSERT INTO notification_templates (template_name, title_template, body_template)
VALUES 
    ('event_created', 'New Event: {{event_type}}', 'Event {{event_type}} was created for aggregate {{aggregate_id}}'),
    ('alert', 'Alert: {{alert_type}}', 'Alert: {{message}}')
ON CONFLICT (template_name) DO NOTHING;

-- Send notification
CREATE OR REPLACE FUNCTION send_notification(
    p_user_id UUID,
    p_template_name TEXT,
    p_variables JSONB DEFAULT '{}'
) RETURNS BIGINT AS $$
DECLARE
    v_template RECORD;
    v_title TEXT;
    v_body TEXT;
    v_notification_id BIGINT;
BEGIN
    SELECT * INTO v_template FROM notification_templates 
    WHERE template_name = p_template_name AND is_active = TRUE;
    
    IF v_template IS NULL THEN
        RETURN NULL;
    END IF;
    
    -- Simple template variable replacement
    v_title := v_template.title_template;
    v_body := v_template.body_template;
    
    -- Replace variables (simplified)
    FOR key, value IN SELECT * FROM jsonb_each_text(p_variables)
    LOOP
        v_title := replace(v_title, '{{' || key || '}}', value);
        v_body := replace(v_body, '{{' || key || '}}', value);
    END LOOP;
    
    -- Get user preferences
    IF EXISTS (
        SELECT 1 FROM user_notification_prefs
        WHERE user_id = p_user_id AND channel = 'email' AND enabled = FALSE
    ) THEN
        RETURN NULL;
    END IF;
    
    INSERT INTO notifications (tenant_id, user_id, title, body, notification_type)
    VALUES (NULL, p_user_id, v_title, v_body, 'notification')
    RETURNING notification_id INTO v_notification_id;
    
    RETURN v_notification_id;
END;
$$ LANGUAGE plpgsql;

-- Batch notification
CREATE OR REPLACE FUNCTION send_batch_notifications(
    p_user_ids UUID[],
    p_template_name TEXT,
    p_variables JSONB DEFAULT '{}'
) RETURNS INT AS $$
DECLARE
    v_user UUID;
    v_sent INT := 0;
BEGIN
    FOREACH v_user IN ARRAY p_user_ids
    LOOP
        IF send_notification(v_user, p_template_name, p_variables) IS NOT NULL THEN
            v_sent := v_sent + 1;
        END IF;
    END LOOP;
    
    RETURN v_sent;
END;
$$ LANGUAGE plpgsql;