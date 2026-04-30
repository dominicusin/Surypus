# Surypus Architecture (Canonical RBAC)

- RBAC Canonicalization
- Observability & Alerts
- Self-healing & Config
- Concurrency & Resilience
- Event Store & Projections
- Health Dashboards
- Documentation & Audit

This document outlines the high-level architecture changes introduced in the ongoing Refactor of Surypus with a focus on RBAC canonicalization.

Key Concepts
- Canonical Path: path is canonical_path, used to canonicalize permissions across RBAC tables.
- Circuit Breaker: protects against cascading failures when canonicalization experiences instability.
- Savepoints & Batch Processing: allows partial success during large canonicalization tasks.
- Observability: metrics, health endpoints, dashboards, and alerts.
- Self-Heal: automated remediation to restore canonicalization when safe.
- Concurrency: stress-test friendly design; safe parallelism with locks.

Note: This document evolves with new patches to reflect ongoing work.
