-- Phase 9: race-free stock reservation + explicit release.
--
-- The legacy fn_reserve_stock() reads (qtty - resrv_qtty) and then UPDATEs in
-- two steps, which is a TOCTOU race: two concurrent reservations can both see
-- enough stock and over-reserve. These replacements do the availability check
-- and the increment in a SINGLE atomic UPDATE guarded by a WHERE clause, so
-- concurrent reservations can never exceed on-hand stock. We also add the
-- missing release operation (the projection side previously had only a
-- placeholder for StockReleased).

-- Reserve stock atomically. Returns 1 if the reservation was applied, 0 if
-- there was insufficient available stock (qtty - resrv_qtty < p_quantity).
CREATE OR REPLACE FUNCTION fn_reserve_stock_atomic(
    p_goods_id  BIGINT,
    p_loc_id    BIGINT,
    p_quantity  NUMERIC(15,3)
)
RETURNS INTEGER AS $$
DECLARE
    v_updated INTEGER;
BEGIN
    UPDATE stock
    SET resrv_qtty = resrv_qtty + p_quantity
    WHERE goods_id = p_goods_id
      AND location_id = p_loc_id
      AND (qtty - resrv_qtty) >= p_quantity;   -- atomic availability guard
    GET DIAGNOSTICS v_updated = ROW_COUNT;
    RETURN v_updated;
END;
$$ LANGUAGE plpgsql;

-- Release a previously made reservation. Returns 1 on success, 0 if there was
-- no matching reservation to release (or quantity would go negative).
CREATE OR REPLACE FUNCTION fn_release_stock(
    p_goods_id  BIGINT,
    p_loc_id    BIGINT,
    p_quantity  NUMERIC(15,3)
)
RETURNS INTEGER AS $$
DECLARE
    v_updated INTEGER;
BEGIN
    UPDATE stock
    SET resrv_qtty = GREATEST(0, resrv_qtty - p_quantity)
    WHERE goods_id = p_goods_id
      AND location_id = p_loc_id
      AND resrv_qtty >= p_quantity;
    GET DIAGNOSTICS v_updated = ROW_COUNT;
    RETURN v_updated;
END;
$$ LANGUAGE plpgsql;

-- Convenience wrapper that matches the legacy fn_reserve_stock(...) BOOLEAN
-- contract but uses the race-free implementation.
CREATE OR REPLACE FUNCTION fn_reserve_stock(
    p_goods_id  BIGINT,
    p_loc_id    BIGINT,
    p_quantity  NUMERIC(18,4)
)
RETURNS BOOLEAN AS $$
DECLARE
    v_rows INTEGER;
BEGIN
    SELECT fn_reserve_stock_atomic(p_goods_id, p_loc_id, p_quantity) INTO v_rows;
    RETURN v_rows = 1;
END;
$$ LANGUAGE plpgsql;
