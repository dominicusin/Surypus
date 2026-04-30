-- Enhanced tenant isolation: add RLS policies for all tenant-scoped tables
DO $$ 
DECLARE
    v_tables TEXT[] := ARRAY['aggregates', 'event_types', 'aggregate_snapshots', 'event_outbox'];
    v_table TEXT;
BEGIN
    FOREACH v_table IN ARRAY v_tables
    LOOP
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = v_table) THEN
            EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY', v_table);
        END IF;
    END LOOP;
END $$;

-- Additional RLS policies for aggregates
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE policyname = 'aggregates_tenant_isolation' AND tablename = 'aggregates'
    ) THEN
        CREATE POLICY aggregates_tenant_isolation ON aggregates
        USING (tenant_id = current_setting('surypus.tenant_id', true)::uuid);
    END IF;
END $$;
