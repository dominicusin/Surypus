-- ============================================================================
-- Goods Aggregate - Event Sourcing Implementation (second aggregate)
-- Demonstrates that the event-sourced command/event framework generalises
-- beyond the Bill aggregate to any DSL entity.
-- ============================================================================
-- Events:
--   - GoodsCreated
--   - GoodsPriceChanged
--   - GoodsRenamed
-- ============================================================================

-- Register the event types for the Goods aggregate.
SELECT event_type_register('GoodsCreated',    'Goods', NULL);
SELECT event_type_register('GoodsPriceChanged','Goods', NULL);
SELECT event_type_register('GoodsRenamed',    'Goods', NULL);

-- Projection read model for Goods.
CREATE TABLE IF NOT EXISTS projection_goods (
    goods_id    UUID PRIMARY KEY,
    code        TEXT,
    name        TEXT,
    price       NUMERIC(15,2),
    tenant_id   UUID,
    version     INT DEFAULT 0,
    updated_at  TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Command: Create goods
CREATE OR REPLACE FUNCTION cmd_goods_create(
    p_aggregate_id UUID,
    p_tenant_id UUID,
    p_user_id UUID,
    p_code TEXT,
    p_name TEXT,
    p_price NUMERIC,
    p_expected_version INT DEFAULT NULL
)
RETURNS BIGINT AS $$
DECLARE
    v_event_data JSONB;
    v_sequence BIGINT;
BEGIN
    v_event_data := jsonb_build_object(
        'code', p_code,
        'name', p_name,
        'price', p_price,
        'created_at', CURRENT_TIMESTAMP
    );
    v_sequence := event_append(
        p_aggregate_id, 'Goods', 'GoodsCreated', v_event_data,
        p_tenant_id, p_user_id, NULL, NULL, p_expected_version
    );
    -- Update the read-model projection immediately (the event store is the
    -- source of truth; the projection is rebuilt/advanced from it).
    PERFORM projection_handle_goods(p_aggregate_id, 'GoodsCreated', v_event_data, p_tenant_id);
    RETURN v_sequence;
END;
$$ LANGUAGE plpgsql;

-- Command: Change price
CREATE OR REPLACE FUNCTION cmd_goods_update_price(
    p_aggregate_id UUID,
    p_tenant_id UUID,
    p_user_id UUID,
    p_new_price NUMERIC,
    p_expected_version INT DEFAULT NULL
)
RETURNS BIGINT AS $$
DECLARE
    v_event_data JSONB;
    v_sequence BIGINT;
BEGIN
    v_event_data := jsonb_build_object('price', p_new_price);
    v_sequence := event_append(
        p_aggregate_id, 'Goods', 'GoodsPriceChanged', v_event_data,
        p_tenant_id, p_user_id, NULL, NULL, p_expected_version
    );
    PERFORM projection_handle_goods(p_aggregate_id, 'GoodsPriceChanged', v_event_data, p_tenant_id);
    RETURN v_sequence;
END;
$$ LANGUAGE plpgsql;

-- Command: Rename goods
CREATE OR REPLACE FUNCTION cmd_goods_rename(
    p_aggregate_id UUID,
    p_tenant_id UUID,
    p_user_id UUID,
    p_new_name TEXT,
    p_expected_version INT DEFAULT NULL
)
RETURNS BIGINT AS $$
DECLARE
    v_event_data JSONB;
    v_sequence BIGINT;
BEGIN
    v_event_data := jsonb_build_object('name', p_new_name);
    v_sequence := event_append(
        p_aggregate_id, 'Goods', 'GoodsRenamed', v_event_data,
        p_tenant_id, p_user_id, NULL, NULL, p_expected_version
    );
    PERFORM projection_handle_goods(p_aggregate_id, 'GoodsRenamed', v_event_data, p_tenant_id);
    RETURN v_sequence;
END;
$$ LANGUAGE plpgsql;

-- Projection: apply a Goods event to the read model.
CREATE OR REPLACE FUNCTION projection_handle_goods(
    p_aggregate_id UUID,
    p_event_type TEXT,
    p_event_data JSONB,
    p_tenant_id UUID
)
RETURNS VOID AS $$
BEGIN
    IF p_event_type = 'GoodsCreated' THEN
        INSERT INTO projection_goods (goods_id, code, name, price, tenant_id, version, updated_at)
        VALUES (p_aggregate_id,
                p_event_data->>'code',
                p_event_data->>'name',
                (p_event_data->>'price')::NUMERIC,
                p_tenant_id, 1, CURRENT_TIMESTAMP)
        ON CONFLICT (goods_id) DO UPDATE SET
            code = EXCLUDED.code, name = EXCLUDED.name, price = EXCLUDED.price,
            version = EXCLUDED.version, updated_at = CURRENT_TIMESTAMP;
    ELSIF p_event_type = 'GoodsPriceChanged' THEN
        UPDATE projection_goods
        SET price = (p_event_data->>'price')::NUMERIC,
            version = version + 1,
            updated_at = CURRENT_TIMESTAMP
        WHERE goods_id = p_aggregate_id;
    ELSIF p_event_type = 'GoodsRenamed' THEN
        UPDATE projection_goods
        SET name = p_event_data->>'name',
            version = version + 1,
            updated_at = CURRENT_TIMESTAMP
        WHERE goods_id = p_aggregate_id;
    END IF;
END;
$$ LANGUAGE plpgsql;
