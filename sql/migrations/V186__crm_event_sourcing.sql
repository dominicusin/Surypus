-- V186: CRM event sourcing — auto-append events to event_store on CRM mutations

-- Trigger: deal stage change → event_store
CREATE OR REPLACE FUNCTION crm_deal_stage_event() RETURNS TRIGGER AS $$
BEGIN
  IF OLD.stage_id IS DISTINCT FROM NEW.stage_id THEN
    INSERT INTO event_store (aggregate_id, aggregate_type, event_type, event_version, event_data)
    VALUES (
      NEW.id,
      'crm_deal',
      'DealStageChanged',
      1,
      jsonb_build_object(
        'dealId',      NEW.id,
        'fromStageId', OLD.stage_id,
        'toStageId',   NEW.stage_id,
        'dealName',    NEW.deal_name,
        'changedAt',   NOW()
      )
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_crm_deal_stage_event ON crm_deals;
CREATE TRIGGER trg_crm_deal_stage_event
  AFTER UPDATE ON crm_deals
  FOR EACH ROW EXECUTE FUNCTION crm_deal_stage_event();

-- Trigger: new deal created → event_store
CREATE OR REPLACE FUNCTION crm_deal_created_event() RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO event_store (aggregate_id, aggregate_type, event_type, event_version, event_data)
  VALUES (
    NEW.id,
    'crm_deal',
    'DealCreated',
    1,
    jsonb_build_object(
      'dealId',    NEW.id,
      'dealName',  NEW.deal_name,
      'dealValue', NEW.deal_value,
      'stageId',   NEW.stage_id,
      'createdAt', NEW.created_at
    )
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_crm_deal_created_event ON crm_deals;
CREATE TRIGGER trg_crm_deal_created_event
  AFTER INSERT ON crm_deals
  FOR EACH ROW EXECUTE FUNCTION crm_deal_created_event();

-- Trigger: contact created → event_store
CREATE OR REPLACE FUNCTION crm_contact_created_event() RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO event_store (aggregate_id, aggregate_type, event_type, event_version, event_data)
  VALUES (
    NEW.id,
    'crm_contact',
    'ContactCreated',
    1,
    jsonb_build_object(
      'contactId', NEW.id,
      'firstName', NEW.first_name,
      'lastName',  NEW.last_name,
      'email',     NEW.email,
      'createdAt', NEW.created_at
    )
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_crm_contact_created_event ON crm_contacts;
CREATE TRIGGER trg_crm_contact_created_event
  AFTER INSERT ON crm_contacts
  FOR EACH ROW EXECUTE FUNCTION crm_contact_created_event();
