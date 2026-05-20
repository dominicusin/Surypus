---
phase: "25"
name: "Multi-tenancy"
created: 2026-05-21
status: ready
---

# Phase 25: Multi-tenancy — Context

**Gathered:** 2026-05-21
**Status:** Ready for planning
**Mode:** Auto-generated (discuss skipped via workflow.skip_discuss)

## Phase Boundary

Support multiple organizations on single instance.

### Requirements
- MT-01: Tenant isolation at database level
- MT-02: Per-tenant configuration
- MT-03: Cross-tenant reporting

### Success Criteria
- Tenant isolation at database level
- Per-tenant configuration
- Cross-tenant reporting

## Implementation Decisions

### Claude's Discretion
All implementation choices are at Claude's discretion — discuss phase was skipped per user setting.

## Codebase Context

The Surypus backend uses Hasql for PostgreSQL. Multi-tenancy requires:
- Schema-based isolation or row-level security
- Tenant context in request middleware
- Migration strategy for existing data
