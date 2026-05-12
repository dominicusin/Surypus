-- ============================================================
-- Event Sourcing: Accounting Events
-- US-3-1: Accounts Event Store
-- ============================================================

-- Accounting Events Table
-- Stores append-only events for all account state changes
CREATE TABLE IF NOT EXISTS accounting_events (
    id BIGSERIAL PRIMARY KEY,
    event_id UUID DEFAULT uuid_generate_v4() UNIQUE NOT NULL,
    aggregate_id BIGINT NOT NULL REFERENCES account(id),
    aggregate_type VARCHAR(50) DEFAULT 'account',
    event_type VARCHAR(100) NOT NULL,
    event_version INTEGER DEFAULT 1,
    event_data JSONB NOT NULL,
    metadata JSONB,
    sequence_number BIGINT NOT NULL,
    occurred_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Ensure events are ordered per aggregate
    UNIQUE(aggregate_id, sequence_number)
);

-- Indexes for event sourcing queries
CREATE INDEX IF NOT EXISTS idx_accounting_events_aggregate ON accounting_events(aggregate_id);
CREATE INDEX IF NOT EXISTS idx_accounting_events_type ON accounting_events(event_type);
CREATE INDEX IF NOT EXISTS idx_accounting_events_occurred_at ON accounting_events(occurred_at);
CREATE INDEX IF NOT EXISTS idx_accounting_events_event_id ON accounting_events(event_id);

-- Event Types Enum for type safety
CREATE TYPE accounting_event_type AS ENUM (
    'AccountCreated',
    'AccountUpdated',
    'BalanceAdjusted',
    'JournalEntryPosted',
    'AccountReclassified',
    'AccountClosed',
    'AccountReopened'
);

-- Function to get next sequence number for an aggregate
CREATE OR REPLACE FUNCTION next_account_event_sequence(p_aggregate_id BIGINT)
RETURNS BIGINT AS $$
DECLARE
    v_next_sequence BIGINT;
BEGIN
    SELECT COALESCE(MAX(sequence_number), 0) + 1
    INTO v_next_sequence
    FROM accounting_events
    WHERE aggregate_id = p_aggregate_id;
    
    RETURN v_next_sequence;
END;
$$ LANGUAGE plpgsql;

-- Function to append account created event
CREATE OR REPLACE FUNCTION append_account_created_event(
    p_account_id BIGINT,
    p_account_data JSONB,
    p_metadata JSONB DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    v_event_id UUID;
    v_sequence BIGINT;
BEGIN
    v_sequence := next_account_event_sequence(p_account_id);
    v_event_id := uuid_generate_v4();
    
    INSERT INTO accounting_events (
        event_id,
        aggregate_id,
        event_type,
        event_data,
        metadata,
        sequence_number,
        occurred_at
    ) VALUES (
        v_event_id,
        p_account_id,
        'AccountCreated',
        p_account_data,
        p_metadata,
        v_sequence,
        NOW()
    );
    
    RETURN v_event_id;
END;
$$ LANGUAGE plpgsql;

-- Function to append journal entry posted event
CREATE OR REPLACE FUNCTION append_journal_entry_event(
    p_account_id BIGINT,
    p_entry_data JSONB,
    p_metadata JSONB DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    v_event_id UUID;
    v_sequence BIGINT;
BEGIN
    v_sequence := next_account_event_sequence(p_account_id);
    v_event_id := uuid_generate_v4();
    
    INSERT INTO accounting_events (
        event_id,
        aggregate_id,
        event_type,
        event_data,
        metadata,
        sequence_number,
        occurred_at
    ) VALUES (
        v_event_id,
        p_account_id,
        'JournalEntryPosted',
        p_entry_data,
        p_metadata,
        v_sequence,
        NOW()
    );
    
    RETURN v_event_id;
END;
$$ LANGUAGE plpgsql;

-- Function to get all events for an account (for replay)
CREATE OR REPLACE FUNCTION get_account_events(
    p_account_id BIGINT,
    p_from_sequence BIGINT DEFAULT 0
) RETURNS TABLE (
    event_id UUID,
    event_type VARCHAR(100),
    event_data JSONB,
    metadata JSONB,
    sequence_number BIGINT,
    occurred_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ae.event_id,
        ae.event_type,
        ae.event_data,
        ae.metadata,
        ae.sequence_number,
        ae.occurred_at
    FROM accounting_events ae
    WHERE ae.aggregate_id = p_account_id
    AND ae.sequence_number >= p_from_sequence
    ORDER BY ae.sequence_number ASC;
END;
$$ LANGUAGE plpgsql;

-- Trigger to automatically create events on account changes
CREATE OR REPLACE FUNCTION account_change_trigger()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        PERFORM append_account_created_event(
            NEW.id,
            jsonb_build_object(
                'code', NEW.code,
                'name', NEW.name,
                'atype', NEW.atype,
                'currency_id', NEW.currency_id,
                'balance', NEW.balance
            ),
            jsonb_build_object('trigger', 'INSERT', 'user', current_user)
        );
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        -- Only log if balance actually changed
        IF OLD.balance IS DISTINCT FROM NEW.balance THEN
            PERFORM append_journal_entry_event(
                NEW.id,
                jsonb_build_object(
                    'old_balance', OLD.balance,
                    'new_balance', NEW.balance,
                    'change_amount', NEW.balance - OLD.balance
                ),
                jsonb_build_object('trigger', 'UPDATE', 'user', current_user)
            );
        END IF;
        RETURN NEW;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Create trigger on account table
DROP TRIGGER IF EXISTS account_event_trigger ON account;
CREATE TRIGGER account_event_trigger
    AFTER INSERT OR UPDATE ON account
    FOR EACH ROW EXECUTE FUNCTION account_change_trigger();

-- Grant permissions
GRANT SELECT, INSERT ON accounting_events TO surypus_app;
GRANT USAGE, SELECT ON SEQUENCE accounting_events_id_seq TO surypus_app;
GRANT EXECUTE ON FUNCTION next_account_event_sequence TO surypus_app;
GRANT EXECUTE ON FUNCTION append_account_created_event TO surypus_app;
GRANT EXECUTE ON FUNCTION append_journal_entry_event TO surypus_app;
GRANT EXECUTE ON FUNCTION get_account_events TO surypus_app;
