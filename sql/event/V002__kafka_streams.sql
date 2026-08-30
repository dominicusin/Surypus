-- ============================================================================
-- Event Stream Consumer - Postgres to Kafka
-- ============================================================================
-- Polls event_outbox table and publishes to Kafka
-- ============================================================================

-- Function to mark event as published
CREATE OR REPLACE FUNCTION outbox_mark_published(
    p_outbox_id BIGINT
)
RETURNS VOID AS $$
BEGIN
    UPDATE event_outbox
    SET published = TRUE,
        last_attempt_at = CURRENT_TIMESTAMP
    WHERE outbox_id = p_outbox_id;
END;
$$ LANGUAGE plpgsql;

-- Function to increment publish attempts
CREATE OR REPLACE FUNCTION outbox_increment_attempts(
    p_outbox_id BIGINT
)
RETURNS VOID AS $$
BEGIN
    UPDATE event_outbox
    SET publish_attempts = publish_attempts + 1,
        last_attempt_at = CURRENT_TIMESTAMP
    WHERE outbox_id = p_outbox_id;
END;
$$ LANGUAGE plpgsql;

-- Get pending events for publishing
CREATE OR REPLACE FUNCTION outbox_get_pending(
    p_limit INT DEFAULT 100,
    p_max_attempts INT DEFAULT 5
)
RETURNS TABLE (
    outbox_id BIGINT,
    event_id BIGINT,
    aggregate_id UUID,
    event_type VARCHAR(128),
    event_data JSONB,
    topic VARCHAR(256),
    headers JSONB
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        eo.outbox_id,
        eo.event_id,
        eo.aggregate_id,
        eo.event_type,
        eo.event_data,
        eo.topic,
        eo.headers
    FROM event_outbox eo
    WHERE eo.published = FALSE
      AND eo.publish_attempts < p_max_attempts
    ORDER BY eo.created_at ASC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- KAFKA PRODUCER SIMULATION (for demo purposes)
-- In production, this would be an external service using kafka client library
-- ============================================================================

-- Table to simulate Kafka topic messages
CREATE TABLE IF NOT EXISTS kafka_messages (
    message_id          BIGSERIAL PRIMARY KEY,
    topic               VARCHAR(256) NOT NULL,
    key                 TEXT,
    value               JSONB NOT NULL,
    headers             JSONB DEFAULT '{}',
    partition           INT DEFAULT 0,
    msg_offset          BIGINT,
    created_at          TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Produce message to Kafka (simulated)
CREATE OR REPLACE FUNCTION kafka_produce(
    p_topic VARCHAR(256),
    p_key TEXT,
    p_value JSONB,
    p_headers JSONB DEFAULT '{}'
)
RETURNS BIGINT AS $$
DECLARE
    v_offset BIGINT;
    v_message_id BIGINT;
BEGIN
    -- Get next offset for topic
    SELECT COALESCE(MAX(msg_offset), 0) + 1 INTO v_offset
    FROM kafka_messages
    WHERE topic = p_topic;
    
    -- Insert message
    INSERT INTO kafka_messages (topic, key, value, headers, msg_offset)
    VALUES (p_topic, p_key, p_value, p_headers, v_offset)
    RETURNING message_id INTO v_message_id;
    
    RETURN v_message_id;
END;
$$ LANGUAGE plpgsql;

-- Consume messages from Kafka (simulated)
CREATE OR REPLACE FUNCTION kafka_consume(
    p_topic VARCHAR(256),
    p_partition INT DEFAULT 0,
    p_offset BIGINT DEFAULT 0,
    p_limit INT DEFAULT 100
)
RETURNS TABLE (
    message_id BIGINT,
    key TEXT,
    value JSONB,
    headers JSONB,
    msg_offset BIGINT,
    created_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        km.message_id,
        km.key,
        km.value,
        km.headers,
        km.msg_offset,
        km.created_at
    FROM kafka_messages km
    WHERE km.topic = p_topic
      AND km.partition = p_partition
      AND km.msg_offset >= p_offset
    ORDER BY km.msg_offset ASC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- KAFKA TOPICS (simulated)
-- ============================================================================

-- Create topic if not exists
CREATE TABLE IF NOT EXISTS kafka_topics (
    topic               VARCHAR(256) PRIMARY KEY,
    partitions          INT DEFAULT 1,
    replication_factor  INT DEFAULT 1,
    config              JSONB DEFAULT '{}',
    created_at          TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Register Surypus topics
INSERT INTO kafka_topics (topic, partitions, config) VALUES
('surypus.events.inventory.StockReceived', 3, '{"retention.ms": "604800000"}'),
('surypus.events.inventory.StockIssued', 3, '{"retention.ms": "604800000"}'),
('surypus.events.inventory.LotCreated', 3, '{"retention.ms": "604800000"}'),
('surypus.events.inventory.LotConsumed', 3, '{"retention.ms": "604800000"}'),
('surypus.events.bill.BillCreated', 3, '{"retention.ms": "604800000"}'),
('surypus.events.bill.BillPosted', 3, '{"retention.ms": "604800000"}'),
('surypus.events.bill.BillCancelled', 3, '{"retention.ms": "604800000"}'),
('surypus.events.accounting.AccountDebited', 3, '{"retention.ms": "604800000"}'),
('surypus.events.accounting.AccountCredited', 3, '{"retention.ms": "604800000"}'),
('surypus.events.salary.SalaryRecordCreated', 3, '{"retention.ms": "2592000000"}'),  -- 30 days
('surypus.events.person.PersonCreated', 3, '{"retention.ms": "2592000000"}'),
('surypus.events.auth.AuthorizationDecision', 1, '{"retention.ms": "86400000"}'),  -- 1 day
('surypus.projections.updates', 1, '{"cleanup.policy": "compact"}'),
('surypus.commands.execute', 1, '{}')
ON CONFLICT (topic) DO NOTHING;

-- ============================================================================
-- KAFKA CONSUMER GROUPS
-- ============================================================================

CREATE TABLE IF NOT EXISTS kafka_consumer_groups (
    group_id            VARCHAR(256) PRIMARY KEY,
    topics              TEXT[] NOT NULL,
    consumer_count      INT DEFAULT 0,
    last_offset         BIGINT DEFAULT 0,
    created_at          TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Register consumer groups
INSERT INTO kafka_consumer_groups (group_id, topics) VALUES
('projection-inventory-group', ARRAY['surypus.events.inventory.*']),
('projection-bill-group', ARRAY['surypus.events.bill.*']),
('projection-accounting-group', ARRAY['surypus.events.accounting.*']),
('audit-log-group', ARRAY['surypus.events.*']),
('notification-group', ARRAY['surypus.events.bill.BillPosted', 'surypus.events.salary.SalaryRecordCreated'])
ON CONFLICT (group_id) DO NOTHING;

-- ============================================================================
-- KAFKA STREAMS (for event processing)
-- ============================================================================

-- Stream processing configuration
CREATE TABLE IF NOT EXISTS kafka_streams (
    stream_id           VARCHAR(256) PRIMARY KEY,
    source_topic          VARCHAR(256) NOT NULL,
    target_topic          VARCHAR(256),
    processing_function   TEXT NOT NULL,  -- SQL function name
    is_active             BOOLEAN DEFAULT TRUE,
    last_processed_offset BIGINT DEFAULT 0,
    created_at            TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Register streams
INSERT INTO kafka_streams (stream_id, source_topic, target_topic, processing_function) VALUES
('inventory-to-balance', 'surypus.events.inventory.StockReceived', NULL, 'projection_handle_stock_received'),
('inventory-to-balance-issue', 'surypus.events.inventory.StockIssued', NULL, 'projection_handle_stock_issued'),
('bill-to-accounting', 'surypus.events.bill.BillPosted', 'surypus.events.accounting.JournalEntryCreated', 'command_create_journal_entry')
ON CONFLICT (stream_id) DO NOTHING;
