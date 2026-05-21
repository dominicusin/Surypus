# Phase 15: QML Desktop Skeleton - Context

**Gathered:** 2026-05-19
**Status:** Ready for planning
**Mode:** Auto-generated (discuss skipped via workflow.skip_discuss)

<domain>
## Phase Boundary

First working QML Desktop application connected to backend.

**Requirements:** QML-01, QML-02, QML-03, QML-04, QML-05, QML-06

</domain>

<decisions>
## Implementation Decisions

### Claude's Discretion
All implementation choices are at Claude's discretion — discuss phase was skipped per user setting. Use ROADMAP phase goal, success criteria, and codebase conventions to guide decisions.

</decisions>

<code_context>
## Existing Code Insights

- QML files already exist in `qml/` directory (~2,430 lines across 4 files: Main.qml, main.qml, LoginPanel.qml)
- Existing QML has full desktop ERP interface with dashboard, goods, persons, bills, inventory, stock, payroll modules
- REST API base URL configured for port 3000
- Login endpoint `/login` returns JWT token
- Build system: Stack + Haskell backend on port 3000

</code_context>

<specifics>
## Specific Ideas

No specific requirements — discuss phase skipped. Refer to ROADMAP phase description and success criteria:
- Login flow works with JWT
- Dashboard shows KPIs fetched via REST API
- Navigation between modules works
- QRestAccessManager or OpenAPI client used for API calls
- App packages as AppImage

</specifics>

<deferred>
## Deferred Ideas

None — discuss phase skipped.
</deferred>
