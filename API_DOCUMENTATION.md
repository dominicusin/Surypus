# Surypus ERP API Documentation

## Overview

The Surypus ERP system provides a RESTful API for managing accounting, inventory, tax, and reports. The API is built using Scotty and provides endpoints for core ERP functionality.

## Base URL

```
http://localhost:8080
```

## Authentication

The API uses JWT-based authentication. Include the JWT token in the `Authorization` header:

```
Authorization: Bearer <token>
```

## Endpoints

### Health Check

#### GET /health

Health check endpoint to verify the API is running.

**Response:**
```
OK
```

### Accounting API

#### GET /api/v1/accounting/ledgers

Retrieve all ledgers.

**Response:**
```json
{
  "status": "operational",
  "ledgers": []
}
```

#### POST /api/v1/accounting/transactions

Create a new accounting transaction.

**Response:**
```json
{
  "status": "success",
  "message": "Transaction created (stub)"
}
```

#### GET /api/v1/accounting/balance/:accountId

Get the balance for a specific account.

**Parameters:**
- `accountId` (path parameter): Account ID

**Response:**
```json
{
  "accountId": "123",
  "balance": 0,
  "status": "operational"
}
```

### Inventory API

#### GET /api/v1/inventory/goods

Retrieve all goods in inventory.

**Response:**
```json
{
  "status": "operational",
  "goods": []
}
```

#### POST /api/v1/inventory/goods

Create a new goods item.

**Response:**
```json
{
  "status": "success",
  "message": "Goods created (stub)"
}
```

#### GET /api/v1/inventory/stock/:goodsId

Get stock level for a specific goods item.

**Parameters:**
- `goodsId` (path parameter): Goods ID

**Response:**
```json
{
  "goodsId": "456",
  "quantity": 0,
  "status": "operational"
}
```

#### POST /api/v1/inventory/stock/movement

Record a stock movement (in/out).

**Response:**
```json
{
  "status": "success",
  "message": "Stock movement recorded (stub)"
}
```

### Tax API

#### GET /api/v1/tax/rates

Retrieve all tax rates.

**Response:**
```json
{
  "status": "operational",
  "rates": []
}
```

#### POST /api/v1/tax/calculate

Calculate tax for a given amount.

**Response:**
```json
{
  "status": "success",
  "taxAmount": 0,
  "message": "Tax calculated (stub)"
}
```

### Reports API

#### GET /api/v1/reports/balance-sheet

Generate a balance sheet report.

**Response:**
```json
{
  "status": "operational",
  "message": "Balance sheet report (stub)"
}
```

#### GET /api/v1/reports/income-statement

Generate an income statement report.

**Response:**
```json
{
  "status": "operational",
  "message": "Income statement report (stub)"
}
```

#### GET /api/v1/reports/inventory

Generate an inventory report.

**Response:**
```json
{
  "status": "operational",
  "message": "Inventory report (stub)"
}
```

### Integration API

#### POST /api/v1/integrations/bank-statement/upload

Upload a bank statement (OFX or ISO20022 format).

**Request Body:**
```json
{
  "content": "bank statement content",
  "format": "OFX"
}
```

**Response:**
```json
{
  "importId": "import-tenant-id",
  "rowCount": 0,
  "status": "success",
  "transactions": []
}
```

#### GET /api/v1/integrations/health

Get health status of the integration system.

**Response:**
```json
{
  "status": "healthy",
  "tenantId": "default-tenant",
  "healthData": {}
}
```

#### GET /api/v1/integrations/status

Get the operational status of integration endpoints.

**Response:**
```json
{
  "status": "operational",
  "tenantId": "default-tenant",
  "endpoints": [
    {
      "path": "/api/v1/integrations/bank-statement/upload",
      "status": "available"
    },
    {
      "path": "/api/v1/integrations/health",
      "status": "available"
    },
    {
      "path": "/api/v1/integrations/status",
      "status": "available"
    }
  ]
}
```

## Running the Server

To start the API server:

```bash
stack run
```

The server will start on port 8080 by default.

## Testing

Run the test suite:

```bash
stack test
```

## Status

Current implementation status:
- ✓ Accounting API (stub endpoints)
- ✓ Inventory API (stub endpoints)
- ✓ Tax API (stub endpoints)
- ✓ Reports API (stub endpoints)
- ✓ Integration API (functional)
- ✓ Scotty Web Server

Note: Most endpoints are currently stub implementations and return placeholder data. Full implementation is planned for future phases.
