-- Webhook configuration
CREATE TABLE IF NOT EXISTS webhooks (
    webhook_id BIGSERIAL PRIMARY KEY,
    tenant_id UUID NOT NULL,
    url TEXT NOT NULL,
    event_types TEXT[] NOT NULL,
    secret_key TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Webhook delivery log
CREATE TABLE IF NOT EXISTS webhook_delivery (
    delivery_id BIGSERIAL PRIMARY KEY,
    webhook_id BIGINT REFERENCES webhooks(webhook_id),
    event_type TEXT,
    payload JSONB,
    status TEXT CHECK (status IN ('pending', 'success', 'failed')),
    response_code INT,
    response_body TEXT,
    attempts INT DEFAULT 0,
    next_retry TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Webhook trigger (placeholder for external system)
CREATE OR REPLACE FUNCTION trigger_webhook(
    p_webhook_id BIGINT,
    p_event_type TEXT,
    p_payload JSONB
) RETURNS BIGINT AS $$
DECLARE
    v_delivery_id BIGINT;
BEGIN
    INSERT INTO webhook_delivery (webhook_id, event_type, payload, status, attempts, created_at)
    VALUES (p_webhook_id, p_event_type, p_payload, 'pending', 1, NOW())
    RETURNING delivery_id INTO v_delivery_id;
    
    RETURN v_delivery_id;
END;
$$ LANGUAGE plpgsql;