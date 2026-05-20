---
inclusion: fileMatch
fileMatchPattern: ['**/api/**', '**/routes/**', '**/handlers/**', '**/controllers/**']
description: API design conventions (auto-loaded when working in API code)
---
# API Standards

## REST Conventions
- Use plural nouns for resources
- HTTP methods: GET (read), POST (create), PUT (update), DELETE (remove)
- Return appropriate status codes

## Response Format
```json
{
  "data": {},
  "meta": { "timestamp": "ISO8601" },
  "errors": []
}
```

## Versioning
[API versioning strategy]