# API Conventions

Standardized conventions for REST API endpoints.

## Response Format

All API responses follow a consistent format:

```json
{
  "status": "success" | "error",
  "data": <payload> | null,
  "error": { "code": "ERR_CODE", "message": "Human readable" } | null
}
```

### Success Response

```json
{
  "status": "success",
  "data": { "id": 123, "name": "Item" },
  "error": null
}
```

### Error Response

```json
{
  "status": "error",
  "data": null,
  "error": { "code": "NOT_FOUND", "message": "Item not found" }
}
```

---

## Pagination

List endpoints support pagination via query parameters:

| Parameter | Type | Default | Max |
|-----------|------|---------|-----|
| `limit` | int | 20 | 100 |
| `offset` | int | 0 | - |
| `total` | int | - | - (returned in response) |

### Paginated Response

```json
{
  "status": "success",
  "data": {
    "items": [...],
    "limit": 20,
    "offset": 0,
    "total": 150
  },
  "error": null
}
```

---

## Error Handling

### HTTP Status Codes

| Code | Meaning | Use Case |
|------|---------|----------|
| 400 | Bad Request | Invalid input, missing required fields |
| 401 | Unauthorized | Missing or invalid JWT token |
| 403 | Forbidden | Valid token but insufficient permissions |
| 404 | Not Found | Resource not found |
| 409 | Conflict | Duplicate or constraint violation |
| 500 | Internal Error | Server failure |

### Error Codes

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid request data"
  }
}
```

---

## Field Naming

### Conventions

- Use **camelCase** for all field names
- Use domain prefixes for clarity:
  - `bill*` - Bill-related fields (billId, billDate, billTotal)
  - `person*` - Person-related fields (personId, personName)
  - `sr*` - Sales requisition fields (srNumber, srDate)

### Examples

```json
{
  "billId": 123,
  "billDate": "2026-04-17",
  "billTotal": 120000,
  "billLines": [
    { "blLineNum": 1, "blGoodsName": "Product A", "blQty": 10 }
  ]
}
```

---

## Endpoint Patterns

### List Endpoint

```
GET /{resource}?limit=20&offset=0&sort=field&order=asc
```

Response:
```json
{
  "status": "success",
  "data": {
    "items": [...],
    "limit": 20,
    "offset": 0,
    "total": 100
  },
  "error": null
}
```

### Get by ID

```
GET /{resource}/:id
```

Response:
```json
{
  "status": "success",
  "data": { ... },
  "error": null
}
```

### Create

```
POST /{resource}
```

Request:
```json
{
  "field1": "value1",
  "field2": "value2"
}
```

Response (201 Created):
```json
{
  "status": "success",
  "data": { "id": 123, ... },
  "error": null
}
```

### Update

```
PUT /{resource}/:id
```

Request:
```json
{
  "field1": "new value"
}
```

Response:
```json
{
  "status": "success",
  "data": { "id": 123, "field1": "new value", ... },
  "error": null
}
```

### Delete

```
DELETE /{resource}/:id
```

Response (204 No Content):
```json
{
  "status": "success",
  "data": null,
  "error": null
}
```

### Related Resources

```
GET /{resource}/:id/{related}
```

Example: `GET /bills/123/lines`

Response:
```json
{
  "status": "success",
  "data": [
    { "blId": 1, "blLineNum": 1, ... }
  ],
  "error": null
}
```