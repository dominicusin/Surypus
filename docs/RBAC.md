# Role-Based Access Control (RBAC) System

## Overview

Surypus implements a comprehensive Role-Based Access Control (RBAC) system to manage user permissions across the API. This document outlines the role hierarchy, permissions, and how they are applied to API endpoints.

## Role Hierarchy

The system defines four primary roles with different permission levels:

### 1. **Admin (RoleAdmin)**
- **Description**: Full system access
- **Permissions**: All permissions
- **Typical Users**: System administrators, developers
- **Key Permissions**: AdminAccess, all CRUD operations

### 2. **Manager (RoleManager)**
- **Description**: Business operations management
- **Permissions**: Most write operations, all read operations
- **Typical Users**: Department managers, supervisors
- **Limited By**: Cannot access admin functions, cannot delete sensitive data

### 3. **User (RoleUser)**
- **Description**: Standard user with basic read and write access
- **Permissions**: Limited write operations, basic read operations
- **Typical Users**: Regular employees, data entry staff
- **Limited By**: Read-only for sensitive areas (accounting, payroll), no delete permissions

### 4. **Viewer (RoleViewer)**
- **Description**: Read-only access for reporting and analysis
- **Permissions**: Read-only across the system
- **Typical Users**: External stakeholders, auditors, analysts
- **Limited By**: Cannot perform any write or delete operations

## Permission Types

Permissions are organized by resource type:

### Person Management
- `PersonRead` - Read person data
- `PersonWrite` - Create/update person data
- `PersonDelete` - Delete person records

### Goods & Inventory
- `GoodsRead` - Read goods catalog
- `GoodsWrite` - Create/update goods
- `GoodsDelete` - Delete goods
- `StockRead` - Read stock information
- `StockWrite` - Modify stock (internal use)

### Billing
- `BillRead` - Read bills/invoices
- `BillWrite` - Create/update bills
- `BillDelete` - Delete bills
- `BillPost` - Post/confirm bills

### Locations & Warehouse
- `LocationRead` - Read location data
- `LocationWrite` - Create/update locations
- `LocationDelete` - Delete locations

### Accounting & Finance
- `AccountingRead` - Read accounting entries
- `AccountingWrite` - Create/update accounting entries
- `PaymentRead` - Read payment information
- `PaymentWrite` - Create/update payments
- `PaymentDelete` - Delete payments

### Orders & Operations
- `OrdersWrite` - Manage orders (read/write/delete)

### Taxes & Currencies
- `TaxesWrite` - Manage tax rates and calculations
- `CurrenciesWrite` - Manage currency settings

### Users & Settings
- `UsersRead` - Read user information
- `UsersWrite` - Create/manage users
- `SettingsRead` - Read system settings
- `SettingsWrite` - Modify system settings

### Payroll
- `PayrollRead` - Read payroll data
- `PayrollWrite` - Create/update payroll
- `SalariesWrite` - Manage salary information

### Reports & Analysis
- `ReportsRead` - Access reports
- `ReportsWrite` - Create/manage reports

### Administrative
- `AdminAccess` - Access administrative functions

## API Endpoint Permissions

### Authentication Endpoints (No Auth Required)
```
POST /v1/login          - Public (no auth required)
POST /v1/refresh        - Public (no auth required)
```

### Protected Endpoints

#### Persons
```
GET /v1/persons                - PersonRead
POST /v1/persons               - PersonWrite
GET /v1/persons/:id            - PersonRead
PUT /v1/persons/:id            - PersonWrite
DELETE /v1/persons/:id         - PersonDelete
GET /v1/persons/search/:query  - PersonRead
```

#### Goods
```
GET /v1/goods           - GoodsRead
POST /v1/goods          - GoodsWrite
GET /v1/goods/:id       - GoodsRead
PUT /v1/goods/:id       - GoodsWrite
DELETE /v1/goods/:id    - GoodsDelete
```

