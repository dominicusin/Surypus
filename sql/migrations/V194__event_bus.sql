-- ============================================================================
-- Event Bus Pattern
-- ============================================================================

-- Event subscriptions
CREATE TABLE IF NOT EXISTS event_subscriptions (
    id SERIAL PRIMARY KEY,
    subscriber_name TEXT NOT NULL,
    event_type_pattern TEXT NOT NULL,
    endpoint_url TEXT,
    filter_condition JSONB,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Default subscriptions
INSERT INTO event_subscriptions (subscriber_name, event_type_pattern, endpoint_url)
VALUES 
    ('audit_subscriber', '%.Created', NULL),
    ('notification_subscriber', '%.Created,%.Updated', NULL),
    ('analytics_subscriber', '*', NULL)
ON CONFLICT DO NOTHING;

-- Event delivery log
CREATE TABLE IF NOT EXISTS event_delivery_log (
    id BIGSERIAL PRIMARY KEY,
    event_id BIGINT,
    subscription_id INT REFERENCES event_subscriptions(id),
    status TEXT CHECK (status IN ('pending', 'delivered', 'failed', 'retrying')) DEFAULT 'pending',
    attempts INT DEFAULT 0,
    delivered_at TIMESTAMPTZ,
    error_message TEXT
);

-- Publish event to subscribers
CREATE OR REPLACE FUNCTION event_bus_publish(
    p_event_type TEXT,
    p_event_data JSONB,
    p_tenant_id UUID
) RETURNS INT AS $$
DECLARE
    v_subscriber RECORD;
    v_delivered_count INT := 0;
BEGIN
    FOR v_subscriber IN
        SELECT * FROM event_subscriptions 
        WHERE is_active = TRUE 
          AND (event_type_pattern = '*' OR p_event_type LIKE event_type_pattern)
    LOOP
        BEGIN
            INSERT INTO event_delivery_log (event_id, subscription_id, status, attempts)
            VALUES (NULL, v_subscriber.id, 'pending', 1);
            
            v_delivered_count := v_delivered_count + 1;
        EXCEPTION WHEN OTHERS THEN
            NULL;
        END;
    END LOOP;
    
    RETURN v_delivered_count;
END;
$$ LANGUAGE plpgsql;