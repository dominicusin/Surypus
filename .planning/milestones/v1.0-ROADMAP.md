# Roadmap v1.0

## Phase 1: Project Bootstrap

**Goal:** Set up project structure, build system, and basic configuration.

**Requirements:** [REQ-01, REQ-02]

**Success Criteria:**
- Stack build succeeds
- Project compiles
- Basic config structure in place

---

## Phase 2: Database Layer

**Goal:** Implement Hasql-based database access layer with migrations.

**Requirements:** [REQ-10]

**Success Criteria:**
- Database migrations run successfully
- Connection pooling configured
- Basic CRUD operations work

---

## Phase 3: Authentication System

**Goal:** Implement JWT-based authentication.

**Requirements:** [REQ-01]

**Success Criteria:**
- JWT tokens issue and validate
- Login endpoint works
- Protected routes work

---

## Phase 4: RBAC System

**Goal:** Implement role-based access control.

**Requirements:** [REQ-02]

**Success Criteria:**
- Roles and permissions tables
- User-role assignment
- Authorization middleware works

---

## Phase 5: Inventory Core

**Goal:** Implement inventory management entities.

**Requirements:** [REQ-03]

**Success Criteria:**
- Goods, locations, stock tables
- CRUD operations for inventory
- API endpoints for inventory

---

## Phase 6: Accounting Core

**Goal:** Implement accounting system foundation.

**Requirements:** [REQ-04]

**Success Criteria:**
- Chart of accounts
- Journal entries
- Basic accounting reports

---

## Phase 7: Documents System

**Goal:** Implement document management.

**Requirements:** [REQ-05]

**Success Criteria:**
- Bills and bill items tables
- Document CRUD operations
- Document API endpoints

---

## Phase 8: Event Sourcing

**Goal:** Add event store for audit trail.

**Requirements:** [REQ-06]

**Success Criteria:**
- Event store table
- Event emission from critical operations
- Event replay capability

---

## Phase 9: REST API

**Goal:** Expose REST API for all modules.

**Requirements:** [REQ-07]

**Success Criteria:**
- All endpoints documented
- OpenAPI spec generated
- API tests pass

---

## Phase 10: Web Interface

**Goal:** Build web PWA interface.

**Requirements:** [REQ-08]

**Success Criteria:**
- Web interface works
- Responsive design
- API integration complete

---

## Phase 11: LiquidHaskell Verification

**Goal:** Add formal verification to calculations.

**Requirements:** [REQ-09]

**Success Criteria:**
- LH annotations in place
- Verification passes
- CI integration

---

## Phase 12: Production Ready

**Goal:** Final polish and deployment readiness.

**Requirements:** All

**Success Criteria:**
- All tests pass
- Documentation complete
- Deployment scripts ready
