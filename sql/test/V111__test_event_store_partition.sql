-- Test: dynamic partition creation for event_store on tenant insert
DO $$
DECLARE
  v_agg UUID := gen_random_uuid();
  v_tenant UUID := gen_random_uuid();
  v_goods UUID := gen_random_uuid();
  v_loc UUID := gen_random_uuid();
  v_lot UUID := gen_random_uuid();
  v_data JSONB;
  v_seq BIGINT;
BEGIN
  v_data := jsonb_build_object(
    'lot_id', v_lot,
    'goods_id', v_goods,
    'location_id', v_loc,
    'qty', 5,
    'cost', 1,
    'price', 10,
    'lot_number', 'LOT-TEST',
    'received_at', CURRENT_TIMESTAMP
  );
  v_seq := event_append(v_agg, 'Inventory', 'LotCreated', v_data, v_tenant, NULL, NULL, NULL, NULL);
  RAISE NOTICE 'Partition test event appended: seq=%', v_seq;
END;
$$ LANGUAGE plpgsql;
