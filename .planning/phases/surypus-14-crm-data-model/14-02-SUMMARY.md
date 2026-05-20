---
phase: 14-crm-data-model
plan: 02
type: summary
status: Complete
completed_at: 2026-05-19T10:30:00Z
---

# Phase 14 Plan 02 Summary: CRM RBAC + Event Sourcing

## Completed Tasks

### 1. RBAC Permissions Added (`src/Surypus/RBAC.hs`)
Added 6 new CRM permissions:
- `CRMContactRead` → "crm_contact:read"
- `CRMContactWrite` → "crm_contact:write"  
- `CRMDealRead` → "crm_deal:read"
- `CRMDealWrite` → "crm_deal:write"
- `CRMLeadRead` → "crm_lead:read"
- `CRMLeadWrite` → "crm_lead:write"

Updated `checkUserPermission` to allow CRM read operations by default.

### 2. Authorization Path Mappings (`src/Surypus/API/Authorization.hs`)
Added path→permission mappings for CRM endpoints:
- `/crm/contacts` (GET/POST) → "crm_contact:read/write"
- `/crm/contacts/:id` (GET/PUT/DELETE) → "crm_contact:read/write"
- `/crm/companies` (GET/POST) → "crm_contact:read/write"
- `/crm/companies/:id` (GET/PUT/DELETE) → "crm_contact:read/write"
- `/crm/deals` (GET/POST) → "crm_deal:read/write"
- `/crm/deals/:id` (GET/PUT/DELETE) → "crm_deal:read/write"
- `/crm/pipeline` → "crm_deal:read"

### 3. CRM Event Store (`src/Infrastructure/EventStore/CRM.hs`)
Created new module with:
- Event payload types: `ContactCreated`, `ContactUpdated`, `ContactDeleted`, `CompanyCreated`, `CompanyUpdated`, `DealCreated`, `DealUpdated`, `DealStageChanged`, `ActivityLogged`
- Sum type `CRMEvent` wrapping all variants
- `CRMEventStore` with `mkCRMEventStore` constructor
- `appendCRMEvent` function using `DAL.EventStore` under the hood
- TemplateHaskell derived `ToJSON` instances

### 4. Surypus.cabal Updated
Added `Infrastructure.EventStore.CRM` to exposed modules.

### 5. CRM API Integration (`surypus-api/src/Surypus/API/CRM.hs`)
Integrated event sourcing in `createContact`:
- Added imports for `Data.Time`, `Infrastructure.EventStore.CRM`, `Control.Exception`
- Created `appendContactCreatedEvent` helper function
- Fire-and-forget call to append event after successful mutation

## Files Modified
- `src/Surypus/RBAC.hs` - Added CRM permissions
- `src/Surypus/API/Authorization.hs` - Added CRM path mappings
- `src/Infrastructure/EventStore/CRM.hs` - New file
- `Surypus.cabal` - Exposed CRM EventStore module
- `surypus-api/src/Surypus/API/CRM.hs` - Integrated event sourcing

## Test Results
All tests pass:
```
surypus-api-test: 6 examples, 0 failures
surypus-common-test: passed
surypus-test: 30 examples, 0 failures
```

## Next Steps
- Continue with Plan 03: Additional event sourcing integration for other CRM mutations
- Plan 04+: Notifications, Reports, Orders phases