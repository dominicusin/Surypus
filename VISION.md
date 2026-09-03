# Surypus Vision

This document describes the long-term vision and goals for the Surypus project.

## Mission

To build a production-ready, type-safe ERP/CRM system that demonstrates the power of formal methods in real-world business software.

## Core Values

1. **Correctness** - Software that is proven to work correctly
2. **Type Safety** - Leveraging Haskell's type system to prevent bugs
3. **Open Source** - Transparent, community-driven development
4. **Quality** - High standards for code, tests, and documentation
5. **Collaboration** - Welcoming contributors from all backgrounds

## What We're Building

### Target Users

- Small to medium businesses needing an ERP/CRM
- Developers interested in formal verification
- Organizations valuing type safety and correctness

### Key Differentiators

- **Formal Verification** - LiquidHaskell refinements prove invariants
- **Type-Safe Database** - Persistent + Esqueleto prevent SQL injection at type level
- **Event Sourcing** - Complete audit trail, event replay
- **RBAC** - 33 granular permissions
- **Open Source** - MPL-2.0 license, community-driven

## Roadmap

### v2.0 Production Ready ✅
- Core infrastructure (Phases 160-171)
- GUI & Features (Phases 13-21)
- CI/CD pipeline with 61+ workflows
- Docker support
- Nix flake
- devcontainer

### v2.1 Performance & Observability
- OpenTelemetry tracing
- Prometheus metrics
- Structured logging
- Distributed tracing

### v3.0 Multi-Repo Architecture
- Extract surypus-core
- Extract surypus-dal
- Extract surypus-api
- API gateway

### v4.0 Formal Verification
- LiquidHaskell coverage expansion
- Property-based testing
- Chaos engineering

## What We're NOT Building

To maintain focus, we explicitly avoid:

- **Proprietary features** - Everything is open source
- **Vendor lock-in** - Use open standards
- **Over-engineering** - Keep it simple
- **Feature bloat** - Focus on core ERP/CRM functionality

## Success Metrics

- 1000+ GitHub stars
- 100+ contributors
- 10000+ package downloads
- Active community with regular releases

---

*Last updated: 2026-09-03*