#### Locations
```
GET /v1/locations               - LocationRead
POST /v1/locations              - LocationWrite
GET /v1/locations/:id           - LocationRead
PUT /v1/locations/:id           - LocationWrite
DELETE /v1/locations/:id        - LocationDelete
```

#### Bills
```
GET /v1/bills                   - BillRead
POST /v1/bills                  - BillWrite
GET /v1/bills/:id               - BillRead
PUT /v1/bills/:id               - BillWrite
DELETE /v1/bills/:id            - BillDelete
PUT /v1/bills/:id/status        - BillPost
```

#### Payments
```
GET /v1/payments                - PaymentRead
POST /v1/payments               - PaymentWrite
GET /v1/payments/:id            - PaymentRead
PUT /v1/payments/:id            - PaymentWrite
DELETE /v1/payments/:id         - PaymentDelete
```

#### Orders
```
GET /v1/orders                  - OrdersWrite (for access)
POST /v1/orders                 - OrdersWrite
GET /v1/orders/:id              - OrdersWrite (for access)
PUT /v1/orders/:id/status       - OrdersWrite
DELETE /v1/orders/:id           - OrdersWrite
```

#### Taxes
```
GET /v1/taxes                   - TaxesWrite (for access)
POST /v1/taxes                  - TaxesWrite
GET /v1/taxes/:id               - TaxesWrite (for access)
PUT /v1/taxes/:id               - TaxesWrite
DELETE /v1/taxes/:id            - TaxesWrite
```

#### Currencies
```
GET /v1/currencies              - CurrenciesWrite (for access)
POST /v1/currencies             - CurrenciesWrite
GET /v1/currencies/:id          - CurrenciesWrite (for access)
PUT /v1/currencies/:id          - CurrenciesWrite
DELETE /v1/currencies/:id       - CurrenciesWrite
```

#### Stock & Inventory
```
GET /v1/stock                   - StockRead
GET /v1/stock/summary           - StockRead
GET /v1/stock/:goodsId/:locId   - StockRead
GET /v1/stock/goods/:goodsId    - StockRead
```

#### Accounting
```
GET /v1/accounting/accounts         - AccountingRead
POST /v1/accounting/accounts        - AccountingWrite
GET /v1/accounting/accounts/:id     - AccountingRead
PUT /v1/accounting/accounts/:id     - AccountingWrite
DELETE /v1/accounting/accounts/:id  - AccountingWrite

GET /v1/accounting/entries          - AccountingRead
POST /v1/accounting/entries         - AccountingWrite
GET /v1/accounting/entries/:id      - AccountingRead
PUT /v1/accounting/entries/:id      - AccountingWrite
DELETE /v1/accounting/entries/:id   - AccountingWrite
```

#### Payroll
```
GET /v1/payroll                 - PayrollRead
GET /v1/payroll/employees       - PayrollRead
GET /v1/payroll/employees/:id   - PayrollRead
GET /v1/payroll/salaries        - PayrollRead
GET /v1/payroll/salaries/:id    - SalariesWrite (for access)
```

#### Users
```
GET /v1/users           - UsersRead
POST /v1/users          - UsersWrite
```

#### RBAC Administration
```
GET /v1/rbac/roles              - AdminAccess
POST /v1/rbac/roles             - AdminAccess
PUT /v1/rbac/roles/:name        - AdminAccess
DELETE /v1/rbac/roles/:name     - AdminAccess
GET /v1/rbac/grants             - AdminAccess
POST /v1/rbac/grants            - AdminAccess
GET /v1/rbac/grants/active?principal=...              - AdminAccess
POST /v1/rbac/grants/cleanup                         - AdminAccess
PUT /v1/rbac/grants/:from/:to/:permission?resource=... - AdminAccess
DELETE /v1/rbac/grants/:from/:to/:permission?resource=... - AdminAccess
GET /v1/rbac/audit?principal=...&resource=...&offset=...&limit=... - AdminAccess
POST /v1/rbac/audit/cleanup?keep=...                     - AdminAccess
```

