-- Index optimization for billing read paths
C
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_bill_line_bill_id ON bill_line (bill_id);
