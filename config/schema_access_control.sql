-- ============================================================
-- Access Control Tables - Контроль доступа
-- ============================================================

-- Users (пользователи)
CREATE TABLE IF NOT EXISTS app_user (
    id BIGSERIAL PRIMARY KEY,
    login VARCHAR(64) NOT NULL,
    password_hash VARCHAR(128) NOT NULL,
    person_id BIGINT NOT NULL REFERENCES person(id),
    status SMALLINT DEFAULT 0,  -- 0=ACTIVE, 1=DISABLED, 2=LOCKED, 3=EXPIRED
    flags INTEGER DEFAULT 0,
    last_login TIMESTAMPTZ,
    expire_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(login)
);

-- Roles (роли)
CREATE TABLE IF NOT EXISTS role (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(32) NOT NULL,
    name VARCHAR(128) NOT NULL,
    parent_id BIGINT REFERENCES role(id),
    flags INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(code)
);

-- Permissions (права)
CREATE TABLE IF NOT EXISTS permission (
    id BIGSERIAL PRIMARY KEY,
    role_id BIGINT NOT NULL REFERENCES role(id),
    object_type SMALLINT NOT NULL,  -- 0=GOODS, 1=PERSON, 2=BILL, 3=ORDER, 4=REPORT, 5=SETTINGS
    object_id BIGINT,
    flags INTEGER NOT NULL DEFAULT 0,  -- Биты: 1=READ, 2=WRITE, 4=DELETE, 8=EXEC
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- User roles (связь пользователь-роль)
CREATE TABLE IF NOT EXISTS user_role (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES app_user(id),
    role_id BIGINT NOT NULL REFERENCES role(id),
    granted_at TIMESTAMPTZ DEFAULT NOW(),
    granted_by BIGINT REFERENCES app_user(id),
    UNIQUE(user_id, role_id)
);

-- Индексы
CREATE INDEX IF NOT EXISTS idx_app_user_login ON app_user(login);
CREATE INDEX IF NOT EXISTS idx_app_user_person ON app_user(person_id);

CREATE INDEX IF NOT EXISTS idx_role_code ON role(code);
CREATE INDEX IF NOT EXISTS idx_role_parent ON role(parent_id);

CREATE INDEX IF NOT EXISTS idx_permission_role ON permission(role_id);
CREATE INDEX IF NOT EXISTS idx_permission_object ON permission(object_type, object_id);

CREATE INDEX IF NOT EXISTS idx_user_role_user ON user_role(user_id);
CREATE INDEX IF NOT EXISTS idx_user_role_role ON user_role(role_id);

-- ============================================================
-- Функции
-- ============================================================

-- Проверить право
CREATE OR REPLACE FUNCTION check_permission(
    p_user_id BIGINT,
    p_object_type SMALLINT,
    p_object_id BIGINT,
    p_required_flag INT
) RETURNS BOOLEAN AS $$
DECLARE
    v_has_permission BOOLEAN := FALSE;
BEGIN
    -- Проверить через роли
    SELECT EXISTS (
        SELECT 1 FROM user_role ur
        JOIN permission perm ON perm.role_id = ur.role_id
        WHERE ur.user_id = p_user_id
            AND perm.object_type = p_object_type
            AND (perm.object_id IS NULL OR perm.object_id = p_object_id)
            AND (perm.flags & p_required_flag) > 0
    ) INTO v_has_permission;
    
    RETURN v_has_permission;
END;
$$ LANGUAGE plpgsql;

-- Создать пользователя
CREATE OR REPLACE FUNCTION create_user(
    p_login VARCHAR,
    p_password_hash VARCHAR,
    p_person_id BIGINT
) RETURNS BIGINT AS $$
DECLARE
    v_id BIGINT;
BEGIN
    INSERT INTO app_user (login, password_hash, person_id, status)
    VALUES (p_login, p_password_hash, p_person_id, 0)
    RETURNING id INTO v_id;
    
    RETURN v_id;
END;
$$ LANGUAGE plpgsql;

-- Назначить роль
CREATE OR REPLACE FUNCTION grant_role(
    p_user_id BIGINT,
    p_role_id BIGINT,
    p_granted_by BIGINT
) RETURNS BOOLEAN AS $$
BEGIN
    INSERT INTO user_role (user_id, role_id, granted_by)
    VALUES (p_user_id, p_role_id, p_granted_by)
    ON CONFLICT DO NOTHING;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- Отозвать роль
CREATE OR REPLACE FUNCTION revoke_role(
    p_user_id BIGINT,
    p_role_id BIGINT
) RETURNS BOOLEAN AS $$
BEGIN
    DELETE FROM user_role WHERE user_id = p_user_id AND role_id = p_role_id;
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- Записать вход
CREATE OR REPLACE FUNCTION record_login(p_user_id BIGINT)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE app_user SET last_login = NOW() WHERE id = p_user_id;
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- Представления
-- ============================================================

-- Пользователи и их роли
CREATE VIEW v_user_roles AS
SELECT 
    u.id AS user_id, u.login, u.status, u.last_login,
    r.id AS role_id, r.code AS role_code, r.name AS role_name
FROM app_user u
JOIN user_role ur ON ur.user_id = u.id
JOIN role r ON r.id = ur.role_id
ORDER BY u.login, r.name;

-- Права ролей
CREATE VIEW v_role_permissions AS
SELECT 
    r.id AS role_id, r.code AS role_code, r.name AS role_name,
    p.object_type, p.object_id, p.flags,
    CASE WHEN (p.flags & 1) > 0 THEN TRUE ELSE FALSE END AS can_read,
    CASE WHEN (p.flags & 2) > 0 THEN TRUE ELSE FALSE END AS can_write,
    CASE WHEN (p.flags & 4) > 0 THEN TRUE ELSE FALSE END AS can_delete,
    CASE WHEN (p.flags & 8) > 0 THEN TRUE ELSE FALSE END AS can_exec
FROM role r
JOIN permission p ON p.role_id = r.id
ORDER BY r.name, p.object_type;
