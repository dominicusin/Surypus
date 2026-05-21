# Phase 14: CRM Data Model Context

## Domain
Implement contacts, companies, and deal pipeline with forecasting for the Surypus ERP/CRM system.

## Canonical Refs
- ROADMAP.md: Phase 14 definition
- REQUIREMENTS.md: CRM-01 through CRM-07 requirements
- src/CRM/Types.hs: Existing CRM type definitions
- src/CRM/Contact.hs: Existing Contact domain type
- src/CRM/Company.hs: Existing Company domain type

## Prior Decisions
- Using Haskell with Hasql for database access (from project vision)
- Event sourcing for audit trail (CRM-07 requirement)
- JWT authentication for API security (from project vision)
- PostgreSQL 16+ as database (non-negotiable)

## Code Context
- Existing CRM module structure with Types, Contact, Company, Deal, Activity modules
- Basic type definitions using UUIDs for IDs
- QuickCheck arbitraries defined for testing
- CRM epoch timestamp set to 2024-01-01

## Decisions

### Database Schema Design
**Decision:** Use separate tables for contacts, companies, and deals with foreign key relationships.
- Contacts table: id (UUID), first_name, last_name, email, phone, mobile_phone, position, company_id (FK), person_id, notes, is_active, created_at, updated_at
- Companies table: id (UUID), name, person_id, email, phone, website, industry, size, annual_revenue, description, is_active, created_at, updated_at
- Deals table: id (UUID), title, description, value, probability, stage_id, contact_id, company_id, expected_close_date, is_active, created_at, updated_at
- Pipeline stages: predefined set of 5-7 stages with probabilities
- Activities table: for logging calls, meetings, etc. linked to contacts/deals

### API Design Approach
**Decision:** RESTful API with JSON serialization using Aeson.
- Standard CRUD endpoints for contacts, companies, deals
- Filtering, sorting, pagination support
- Separate endpoints for pipeline stages and forecast calculations
- WebSocket integration for real-time updates (following DASH-03 pattern)
- Event sourcing: all CRM changes published to EventStore

### Pipeline Forecast Implementation
**Decision:** Probability-weighted revenue calculation updated on deal changes.
- Forecast calculated as sum(deal_value * deal_probability) for all active deals
- Real-time updates via WebSocket when deal value/probability/stage changes
- Caching layer for performance with invalidation on deal updates
- Historical tracking: store daily snapshots for trend analysis

### RBAC Integration
**Decision:** Leverage existing RBAC module with CRM-specific permissions.
- Define permissions: CRM_VIEW, CRM_CREATE, CRM_EDIT, CRM_DELETE for each entity
- Pipeline-specific permissions: PIPELINE_VIEW, PIPELINE_EDIT_STAGE
- Authorization middleware to check permissions before API execution
- Default roles: Sales Rep, Sales Manager, Admin with appropriate CRM permissions

### Event Sourcing Implementation
**Decision:** Append-only event store for all CRM changes.
- Events: ContactCreated, ContactUpdated, ContactDeleted, CompanyCreated, etc.
- Snapshotting strategy: periodic snapshots for performance
- Event versions: handle schema evolution
- Replay capability: rebuild state from event log

## Deferred Ideas
- Social media integration for contacts (future phase)
- Advanced analytics and AI-driven deal scoring (future phase)
- Marketing campaign management (future phase)
- Document attachment to CRM records (future phase)

## Next Steps
Run `/gsd-plan-phase 14` to create implementation plan based on these decisions.