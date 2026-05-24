-- ============================================================
-- Migration V500: All-Russian Classifiers (Общероссийские классификаторы)
-- ============================================================

-- OKSM - Countries of the world (Страны мира)
CREATE TABLE IF NOT EXISTS oksm (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(3) NOT NULL,
    name VARCHAR(128) NOT NULL,
    full_name VARCHAR(256),
    alpha2 VARCHAR(2),
    alpha3 VARCHAR(3),
    UNIQUE(code)
);

-- OKV - Currencies (Валюты)
CREATE TABLE IF NOT EXISTS okv (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(3) NOT NULL,
    letter_code VARCHAR(3),
    name VARCHAR(128) NOT NULL,
    countries TEXT,
    UNIQUE(code)
);

-- OKEI - Units of measurement (Единицы измерения)
CREATE TABLE IF NOT EXISTS okei (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(8) NOT NULL,
    name VARCHAR(256) NOT NULL,
    national_symbol VARCHAR(32),
    international_symbol VARCHAR(32),
    national_letter_code VARCHAR(16),
    international_letter_code VARCHAR(16),
    section VARCHAR(32),
    UNIQUE(code)
);

-- OKPD2 - Product classification by economic activity
CREATE TABLE IF NOT EXISTS okpd2 (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(32) NOT NULL,
    name TEXT NOT NULL,
    parent_code VARCHAR(32),
    UNIQUE(code)
);

-- OKVED2 - Types of economic activity
CREATE TABLE IF NOT EXISTS okved2 (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(16) NOT NULL,
    name TEXT NOT NULL,
    parent_code VARCHAR(16),
    UNIQUE(code)
);

-- TN VED - Foreign Economic Activity Commodity Nomenclature
CREATE TABLE IF NOT EXISTS tnved (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(32) NOT NULL,
    name TEXT NOT NULL,
    parent_code VARCHAR(32),
    section_num VARCHAR(4),
    group_num VARCHAR(4),
    UNIQUE(code)
);

-- OKATO - Administrative-Territorial Division
CREATE TABLE IF NOT EXISTS okato (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(16) NOT NULL,
    name VARCHAR(256) NOT NULL,
    parent_code VARCHAR(16),
    level SMALLINT DEFAULT 0,
    UNIQUE(code)
);

-- OKTMO - Municipal Territories
CREATE TABLE IF NOT EXISTS oktmo (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(16) NOT NULL,
    name VARCHAR(256) NOT NULL,
    parent_code VARCHAR(16),
    UNIQUE(code)
);

-- OKOF - Fixed Assets (Основные фонды)
CREATE TABLE IF NOT EXISTS okof (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(16) NOT NULL,
    name TEXT NOT NULL,
    parent_code VARCHAR(16),
    UNIQUE(code)
);

-- OKP - Products (Продукция)
CREATE TABLE IF NOT EXISTS okp (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(32) NOT NULL,
    name TEXT NOT NULL,
    parent_code VARCHAR(32),
    UNIQUE(code)
);

-- OKDP - Economic Activities (старый ОКДП)
CREATE TABLE IF NOT EXISTS okdp (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(16) NOT NULL,
    name TEXT NOT NULL,
    parent_code VARCHAR(16),
    UNIQUE(code)
);

-- OKSO - Occupations (Специальности)
CREATE TABLE IF NOT EXISTS okso (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(16) NOT NULL,
    name VARCHAR(256) NOT NULL,
    UNIQUE(code)
);

-- OKUN - Services to the Population (Услуги населению)
CREATE TABLE IF NOT EXISTS okun (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(16) NOT NULL,
    name VARCHAR(256) NOT NULL,
    parent_code VARCHAR(16),
    UNIQUE(code)
);

-- OKUD - Management Documentation (Управленческая документация)
CREATE TABLE IF NOT EXISTS okud (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(16) NOT NULL,
    name VARCHAR(256) NOT NULL,
    UNIQUE(code)
);

-- OKFS - Forms of Ownership (Формы собственности)
CREATE TABLE IF NOT EXISTS okfs (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(4) NOT NULL,
    name VARCHAR(256) NOT NULL,
    UNIQUE(code)
);

-- OKNPO - Primary Professional Education (Начальное профессиональное образование)
CREATE TABLE IF NOT EXISTS oknpo (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(16) NOT NULL,
    name VARCHAR(256) NOT NULL,
    UNIQUE(code)
);

-- ============================================================
-- Indexes
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_oksm_code ON oksm(code);
CREATE INDEX IF NOT EXISTS idx_oksm_alpha2 ON oksm(alpha2);
CREATE INDEX IF NOT EXISTS idx_oksm_alpha3 ON oksm(alpha3);

CREATE INDEX IF NOT EXISTS idx_okv_code ON okv(code);

CREATE INDEX IF NOT EXISTS idx_okei_code ON okei(code);

CREATE INDEX IF NOT EXISTS idx_okpd2_code ON okpd2(code);
CREATE INDEX IF NOT EXISTS idx_okpd2_parent ON okpd2(parent_code);

CREATE INDEX IF NOT EXISTS idx_okved2_code ON okved2(code);
CREATE INDEX IF NOT EXISTS idx_okved2_parent ON okved2(parent_code);

CREATE INDEX IF NOT EXISTS idx_tnved_code ON tnved(code);
CREATE INDEX IF NOT EXISTS idx_tnved_parent ON tnved(parent_code);

CREATE INDEX IF NOT EXISTS idx_okato_code ON okato(code);
CREATE INDEX IF NOT EXISTS idx_okato_parent ON okato(parent_code);

CREATE INDEX IF NOT EXISTS idx_oktmo_code ON oktmo(code);
CREATE INDEX IF NOT EXISTS idx_oktmo_parent ON oktmo(parent_code);

CREATE INDEX IF NOT EXISTS idx_okof_code ON okof(code);
CREATE INDEX IF NOT EXISTS idx_okof_parent ON okof(parent_code);

CREATE INDEX IF NOT EXISTS idx_okp_code ON okp(code);
CREATE INDEX IF NOT EXISTS idx_okp_parent ON okp(parent_code);

CREATE INDEX IF NOT EXISTS idx_okdp_code ON okdp(code);
CREATE INDEX IF NOT EXISTS idx_okdp_parent ON okdp(parent_code);

CREATE INDEX IF NOT EXISTS idx_okso_code ON okso(code);
CREATE INDEX IF NOT EXISTS idx_okun_code ON okun(code);
CREATE INDEX IF NOT EXISTS idx_okud_code ON okud(code);
CREATE INDEX IF NOT EXISTS idx_okfs_code ON okfs(code);
CREATE INDEX IF NOT EXISTS idx_oknpo_code ON oknpo(code);
