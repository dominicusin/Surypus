-- Index to optimize reads on projection_stock_balance per tenant/goods/location
CREATE INDEX IF NOT EXISTS idx_projection_stock_balance_tenant_goods_loc
ON projection_stock_balance (tenant_id, goods_id, location_id);
