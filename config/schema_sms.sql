-- =============================================================================
-- УЧЕТНЫЕ ЗАПИСИ SMS ПРОВАЙДЕРОВ
-- Соответствуют Core.Integration.SMSAccount
-- Аналог: PPOBJ_SMSPRVACCOUNT
-- =============================================================================

CREATE TABLE IF NOT EXISTS sms_account (
    id SERIAL PRIMARY KEY,
    name VARCHAR(256) NOT NULL,
    provider INT DEFAULT 0,  -- 0:Unknown, 1:SMSRU, 2:Twilio, 3:ByteHand, 4:SMPP
    api_key VARCHAR(512),
    sender VARCHAR(32),
    flags INT DEFAULT 0,
    loc_id INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS sms_log (
    id SERIAL PRIMARY KEY,
    account_id INT NOT NULL REFERENCES sms_account(id),
    phone VARCHAR(20) NOT NULL,
    message TEXT NOT NULL,
    status INT DEFAULT 0,  -- 0:Pending, 1:Sent, 2:Delivered, 3:Failed
    cost NUMERIC(18,4) DEFAULT 0,
    send_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    deliver_time TIMESTAMP,
    error_message TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_sms_log_account ON sms_log(account_id);
CREATE INDEX idx_sms_log_phone ON sms_log(phone);
CREATE INDEX idx_sms_log_status ON sms_log(status);
CREATE INDEX idx_sms_log_send_time ON sms_log(send_time);

-- TRIGGER
CREATE OR REPLACE FUNCTION update_sms_log_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_sms_log_update
    BEFORE UPDATE ON sms_log
    FOR EACH ROW
    EXECUTE FUNCTION update_sms_log_timestamp();

-- VIEW: Статистика SMS
CREATE OR REPLACE VIEW v_sms_stats AS
SELECT 
    sa.id,
    sa.name AS account_name,
    sa.provider,
    COUNT(sl.id) AS total_sms,
    COUNT(CASE WHEN sl.status = 2 THEN 1 END) AS delivered,
    COUNT(CASE WHEN sl.status = 3 THEN 1 END) AS failed,
    COALESCE(SUM(sl.cost), 0) AS total_cost,
    MIN(sl.send_time) AS first_sms,
    MAX(sl.send_time) AS last_sms
FROM sms_account sa
LEFT JOIN sms_log sl ON sl.account_id = sa.id
GROUP BY sa.id, sa.name, sa.provider;
