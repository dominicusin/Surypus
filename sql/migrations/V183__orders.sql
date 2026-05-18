-- Purchase/Sales Orders
CREATE TABLE IF NOT EXISTS orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    order_type TEXT NOT NULL,
    order_number TEXT NOT NULL,
    counterparty_id UUID,
    order_date DATE NOT NULL DEFAULT CURRENT_DATE,
    total_amount NUMERIC DEFAULT 0,
    status TEXT DEFAULT 'DRAFT',
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS order_lines (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID REFERENCES orders(id) ON DELETE CASCADE,
    goods_id UUID,
    quantity NUMERIC NOT NULL,
    unit_price NUMERIC NOT NULL,
    line_total NUMERIC NOT NULL
);
