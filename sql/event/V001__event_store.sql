-- ============================================================================
-- Event Store Schema - Append-Only Event Log
-- ============================================================================
-- Core principle: Events are the source of truth
-- Tables → Events
-- No updates, only append
-- ============================================================================

-- ============================================================================
-- CORE EVENT STORE TABLES
-- ============================================================================

-- Event store - append only
CREATE TABLE IF NOT EXISTS event_store (
    event_id            BIGSERIAL PRIMARY KEY,
    aggregate_id        UUID NOT NULL,
    aggregate_type      VARCHAR(64) NOT NULL,
    event_type          VARCHAR(128) NOT NULL,
    event_version       INT NOT NULL DEFAULT 1,
    event_data          JSONB NOT NULL,
    metadata            JSONB DEFAULT '{}',
    tenant_id           UUID NOT NULL,
    user_id             UUID,
    correlation_id      UUID,
    causation_id        UUID,
    sequence_number     BIGINT NOT NULL,
    created_at          TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Partitioning by tenant for multi-tenancy
    CONSTRAINT valid_event_type CHECK (event_type ~ '^[A-Z][A-Za-z0-9_]*$')
) PARTITION BY LIST (tenant_id);

-- Global sequence for ordering events across all aggregates
CREATE SEQUENCE IF NOT EXISTS global_event_sequence START 1;

