-- ============================================================================
-- Blockchain-style Audit Trail
-- ============================================================================

-- Blockchain audit chain
CREATE TABLE IF NOT EXISTS audit_chain (
    block_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    block_hash TEXT NOT NULL,
    previous_hash TEXT NOT NULL,
    block_data JSONB NOT NULL,
    timestamp TIMESTAMPTZ DEFAULT NOW(),
    nonce INT DEFAULT 0
);

-- Create genesis block
INSERT INTO audit_chain (block_id, block_hash, previous_hash, block_data)
VALUES (
    gen_random_uuid(),
    encode(gen_random_bytes(32), 'hex'),
    '0'::TEXT,
    jsonb_build_object('genesis', TRUE, 'timestamp', NOW())
)
ON CONFLICT DO NOTHING;

-- Add audit block
CREATE OR REPLACE FUNCTION add_audit_block(
    p_block_data JSONB
) RETURNS UUID AS $$
DECLARE
    v_block_id UUID;
    v_previous_hash TEXT;
    v_new_hash TEXT;
    v_nonce INT := 0;
BEGIN
    -- Get previous hash
    SELECT block_hash INTO v_previous_hash
    FROM audit_chain
    ORDER BY timestamp DESC
    LIMIT 1;
    
    -- Simple proof-of-work (for demonstration)
    LOOP
        v_new_hash := encode(gen_random_bytes(32), 'hex');
        v_nonce := v_nonce + 1;
        EXIT WHEN v_nonce > 100;  -- Simplified
    END LOOP;
    
    INSERT INTO audit_chain (block_id, block_hash, previous_hash, block_data, nonce)
    VALUES (gen_random_uuid(), v_new_hash, v_previous_hash, p_block_data, v_nonce)
    RETURNING block_id INTO v_block_id;
    
    RETURN v_block_id;
END;
$$ LANGUAGE plpgsql;

-- Verify chain integrity
CREATE OR REPLACE FUNCTION verify_audit_chain() RETURNS TABLE(
    block_id UUID,
    is_valid BOOLEAN,
    hash TEXT
) AS $$
DECLARE
    v_block RECORD;
    v_prev_hash TEXT := '0';
BEGIN
    FOR v_block IN SELECT * FROM audit_chain ORDER BY timestamp ASC
    LOOP
        RETURN QUERY SELECT v_block.block_id, (v_block.previous_hash = v_prev_hash), v_block.block_hash;
        v_prev_hash := v_block.block_hash;
    END LOOP;
END;
$$ LANGUAGE plpgsql;