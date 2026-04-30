-- =============================================================================
-- ТЕГИ ОБЪЕКТОВ
-- Соответствуют Core.Common.Tag
-- Аналог: PPOBJ_TAG
-- =============================================================================

CREATE TABLE IF NOT EXISTS tag (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    type INT NOT NULL DEFAULT 0,  -- 0:String, 1:Number, 2:Date, 3:Boolean, 4:Object
    flags INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- DEFAULT DATA
INSERT INTO tag (id, name, type) VALUES
(1, 'Приоритет', 1),
(2, 'Дата начала', 2),
(3, 'Дата окончания', 2),
(4, 'Ответственный', 4),
(5, 'Комментарий', 0),
(6, 'Категория', 0)
ON CONFLICT (id) DO NOTHING;