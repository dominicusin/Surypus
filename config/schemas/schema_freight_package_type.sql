-- =============================================================================
-- ТИПЫ ТРАНСПОРТНОЙ УПАКОВКИ
-- Соответствуют Core.Logistics.FreightPackageType
-- Аналог: PPOBJ_FREIGHTPACKAGETYPE
-- =============================================================================

CREATE TABLE IF NOT EXISTS freight_package_type (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    code VARCHAR(32),
    weight NUMERIC(18,4) DEFAULT 0 CHECK (weight >= 0),
    volume NUMERIC(18,6) DEFAULT 0 CHECK (volume >= 0),
    dimensions VARCHAR(64),
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- DEFAULT DATA
INSERT INTO freight_package_type (id, name, code, weight, volume, dimensions) VALUES
(1, 'Коробка картонная малая', 'BOX_S', 0.5, 0.02, '30x20x20'),
(2, 'Коробка картонная средняя', 'BOX_M', 1.0, 0.05, '40x30x30'),
(3, 'Коробка картонная большая', 'BOX_L', 2.0, 0.1, '60x40x40'),
(4, 'Паллета EUR', 'PALLET_EUR', 25.0, 1.5, '1200x800x144'),
(5, 'Паллета FIN', 'PALLET_FIN', 30.0, 1.8, '1200x1000x144'),
(6, 'Мешок полиэтиленовый', 'BAG', 0.1, 0.01, '50x30x10'),
(7, 'Ящик деревянный', 'CRATE', 5.0, 0.15, '60x40x40'),
(8, 'Контейнер 20ft', 'CONT_20', 2200.0, 33.0, '6058x2438x2591'),
(9, 'Контейнер 40ft', 'CONT_40', 4500.0, 67.0, '12192x2438x2591')
ON CONFLICT (id) DO NOTHING;