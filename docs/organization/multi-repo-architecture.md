# Multi-Repository Architecture

This document describes the target architecture for scaling Surypus into multiple coordinated repositories.

## Current State

Single monorepo (`surypus/surypus`) containing:
- Core library
- DAL (Database Access Layer)
- API Server (Scotty)
- CLI tools
- Documentation

## Target Architecture

### Repository Structure

```
surypus/
├── surypus-core/          # Core domain types and logic
├── surypus-dal/           # Database access layer
├── surypus-api/           # REST API server
├── surypus-cli/           # Command-line tools
├── surypus-web/           # Web frontend (QML/Reflex)
├── surypus-common/        # Shared utilities
├── surypus-proto/         # Protocol Buffers / API definitions
├── surypus-infra/         # Infrastructure (Terraform, K8s)
└── surypus/               # Meta-repo (documentation, CI templates)
```

### Repository Details

#### surypus-core

**Purpose:** Domain types, business logic, invariants

```
surypus-core/
├── src/
│   ├── Core/
│   │   ├── Tax.hs
│   │   ├── Accounting.hs
│   │   ├── Inventory.hs
│   │   └── Types.hs
│   └── Surypus/
│       ├── Types.hs
│       └── Refined.hs      # LiquidHaskell refinements
├── test/
├── Surypus-Core.cabal
├── package.yaml
├── stack.yaml
└── README.md
```

**Dependencies:** base, text, time, uuid, liquidhaskell

#### surypus-dal

**Purpose:** Database access, migrations, queries

```
surypus-dal/
├── src/
│   ├── DAL/
│   │   ├── Queries.hs
│   │   ├── Mutations.hs
│   │   ├── Schema.hs
│   │   └── Migration.hs
│   └── Database/
│       └── Persistent.hs
├── sql/
│   ├── migrations/
│   └── test/
├── test/
├── Surypus-DAL.cabal
├── package.yaml
├── stack.yaml
└── README.md
```

**Dependencies:** surypus-core, persistent, esqueleto, postgresql-simple

#### surypus-api

**Purpose:** REST API server

```
surypus-api/
├── app/
│   └── Main.hs
├── src/
│   ├── API/
│   │   ├── Server.hs
│   │   ├── Routes.hs
│   │   ├── Auth.hs
│   │   └── Middleware.hs
│   └── Service/
│       ├── BillService.hs
│       ├── AuthService.hs
│       └── InventoryService.hs
├── test/
├── Surypus-API.cabal
├── package.yaml
├── stack.yaml
├── Dockerfile
└── README.md
```

**Dependencies:** surypus-core, surypus-dal, scotty, jwt, bcrypt

#### surypus-common

**Purpose:** Shared utilities across all repos

```
surypus-common/
├── src/
│   ├── Surypus/
│   │   ├── Logging.hs
│   │   ├── Config.hs
│   │   ├── Error.hs
│   │   └── Prelude.hs
│   └── Utils/
│       └── Text.hs
├── test/
├── Surypus-Common.cabal
├── package.yaml
├── stack.yaml
└── README.md
```

**Dependencies:** base, text, mtl, monad-logger

### API Gateway

For multi-repo architecture, an API Gateway handles:

- Request routing
- Authentication/authorization
- Rate limiting
- Request/response transformation
- Load balancing

Options:
1. **Kong** - Open-source API gateway
2. **NGINX + Lua** - Lightweight, customizable
3. **Custom Haskell gateway** - Using Warp/Wai

### Shared Infrastructure

#### Protocol Buffers

Define API contracts in `.proto` files:

```protobuf
syntax = "proto3";

package surypus;

service BillService {
  rpc CreateBill(CreateBillRequest) returns (Bill);
  rpc GetBill(GetBillRequest) returns (Bill);
  rpc ListBills(ListBillsRequest) returns (stream Bill);
}

message Bill {
  string id = 1;
  string customer_id = 2;
  repeated BillLine lines = 3;
  double total = 4;
  string status = 5;
}
```

#### Event Bus

For inter-service communication:

- **Kafka** - High-throughput, durable
- **RabbitMQ** - Flexible routing
- **Redis Pub/Sub** - Simple, fast
- **PostgreSQL LISTEN/NOTIFY** - Simple, no extra infra

### CI/CD Strategy

#### Per-Repository CI

Each repository has its own CI pipeline:

1. **Build** - Compile with Stack
2. **Test** - Run unit + integration tests
3. **Lint** - HLint + Fourmolu
4. **Security** - Secret scanning + dependency audit
5. **Publish** - Build Docker image + push to GHCR

#### Cross-Repository CI

Meta-repo coordinates:

1. **Integration tests** - Test all services together
2. **Version bump** - Coordinate version updates
3. **Release** - Create coordinated releases
4. **Deploy** - Deploy all services

### Migration Plan

#### Phase 1: Preparation (Current)
- [x] Establish CI/CD templates
- [x] Create reusable GitHub Actions
- [x] Document architecture decisions (ADRs)
- [x] Set up standardized labels and workflows

#### Phase 2: Extract Common
- [ ] Create `surypus-common` repository
- [ ] Move shared types and utilities
- [ ] Publish to internal Hackage/Stackage
- [ ] Update main repo to use surypus-common

#### Phase 3: Extract Core
- [ ] Create `surypus-core` repository
- [ ] Move domain types and logic
- [ ] Add LiquidHaskell refinements
- [ ] Publish and version independently

#### Phase 4: Extract DAL
- [ ] Create `surypus-dal` repository
- [ ] Move database layer
- [ ] Add migration tooling
- [ ] Set up integration test infrastructure

#### Phase 5: Extract API
- [ ] Create `surypus-api` repository
- [ ] Move API server
- [ ] Add API gateway
- [ ] Set up load balancing

#### Phase 6: Full Microservices
- [ ] Add event bus (Kafka/RabbitMQ)
- [ ] Implement service discovery
- [ ] Add distributed tracing
- [ ] Set up monitoring (Prometheus/Grafana)

### Versioning Strategy

- **Semantic Versioning** for all packages
- **PVP (Package Versioning Policy)** for Hackage compatibility
- **Lock files** for reproducible builds
- **Changelog** for each repository

### Communication Between Services

#### Synchronous (REST/gRPC)

For immediate responses:
- **gRPC** - High-performance, typed
- **REST + JSON** - Simple, universal
- **GraphQL** - Flexible queries

#### Asynchronous (Events)

For eventual consistency:
- **Domain events** - BillCreated, PaymentReceived
- **Integration events** - UserRegistered, InventoryUpdated
- **Saga pattern** - Distributed transactions

### Monitoring

#### Metrics

- **Prometheus** - Metrics collection
- **Grafana** - Visualization
- **Custom Haskell metrics** - EKG, Prometheus Haskell client

#### Logging

- **Structured logging** - JSON format
- **Distributed tracing** - OpenTelemetry
- **Centralized** - ELK stack or Loki

#### Alerting

- **PagerDuty** - Incident management
- **Slack** - Team notifications
- **Email** - Non-urgent alerts
