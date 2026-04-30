-- =============================================================================
-- ПРИНТЕРЫ, ПРИВЯЗАННЫЕ К СКЛАДАМ
-- Соответствуют Core.Device.LocPrinter
-- Аналог: PPOBJ_LOCPRINTER
-- =============================================================================

CREATE TABLE IF NOT EXISTS loc_printer (
    id SERIAL PRIMARY KEY,
    loc_id INT NOT NULL,
    printer_id INT NOT NULL,
    flags INT DEFAULT 0,
    config JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(loc_id, printer_id)
);

CREATE INDEX idx_loc_printer_loc ON loc_printer(loc_id);
CREATE INDEX idx_loc_printer_printer ON loc_printer(printer_id);

-- TRIGGER
CREATE OR REPLACE FUNCTION update_loc_printer_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_loc_printer_update
    BEFORE UPDATE ON loc_printer
    FOR EACH ROW
    EXECUTE FUNCTION update_loc_printer_timestamp();

-- VIEW: Принтеры с именами
CREATE OR REPLACE VIEW v_loc_printer_with_names AS
SELECT 
    lp.id,
    lp.loc_id,
    l.name AS location_name,
    lp.printer_id,
    bp.name AS printer_name,
    lp.flags,
    lp.config
FROM loc_printer lp
JOIN location l ON l.id = lp.loc_id
JOIN barcode_printer bp ON bp.id = lp.printer_id;
