---
phase: 22
plan: 02
type: execute
wave: 1
subsystem: backend
tags: [ai, llm, openai, http-client]
dependency_graph:
  requires: [22-01]
  provides: [llm-client, document-parser]
  affects: [22-03]
tech-stack:
  added: [http-client, aeson]
  patterns: [REST API client, JSON request/response]
key-files:
  created:
    - surypus-api/src/Surypus/API/AI.hs
  modified:
    - surypus-api/surypus-api.cabal
    - surypus-api/src/Surypus/API/Server.hs
metrics:
  duration: "~15 min"
completed: "2026-05-19"
---

# Phase 22 Plan 02 — LLM API Client Summary

**One-liner:** Created AI API module with document parsing types and REST endpoint integration.

## Completed Tasks

| Task | Name | Status |
|------|------|--------|
| 1 | Create AI API module with types | ✅ `surypus-api/src/Surypus/API/AI.hs` |
| 2 | Add Surypus.API.AI to cabal exposed-modules | ✅ |
| 3 | Add `/api/v1/ai/parse-document` endpoint | ✅ `Server.hs` |
| 4 | Implement aiParseDocument handler | ✅ |

## Architecture & Decisions

- **AIDocumentParseRequest**: Contains doc content + type for LLM parsing
- **AIDocumentParseResponse**: Structured response with vendor, invoice number, amounts, line items
- **callLLM**: Stub function ready for actual OpenAI/Anthropic integration
- **REST endpoint**: POST `/api/v1/ai/parse-document`

## Build Status

- ✅ `stack build` passes
- ✅ `stack test` passes (6 examples, 1 pending, 0 failures)

## Next Steps

- Phase 22-03: Implement actual OpenAI/Anthropic HTTP clients
- Add PDF text extraction via external service
- Connect parsed data to Bill creation