# Audit Trails

- Canonicalization events are recorded in: canon_events
- Metrics are emitted to: canon_metrics
- Batch runs are recorded in: canon_batch_runs
- Health status is exposed via: canon_health_detailed and canon_health
- Self-heal actions are logged via canonicalization paths and log events

Guidelines:
- Ensure every mutation via canonicalization is logged with a batch context when possible
- Review health dashboards regularly and set up alerts for circuit breaker transitions and high inconsistency counts
