# Surypus Architecture - Redesigned Data & Control Flows

## System Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                        PRESENTATION LAYER                           │
│  ┌──────────┐  ┌──────────────┐  ┌──────────┐  ┌──────────────┐   │
│  │ QML Desk │  │ Web SPA      │  │ Mobile   │  │ External API │   │
│  │ - Dashbd │  │ - Dashboard  │  │ - Stock  │  │ - EDI/EGIAS  │   │
│  │ - CRUD   │  │ - CRUD       │  │ - Orders │  │ - VETIS      │   │
│  │ - Charts │  │ - Reports    │  │ - Scan   │  │ - Contracts  │   │
│  └────┬─────┘  └──────┬───────┘  └────┬─────┘  └──────┬───────┘   │
│       │               │               │               │            │
│       └───────────────┼───────────────┼───────────────┘            │
│                       ▼               ▼                            │
│              ┌────────────────────────────┐                        │
│              │    WebSocket Hub (STM)     │                        │
│              │    Real-time notifications │                        │
│              └────────────────────────────┘                        │
└─────────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         API LAYER (Scotty)                          │
│                                                                     │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────────┐  │
│  │ Auth Middlew │  │ Rate Limiter │  │ Metrics (Prometheus)     │  │
│  │ JWT validate │  │ IP-based     │  │ Request counter          │  │
│  │ RBAC check   │  │ 100/60s      │  │ Response time            │  │
│  │ Audit log    │  │              │  │ Error rates              │  │
│  └──────┬───────┘  └──────┬───────┘  └──────────┬───────────────┘  │
│         │                 │                      │                  │
│         ▼                 ▼                      ▼                  │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │                     Route Handlers                           │   │
│  │  /api/v1/{resource}  - CRUD for all entities                 │   │
│  │  /api/v1/auth/*      - Authentication                        │   │
│  │  /api/v1/reports/*   - Report generation                     │   │
│  │  /api/v1/dashboard   - Analytics                             │   │
│  └─────────────────────────┬────────────────────────────────────┘   │
│                            │                                        │
│                            ▼                                        │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │                    SERVICE LAYER                              │   │
│  │  Business logic orchestration, validation, transactions       │   │
│  │                                                              │   │
│  │  PersonService    - Create/Update/Delete with validation     │   │
│  │  GoodsService     - CRUD + price management                  │   │
│  │  BillService      - Document lifecycle, line management      │   │
│  │  OrderService     - Order processing, fulfillment            │   │
│  │  PaymentService   - Payment processing, reconciliation       │   │
│  │  StockService     - Inventory operations, FIFO               │   │
│  │  AccountingService- Double-entry bookkeeping                 │   │
│  │  PayrollService   - Salary calculations, tax withholding     │   │
│  │  ReportService    - Report generation, scheduling            │   │
│  │  AuthService      - Authentication, token management         │   │
│  └─────────────────────────┬────────────────────────────────────┘   │
│                            │                                        │
│  ┌─────────────────────────▼────────────────────────────────────┐   │
│  │                    EVENT SYSTEM                               │   │
│  │  Domain events for cross-cutting concerns                    │   │
│  │                                                              │   │
│  │  Event types:                                                 │   │
│  │    EntityCreated / EntityUpdated / EntityDeleted             │   │
│  │    BillPosted / BillCancelled                                │   │
│  │    StockReserved / StockReleased / StockAdjusted             │   │
│  │    PaymentReceived / PaymentRefunded                         │   │
│  │    UserLoggedIn / UserLoggedOut                              │   │
│  │                                                              │   │
│  │  Handlers:                                                   │   │
│  │    AuditHandler    - Log all events to audit table           │   │
│  │    WebSocketHandler- Broadcast to connected clients          │   │
│  │    StockHandler    - Update stock on bill post               │   │
│  │    AccHandler      - Create acc entries on bill post         │   │
│  └─────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      DATA ACCESS LAYER (Hasql)                      │
│                                                                     │
│  ┌────────────────────┐  ┌────────────────────────────────────────┐ │
│  │   Repositories     │  │         Type-Safe Queries              │ │
│  │                    │  │                                        │ │
│  │  PersonRepository  │  │  Encoders: Haskell types -> SQL params │ │
│  │  GoodsRepository   │  │  Decoders: SQL rows -> Haskell types   │ │
│  │  BillRepository    │  │  Statements: SQL with type safety      │ │
│  │  OrderRepository   │  │                                        │ │
│  │  PaymentRepository │  │  Features:                             │ │
│  │  StockRepository   │  │    - Server-side pagination (SQL)      │ │
│  │  AccPlanRepository │  │    - Filtered queries                  │ │
│  │  AccTurnRepository │  │    - Batch operations                  │ │
│  │  AuditRepository   │  │    - Transaction support               │ │
│  │  JobRepository     │  │                                        │ │
│  └─────────┬──────────┘  └──────────────────┬─────────────────────┘ │
│            │                                │                       │
│            └────────────────┬───────────────┘                       │
│                             ▼                                       │
│            ┌────────────────────────────────┐                       │
│            │    Connection Pool (Hasql)     │                       │
│            └────────────────┬───────────────┘                       │
└─────────────────────────────┼───────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                       DATABASE (PostgreSQL)                         │
│                                                                     │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │ Core Tables:                                                   │ │
│  │   persons, goods, units, locations, stock                      │ │
│  │   bill, bill_line, order_head, order_line                      │ │
│  │   payment, goods_price                                         │ │
│  │   acc_plan, acc_turn, currency, tax                            │ │
│  │   employee, salary                                             │ │
│  │                                                                │ │
│  │ System Tables:                                                 │ │
│  │   users, roles, permissions                                    │ │
│  │   audit_log                                                    │ │
│  │   jobs, job_dependencies                                       │ │
│  │   report_templates, report_schedules, report_snapshots         │ │
│  │   document_type, document_register, document_counter           │ │
│  │                                                                │ │
│  │ Stored Procedures:                                             │ │
│  │   calc_vat()           - VAT calculation                       │ │
│  │   calc_bill_totals()   - Bill total recalculation              │ │
│  │   post_bill()          - Bill posting with stock updates       │ │
│  │   calc_salary()        - Payroll calculation                   │ │
│  │   fifo_writeoff()      - FIFO stock write-off                  │ │
│  │   trial_balance()      - Trial balance report                  │ │
│  └────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────┘
```

## Data Flow: Bill Creation (End-to-End)

```
User Action (UI)                    API Request (POST /api/v1/bills)
     │                                        │
     ▼                                        ▼
┌──────────┐    HTTP POST    ┌─────────────────────────────┐
│ QML/Web  │ ──────────────> │ APIServer.routeHandler      │
│ Form     │   JSON body     │   - Parse JSON (BillInput)  │
│          │                 │   - Validate JWT token       │
└──────────┘                 │   - Check RBAC permissions   │
                             └──────────────┬──────────────┘
                                            │
                                            ▼
                             ┌─────────────────────────────┐
                             │ BillService.createBill      │
                             │   - Validate input           │
                             │   - Check person exists      │
                             │   - Check location exists    │
                             │   - Calculate totals         │
                             │   - Create bill + lines      │
                             │   - Emit BillCreated event   │
                             └──────────────┬──────────────┘
                                            │
                              ┌─────────────┼─────────────┐
                              ▼             ▼             ▼
                   ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
                   │ BillRepo     │ │ AuditHandler │ │ WSHandler    │
                   │ INSERT bill  │ │ Log event    │ │ Broadcast    │
                   │ INSERT lines │ │ to audit_log │ │ to clients   │
                   └──────────────┘ └──────────────┘ └──────────────┘
                              │
                              ▼
                   ┌──────────────────────┐
                   │ PostgreSQL            │
                   │ BEGIN;                │
                   │  INSERT INTO bill ... │
                   │  INSERT INTO bill_line│
                   │  INSERT INTO audit_log│
                   │ COMMIT;              │
                   └──────────────────────┘
```

## Data Flow: Bill Posting (Document Lifecycle)

```
PUT /api/v1/bills/:id/status?status=2
     │
     ▼
┌─────────────────────────────┐
│ BillService.postBill        │
│   - Validate bill exists    │
│   - Check status transition │
│     (draft -> posted only)  │
│   - Validate lines exist    │
│   - Validate stock avail.   │
│   - Emit BillPosting event  │
└──────────────┬──────────────┘
               │
    ┌──────────┼──────────┬──────────────┐
    ▼          ▼          ▼              ▼
┌────────┐ ┌────────┐ ┌────────┐  ┌──────────────┐
│BillRepo│ │StockSvc│ │AccSvc  │  │AuditHandler  │
│UPDATE  │ │Reserve │ │Create  │  │Log all       │
│status=2│ │stock   │ │entries │  │operations    │
└────────┘ └────────┘ └────────┘  └──────────────┘
    │          │          │
    ▼          ▼          ▼
┌──────────────────────────────────────────┐
│ PostgreSQL (Transaction)                 │
│  UPDATE bill SET status = 2 WHERE id=$1  │
│  UPDATE stock SET qtty = qtty - qty      │
│  INSERT INTO acc_turn (debit, credit)    │
│  INSERT INTO audit_log                   │
│ COMMIT;                                  │
└──────────────────────────────────────────┘
```

## Control Flow: Authentication

```
Request with Bearer Token
     │
     ▼
┌─────────────────────────────┐
│ authMiddleware              │
│   - Extract token from      │
│     Authorization header    │
│   - Validate JWT signature  │
│   - Check expiration        │
│   - Load user + role        │
│   - Attach to request ctx   │
└──────────────┬──────────────┘
               │
        ┌──────┴──────┐
        ▼             ▼
   Valid Token    Invalid/Missing
        │             │
        ▼             ▼
┌──────────────┐ ┌──────────────┐
│ Continue to  │ │ Return 401   │
│ route handler│ │ Unauthorized │
│ with user ctx│ │              │
└──────────────┘ └──────────────┘
```

## Module Dependency Graph

```
APIServer
  ├── Service.*
  │     ├── Core.* (Domain Logic)
  │     ├── DAL.Repository.*
  │     │     ├── DAL.Queries
  │     │     ├── DAL.Mutations
  │     │     └── DAL.Types
  │     └── Surypus.Event
  ├── Surypus.JWT
  ├── Surypus.RBAC
  ├── Surypus.Audit
  ├── Surypus.Validation
  └── Surypus.WebSocket
```

## Key Design Decisions

1. **Service Layer**: Separates business logic from HTTP handlers
2. **Event System**: Decouples cross-cutting concerns (audit, WebSocket, stock updates)
3. **Repository Pattern**: Type-safe DB access with Hasql
4. **Server-side Pagination**: All paginated queries use SQL LIMIT/OFFSET
5. **Transaction Support**: Critical operations (bill posting) use DB transactions
6. **Audit Trail**: All mutations logged to audit_log table
7. **RBAC**: Role-based access control on all write operations
8. **WebSocket**: Real-time notifications for UI updates