-- Event type registry for validation
CREATE TABLE IF NOT EXISTS event_types (
    event_type          VARCHAR(128) PRIMARY KEY,
    aggregate_type      VARCHAR(64) NOT NULL,
    schema_version      INT NOT NULL DEFAULT 1,
    json_schema         JSONB,
    is_deprecated       BOOLEAN DEFAULT FALSE,
    created_at          TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Snapshot table for aggregate performance
CREATE TABLE IF NOT EXISTS aggregate_snapshots (
    snapshot_id         BIGSERIAL PRIMARY KEY,
    aggregate_id        UUID NOT NULL,
    aggregate_type      VARCHAR(64) NOT NULL,
    aggregate_version   INT NOT NULL,
    aggregate_state     JSONB NOT NULL,
    event_count         INT NOT NULL,
    created_at          TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE(aggregate_id, aggregate_version)
);

-- Aggregate registry
CREATE TABLE IF NOT EXISTS aggregates (
    aggregate_id        UUID PRIMARY KEY,
    aggregate_type      VARCHAR(64) NOT NULL,
    current_version     INT NOT NULL DEFAULT 0,
    event_count         INT NOT NULL DEFAULT 0,
    tenant_id           UUID NOT NULL,
    created_at          TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Dead letter queue for failed event processing
CREATE TABLE IF NOT EXISTS event_dlq (
    dlq_id              BIGSERIAL PRIMARY KEY,
    event_id            BIGINT NOT NULL,
    error_message       TEXT,
    retry_count         INT DEFAULT 0,
    last_error_at       TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    resolved            BOOLEAN DEFAULT FALSE
);

-- ============================================================================
-- INDICES
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_event_store_aggregate 
    ON event_store(aggregate_id, sequence_number);

CREATE INDEX IF NOT EXISTS idx_event_store_type 
    ON event_store(event_type, created_at);

CREATE INDEX IF NOT EXISTS idx_event_store_correlation 
    ON event_store(correlation_id);

CREATE INDEX IF NOT EXISTS idx_snapshots_aggregate 
    ON aggregate_snapshots(aggregate_id, aggregate_version DESC);

CREATE INDEX IF NOT EXISTS idx_aggregates_type_tenant 
    ON aggregates(aggregate_type, tenant_id);

-- ============================================================================
-- EVENT STORE FUNCTIONS
-- ============================================================================

-- Append event to store
CREATE OR REPLACE FUNCTION event_append(
    p_aggregate_id UUID,
    p_aggregate_type VARCHAR(64),
    p_event_type VARCHAR(128),
    p_event_data JSONB,
    p_tenant_id UUID,
    p_user_id UUID DEFAULT NULL,
    p_correlation_id UUID DEFAULT NULL,
    p_causation_id UUID DEFAULT NULL,
    p_expected_version INT DEFAULT NULL
)
RETURNS BIGINT AS $$
DECLARE
    v_sequence BIGINT;
    v_current_version INT;
    v_registered_type VARCHAR(128);
BEGIN
    -- Validate event type exists
    SELECT event_type INTO v_registered_type
    FROM event_types
    WHERE event_type = p_event_type AND aggregate_type = p_aggregate_type;
    
    IF v_registered_type IS NULL THEN
        RAISE EXCEPTION 'Unknown event type: % for aggregate %', p_event_type, p_aggregate_type;
    END IF;
    
    -- Get or create aggregate
    INSERT INTO aggregates (aggregate_id, aggregate_type, tenant_id)
    VALUES (p_aggregate_id, p_aggregate_type, p_tenant_id)
    ON CONFLICT (aggregate_id) DO UPDATE SET updated_at = CURRENT_TIMESTAMP
    RETURNING current_version INTO v_current_version;
    
    -- Optimistic concurrency check
    IF p_expected_version IS NOT NULL AND v_current_version != p_expected_version THEN
        RAISE EXCEPTION 'Concurrency conflict: expected %, got %', p_expected_version, v_current_version;
    END IF;
    
    -- Get next global sequence
    SELECT nextval('global_event_sequence') INTO v_sequence;
    
    -- Insert event
    INSERT INTO event_store (
        aggregate_id, aggregate_type, event_type, event_version,
        event_data, tenant_id, user_id, correlation_id, causation_id,
        sequence_number
    ) VALUES (
        p_aggregate_id, p_aggregate_type, p_event_type, 
        (SELECT COALESCE(MAX(event_version), 0) + 1 FROM event_store WHERE aggregate_id = p_aggregate_id),
        p_event_data, p_tenant_id, p_user_id, p_correlation_id, p_causation_id,
        v_sequence
    );
    
    -- Update aggregate version
    UPDATE aggregates 
    SET current_version = current_version + 1, 
        event_count = event_count + 1,
        updated_at = CURRENT_TIMESTAMP
    WHERE aggregate_id = p_aggregate_id;
    
    RETURN v_sequence;
END;
$$ LANGUAGE plpgsql;

-- Get events for aggregate
CREATE OR REPLACE FUNCTION event_get_by_aggregate(
    p_aggregate_id UUID,
    p_from_version INT DEFAULT 0
)
RETURNS TABLE (
    event_id BIGINT,
    event_type VARCHAR(128),
    event_version INT,
    event_data JSONB,
    metadata JSONB,
    sequence_number BIGINT,
    created_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT es.event_id, es.event_type, es.event_version, es.event_data,
           es.metadata, es.sequence_number, es.created_at
    FROM event_store es
    WHERE es.aggregate_id = p_aggregate_id
      AND es.event_version >= p_from_version
    ORDER BY es.event_version;
END;
$$ LANGUAGE plpgsql;

-- Get events by type and time range
CREATE OR REPLACE FUNCTION event_get_by_type(
    p_event_types VARCHAR(128)[],
    p_from TIMESTAMP WITH TIME ZONE DEFAULT NULL,
    p_to TIMESTAMP WITH TIME ZONE DEFAULT NULL,
    p_limit INT DEFAULT 1000
)
RETURNS TABLE (
    event_id BIGINT,
    aggregate_id UUID,
    aggregate_type VARCHAR(64),
    event_type VARCHAR(128),
    event_version INT,
    event_data JSONB,
    sequence_number BIGINT,
    created_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT es.event_id, es.aggregate_id, es.aggregate_type, es.event_type,
           es.event_version, es.event_data, es.sequence_number, es.created_at
    FROM event_store es
    WHERE es.event_type = ANY(p_event_types)
      AND (p_from IS NULL OR es.created_at >= p_from)
      AND (p_to IS NULL OR es.created_at <= p_to)
    ORDER BY es.sequence_number
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- Create snapshot for aggregate
CREATE OR REPLACE FUNCTION snapshot_create(
    p_aggregate_id UUID,
    p_aggregate_type VARCHAR(64),
    p_aggregate_version INT,
    p_aggregate_state JSONB,
    p_event_count INT
)
RETURNS BIGINT AS $$
DECLARE
    v_snapshot_id BIGINT;
BEGIN
    INSERT INTO aggregate_snapshots (
        aggregate_id, aggregate_type, aggregate_version, aggregate_state, event_count
    ) VALUES (
        p_aggregate_id, p_aggregate_type, p_aggregate_version, p_aggregate_state, p_event_count
    )
    RETURNING snapshot_id INTO v_snapshot_id;
    
    RETURN v_snapshot_id;
END;
$$ LANGUAGE plpgsql;

-- Get latest snapshot for aggregate
CREATE OR REPLACE FUNCTION snapshot_get_latest(
    p_aggregate_id UUID
)
RETURNS TABLE (
    snapshot_id BIGINT,
    aggregate_version INT,
    aggregate_state JSONB,
    event_count INT,
    created_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT s.snapshot_id, s.aggregate_version, s.aggregate_state, 
           s.event_count, s.created_at
    FROM aggregate_snapshots s
    WHERE s.aggregate_id = p_aggregate_id
    ORDER BY s.aggregate_version DESC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql;

-- Register event type
CREATE OR REPLACE FUNCTION event_type_register(
    p_event_type VARCHAR(128),
    p_aggregate_type VARCHAR(64),
    p_json_schema JSONB DEFAULT NULL
)
RETURNS VOID AS $$
BEGIN
    INSERT INTO event_types (event_type, aggregate_type, json_schema)
    VALUES (p_event_type, p_aggregate_type, p_json_schema)
    ON CONFLICT (event_type) DO UPDATE SET
        json_schema = COALESCE(p_json_schema, event_types.json_schema),
        created_at = CURRENT_TIMESTAMP;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- EVENT BUS PUBLISHING (for external systems like Kafka)
-- ============================================================================

-- Outbox pattern table for reliable event publishing
CREATE TABLE IF NOT EXISTS event_outbox (
    outbox_id           BIGSERIAL PRIMARY KEY,
    event_id            BIGINT NOT NULL UNIQUE,
    aggregate_id        UUID NOT NULL,
    event_type          VARCHAR(128) NOT NULL,
    event_data          JSONB NOT NULL,
    topic               VARCHAR(256) NOT NULL,
    headers             JSONB DEFAULT '{}',
    published           BOOLEAN DEFAULT FALSE,
    publish_attempts    INT DEFAULT 0,
    last_attempt_at     TIMESTAMP WITH TIME ZONE,
    created_at          TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Function to add event to outbox
CREATE OR REPLACE FUNCTION outbox_append(
    p_event_id BIGINT,
    p_aggregate_id UUID,
    p_event_type VARCHAR(128),
    p_event_data JSONB,
    p_topic VARCHAR(256),
    p_headers JSONB DEFAULT '{}'
)
RETURNS BIGINT AS $$
DECLARE
    v_outbox_id BIGINT;
BEGIN
    INSERT INTO event_outbox (
        event_id, aggregate_id, event_type, event_data, topic, headers
    ) VALUES (
        p_event_id, p_aggregate_id, p_event_type, p_event_data, p_topic, p_headers
    )
    RETURNING outbox_id INTO v_outbox_id;
    
    RETURN v_outbox_id;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-populate outbox on event insert
CREATE OR REPLACE FUNCTION trg_event_to_outbox()
RETURNS TRIGGER AS $$
DECLARE
    v_topic VARCHAR(256);
BEGIN
    v_topic := 'surypus.events.' || LOWER(TG_TABLE_NAME) || '.' || LOWER(NEW.event_type);
    
    PERFORM outbox_append(
        NEW.event_id,
        NEW.aggregate_id,
        NEW.event_type,
        NEW.event_data,
        v_topic,
        jsonb_build_object(
            'tenant_id', NEW.tenant_id,
            'correlation_id', NEW.correlation_id,
            'aggregate_type', NEW.aggregate_type
        )
    );
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply trigger to event store
DROP TRIGGER IF EXISTS trg_event_outbox ON event_store;
CREATE TRIGGER trg_event_outbox
    AFTER INSERT ON event_store
    FOR EACH ROW
    EXECUTE FUNCTION trg_event_to_outbox();

-- ============================================================================
-- READ MODEL PROJECTIONS
-- ============================================================================

-- Projection registry
CREATE TABLE IF NOT EXISTS projections (
    projection_id       BIGSERIAL PRIMARY KEY,
    projection_name     VARCHAR(128) UNIQUE NOT NULL,
    projection_type     VARCHAR(32) NOT NULL CHECK (projection_type IN 'standard', 'custom'),
    handler_function    VARCHAR(256),
    last_sequence       BIGINT DEFAULT 0,
    is_enabled          BOOLEAN DEFAULT TRUE,
    error_count         INT DEFAULT 0,
    last_error          TEXT,
    created_at          TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Projection event handler registry
CREATE TABLE IF NOT EXISTS projection_handlers (
    handler_id          BIGSERIAL PRIMARY KEY,
    projection_id       BIGINT REFERENCES projections(projection_id),
    event_type          VARCHAR(128) NOT NULL,
    handler_order       INT DEFAULT 0,
    is_active           BOOLEAN DEFAULT TRUE,
    UNIQUE(projection_id, event_type)
);

-- Register a projection
CREATE OR REPLACE FUNCTION projection_register(
    p_projection_name VARCHAR(128),
    p_projection_type VARCHAR(32),
    p_handler_function VARCHAR(256)
)
RETURNS BIGINT AS $$
DECLARE
    v_projection_id BIGINT;
BEGIN
    INSERT INTO projections (projection_name, projection_type, handler_function)
    VALUES (p_projection_name, p_projection_type, p_handler_function)
    ON CONFLICT (projection_name) DO UPDATE SET
        handler_function = p_handler_function,
        updated_at = CURRENT_TIMESTAMP
    RETURNING projection_id INTO v_projection_id;
    
    RETURN v_projection_id;
END;
$$ LANGUAGE plpgsql;

-- Update projection checkpoint
CREATE OR REPLACE FUNCTION projection_update_checkpoint(
    p_projection_name VARCHAR(128),
    p_sequence BIGINT
)
RETURNS VOID AS $$
BEGIN
    UPDATE projections 
    SET last_sequence = p_sequence, updated_at = CURRENT_TIMESTAMP
    WHERE projection_name = p_projection_name;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- INITIAL EVENT TYPE REGISTRATION
-- ============================================================================

-- Inventory events
SELECT event_type_register('StockReceived', 'Inventory', NULL);
SELECT event_type_register('StockIssued', 'Inventory', NULL);
SELECT event_type_register('StockAdjusted', 'Inventory', NULL);
SELECT event_type_register('StockReserved', 'Inventory', NULL);
SELECT event_type_register('StockReleased', 'Inventory', NULL);
SELECT event_type_register('LotCreated', 'Inventory', NULL);
SELECT event_type_register('LotConsumed', 'Inventory', NULL);

-- Bill events
SELECT event_type_register('BillCreated', 'Bill', NULL);
SELECT event_type_register('BillUpdated', 'Bill', NULL);
SELECT event_type_register('BillPosted', 'Bill', NULL);
SELECT event_type_register('BillCancelled', 'Bill', NULL);
SELECT event_type_register('BillLineAdded', 'Bill', NULL);

-- Accounting events
SELECT event_type_register('AccountDebited', 'Accounting', NULL);
SELECT event_type_register('AccountCredited', 'Accounting', NULL);
SELECT event_type_register('JournalEntryCreated', 'Accounting', NULL);

-- Person events
SELECT event_type_register('PersonCreated', 'Person', NULL);
SELECT event_type_register('PersonUpdated', 'Person', NULL);
SELECT event_type_register('PersonActivated', 'Person', NULL);
SELECT event_type_register('PersonDeactivated', 'Person', NULL);

-- Salary events
SELECT event_type_register('SalaryRecordCreated', 'Salary', NULL);
SELECT event_type_register('SalaryPeriodClosed', 'Salary', NULL);
SELECT event_type_register('SalaryPaid', 'Salary', NULL);

-- ============================================================================
-- AUDIT AND METRICS
-- ============================================================================

-- Event store metrics
CREATE TABLE IF NOT EXISTS event_metrics (
    metric_id           BIGSERIAL PRIMARY KEY,
    tenant_id           UUID,
    aggregate_type      VARCHAR(64),
    event_type          VARCHAR(128),
    event_count         BIGINT DEFAULT 0,
    period_start        TIMESTAMP WITH TIME ZONE,
    period_end          TIMESTAMP WITH TIME ZONE,
    UNIQUE(tenant_id, aggregate_type, event_type, period_start)
);

-- Function to record metrics
CREATE OR REPLACE FUNCTION event_metrics_record(
    p_tenant_id UUID,
    p_aggregate_type VARCHAR(64),
    p_event_type VARCHAR(128)
)
RETURNS VOID AS $$
DECLARE
    v_period TIMESTAMP WITH TIME ZONE := DATE_TRUNC('hour', CURRENT_TIMESTAMP);
BEGIN
    INSERT INTO event_metrics (tenant_id, aggregate_type, event_type, event_count, period_start, period_end)
    VALUES (p_tenant_id, p_aggregate_type, p_event_type, 1, v_period, v_period + INTERVAL '1 hour')
    ON CONFLICT (tenant_id, aggregate_type, event_type, period_start)
    DO UPDATE SET event_count = event_metrics.event_count + 1;
END;
$$ LANGUAGE plpgsql;
