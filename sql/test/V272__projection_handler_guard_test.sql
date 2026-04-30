-- Test: projection_handler_guard canonical readiness
DO $$
DECLARE
  v_ready BOOLEAN;
BEGIN
  SELECT projection_handler_guard('TestProj', 'StockReceived') INTO v_ready;
  IF v_ready THEN
    RAISE NOTICE 'Projection handler guard is ready for TestProj StockReceived';
  ELSE
    RAISE EXCEPTION 'Projection handler guard not ready for TestProj StockReceived';
  END IF;
END;
$$;
