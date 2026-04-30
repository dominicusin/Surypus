-- ============================================================================
-- Machine Learning Integration
-- ============================================================================

-- ML model registry
CREATE TABLE IF NOT EXISTS ml_models (
    id SERIAL PRIMARY KEY,
    model_name TEXT UNIQUE NOT NULL,
    model_type TEXT CHECK (model_type IN ('regression', 'classification', 'clustering', 'forecasting')),
    version TEXT NOT NULL,
    input_schema JSONB NOT NULL,
    output_schema JSONB NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    trained_at TIMESTAMPTZ DEFAULT NOW()
);

-- Model predictions log
CREATE TABLE IF NOT EXISTS ml_predictions (
    id BIGSERIAL PRIMARY KEY,
    model_id INT REFERENCES ml_models(id),
    input_data JSONB NOT NULL,
    output_data JSONB,
    confidence_score NUMERIC,
    prediction_at TIMESTAMPTZ DEFAULT NOW()
);

-- Register sample models
INSERT INTO ml_models (model_name, model_type, version, input_schema, output_schema)
VALUES 
    ('demand_forecast', 'forecasting', '1.0', 
     '{"fields": ["goods_id", "location_id", "historical_days"]}'::JSONB,
     '{"fields": ["predicted_demand", "confidence"]}'::JSONB),
    ('fraud_detection', 'classification', '1.0',
     '{"fields": ["amount", "user_id", "location_id", "time_of_day"]}'::JSONB,
     '{"fields": ["is_fraud", "fraud_probability"]}'::JSONB)
ON CONFLICT (model_name) DO NOTHING;

-- Log prediction
CREATE OR REPLACE FUNCTION ml_predict(
    p_model_name TEXT,
    p_input_data JSONB
) RETURNS JSONB AS $$
DECLARE
    v_model RECORD;
    v_prediction JSONB;
    v_prediction_id BIGINT;
BEGIN
    SELECT * INTO v_model 
    FROM ml_models 
    WHERE model_name = p_model_name AND is_active = TRUE;
    
    IF v_model IS NULL THEN
        RAISE EXCEPTION 'Model not found: %', p_model_name;
    END IF;
    
    -- Simplified prediction (placeholder for actual ML inference)
    v_prediction := jsonb_build_object(
        'prediction', 'simulated',
        'model', p_model_name,
        'version', v_model.version,
        'timestamp', NOW()
    );
    
    INSERT INTO ml_predictions (model_id, input_data, output_data, confidence_score)
    VALUES (v_model.id, p_input_data, v_prediction, 0.95)
    RETURNING id INTO v_prediction_id;
    
    RETURN v_prediction;
END;
$$ LANGUAGE plpgsql;