Dynamic roles are stored as scoped permissions and can be restricted to a
canonical resource key such as `location:1`, `bill:42`, `report:sales`, or
`accounting-entry:17`.

Delegation grants support temporary escalation through an expiry timestamp.
Expired grants can be cleaned up explicitly through the cleanup endpoint.
Updating a grant refreshes its expiry window while keeping its principal and scoped permission key.
Audit entries can be paginated with `offset`/`limit` and trimmed with the audit cleanup endpoint.

#### Reports
```
GET /v1/reports                 - ReportsRead
GET /v1/reports/metadata        - ReportsRead
GET /v1/reports/templates       - ReportsRead
GET /v1/reports/:id             - ReportsRead
GET /v1/reports/:name/jrxml     - ReportsRead
```

## Implementation Details

### Role-Permission Mapping

The system uses a permission matrix where each role is associated with specific permissions:

```haskell
data RolePermission = RolePermission
  { rpRole :: Role
  , rpPermissions :: [Permission]
  }
```

### Permission Checking

Permissions are checked using the `checkPermission` function:

```haskell
checkPermission :: Text -> Permission -> Either String ()
```

This function:
1. Takes a role (as Text)
2. Takes a required permission
3. Returns `Right ()` if the role has the permission
4. Returns `Left error` if the role lacks the permission

### API Integration

The `requirePermission` helper in `Surypus.API.Server` provides access checking:

```haskell
requirePermission :: Text -> Permission -> Handler ()
```

This function returns a 403 Forbidden response if the permission check fails.

The runtime request pipeline now also supports a request-aware authorization
resolver via advanced middleware. It can:

1. Authenticate non-public requests
2. Resolve required permission from the incoming request path/method
3. Load dynamic roles and delegation grants from an RBAC store
4. Apply resource-level checks using scoped permissions
5. Emit audit entries for allow/deny decisions

## Usage Examples

### Checking Admin Access

```haskell
case checkPermission "admin" AdminAccess of
  Right () -> -- User is admin
  Left err -> -- User is not admin
```

### Assigning Permissions to Endpoints

Endpoints use comments to document required permissions:

```haskell
personsList :: Handler PersonsResponse
-- | GET /v1/persons - Requires PersonRead permission
personsList = return $ PersonsResponse [...] 1
```

### Using Roles in the Application

```haskell
let userRole = roleFromText "manager"
if hasPermission userRole PersonWrite
  then -- Allow write operation
  else -- Deny write operation
```

## Testing

The RBAC system includes comprehensive tests in `test/RBACSpec.hs` and `test/Test.hs`:

- Role permission verification
- Cross-role permission boundaries
- Text-to-role conversion
- Permission checking functions

Run tests with:
```bash
stack test
```

## Future Enhancements

1. **Dynamic Roles**: Create custom roles with specific permission sets
2. **Permission Delegation**: Allow managers to delegate specific permissions
3. **Audit Logging**: Track permission checks and changes
4. **Time-based Permissions**: Temporary permission escalation
5. **Resource-level Permissions**: Fine-grained access control per resource

## Security Considerations

1. **Default Deny**: All permissions must be explicitly granted
2. **Role Validation**: Invalid roles default to the most restrictive (Viewer)
3. **Token-based Verification**: Permissions are verified from JWT tokens
4. **Permission Immutability**: Permissions are defined at compile time

## Configuration

Role definitions are in `src/Surypus/RBAC.hs`. To modify permissions:

1. Update the `Permission` datatype
2. Add the permission to relevant `RolePermission` entries
3. Update endpoint documentation
4. Add corresponding tests

## Support

For questions or issues with the RBAC system, please:
1. Check the test suite in `test/RBACSpec.hs`
2. Review endpoint documentation comments in `src/Surypus/API/Server.hs`
3. Consult the RBAC module documentation in `src/Surypus/RBAC.hs`
