# Deployment Plan: Production (Phase 2 & 3)

- Phase 2 (MVP):
  - Deploy monolith surypus-api + Postgres in a single environment (Docker Compose or Kubernetes namespace)
  - Run migrations automatically on startup; apply seed data
  - Expose REST API and /health, /readiness
  - Expose /metrics (Prometheus) and OpenAPI docs
  - GraphQL/GRPC/Redis not yet deployed; optional WebSocket kept
- Phase 3 (Scale):
  - Move to service-based architecture: surypus-api, surypus-graphql proxy, surypus-grpc internal services
  - Redis-based queue + Redis Streams for event bus
  - API gateway/Ingress for routing
  - Deploy to Kubernetes or ECS with rolling updates
  - Observability: OpenTelemetry, Jaeger/Tempo, Prometheus, Grafana
- Rollout strategy:
  - Canary/Blue-Green deployment for Phase 3 increases
- DR/Backup:
  - Daily backups of Postgres; test restores quarterly
