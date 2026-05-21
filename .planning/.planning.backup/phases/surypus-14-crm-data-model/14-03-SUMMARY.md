# Phase 14 Plan 03: CRM RBAC + Event Sourcing - Summary

## Status: ✅ COMPLETE

## What Was Done

### 1. RBAC Permissions (Task 1) ✅
Added six CRM permissions to `src/Surypus/RBAC.hs`:
- `CRMContactRead` → "crm_contact:read"
- `CRMContactWrite` → "crm_contact:write"
- `CRMDealRead` → "crm_deal:read"
- `CRMDealWrite` → "crm_deal:write"
- `CRMLeadRead` → "crm_lead:read"
- `CRMLeadWrite` → "crm_lead:write"

All permissions added to:
- `Permission` data type
- `permissionToText` function
- `parsePermissionText` function
- `checkUserPermission` allow-list

### 2. Authorization Path Mappings (Task 2) ✅
Added CRM route mappings to `src/Surypus/API/Authorization.hs`:

**Contacts routes:**
- `["crm", "contacts"]` → GET: read, POST: write
- `["crm", "contacts", _id]` → GET: read, PUT: write, DELETE: write
- `["crm", "contacts", _id, "delete"]` → write
- `["crm", "contacts", "search", _q]` → read

**Companies routes:**
- `["crm", "companies"]` → GET: read, POST: write
- `["crm", "companies", _id]` → GET: read, PUT: write, DELETE: write
- `["crm", "companies", _id, "delete"]` → write
- `["crm", "companies", "search", _q]` → read

**Deals/Pipeline routes:**
- `["crm", "deals"]` → GET: read, POST: write
- `["crm", "deals", _id]` → GET: read, PUT: write, DELETE: write
- `["crm", "deals", _id, "stage", _stageId]` → write
- `["crm", "deals", _id, "activities"]` → read
- `["crm", "pipeline"]` → read

### 3. CRM Event Store (Task 3) ✅
Created `src/Infrastructure/EventStore/CRM.hs` with:
- `CRMEvent` sum type with 9 variants
- Event payload types: `ContactCreated`, `ContactUpdated`, `ContactDeleted`, `CompanyCreated`, `CompanyUpdated`, `CompanyDeleted`, `DealCreated`, `DealStageChanged`, `ActivityLogged`
- `CRMEventStore` data type with `cesPool :: Pool`
- `mkCRMEventStore :: Pool -> CRMEventStore`
- `appendCRMEvent :: CRMEventStore -> CRMEvent -> IO (Either Text ())`
- `getEventInfo :: CRMEvent -> (Int64, Text, Text)`

Module registered in `Surypus.cabal`.

### 4. Server.hs Integration (Task 4) ✅
Modified `surypus-api/src/Surypus/API/Server.hs`:

**Env extension:**
```haskell
data Env = Env
  { envPool :: Pool
  , envLogger :: Log.Logger
  , envWSHandler :: Maybe WS.WebSocketHandler
  , envCRMEventStore :: CRMEventStore  -- NEW
  }
```

**mkEnv updated:**
```haskell
mkEnv pool logger wsHandler =
  Env pool logger wsHandler (mkCRMEventStore pool)
```

**Event sourcing in mutation handlers:**
- `crmContactCreate` - logs `ContactCreatedEvent` after successful creation
- `crmCompanyCreate` - logs `CompanyCreatedEvent` after successful creation
- `crmDealCreate` - logs `DealCreatedEvent` after successful creation

## Build & Test Results

```
surypus-api> copy/register
Installing library...
Installing executable surypus-api...
Registering library for surypus-api-0.1.0.0..
surypus-api> Test suite surypus-api-test passed
6 examples, 0 failures, 1 pending
```

## Key Design Decisions

1. **Keep simple Pool-based handler signatures** - CRM.hs handlers unchanged, event sourcing injected at Server.hs layer
2. **Use aggregate_id=0 for CRM events** - Fire-and-forget pattern; bigint_event_id assigned by DB after insert
3. **Follow Accounting.hs pattern exactly** - Same structure for event types and append functions

## Requirements Satisfied

| Requirement | Status |
|------------|--------|
| CRM-04: Access control | ✅ RBAC permissions defined |
| CRM-07: Event sourcing audit | ✅ Event store integrated |