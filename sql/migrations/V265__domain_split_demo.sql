-- Phase 5: Domain split demo (documentation placeholder)
-- This migration demonstrates how to split domain logic into separate modules
-- and reference the domain boundaries clearly.
DO $$ BEGIN
  RAISE NOTICE 'Domain split demo: separate modules CORE/INVENTORY/ACCOUNTING et al.';
END $$;
