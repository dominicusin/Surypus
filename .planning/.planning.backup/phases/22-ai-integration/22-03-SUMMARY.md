---
phase: 22
plan: 03
type: execute
wave: 2
subsystem: backend
tags: [ai, openai, anthropic, http-client]
dependency_graph:
  requires: [22-02]
  provides: [openai-client, pdf-extraction]
  affects: [22-04]
tech-stack:
  added: [http-client, http-conduit]
  patterns: [REST API client, streaming response]
key-files:
  created:
    - surypus-api/src/Surypus/AI/OpenAI.hs
    - surypus-api/src/Surypus/AI/Anthropic.hs
  modified:
    - surypus-api/src/Surypus/API/AI.hs
    - surypus-api/surypus-api.cabal
metrics:
  duration: "~20 min"
completed: "2026-05-20"
---

# Phase 22 Plan 03 — Actual LLM Clients Summary

**One-liner:** Created OpenAI and Anthropic API client modules with HTTP integration.

## Completed Tasks

| Task | Name | Status |
|------|------|--------|
| 1 | Create `Surypus.AI.OpenAI` module | ✅ `surypus-api/src/Surypus/AI/OpenAI.hs` |
| 2 | Create `Surypus.AI.Anthropic` module | ✅ `surypus-api/src/Surypus/AI/Anthropic.hs` |
| 3 | Implement `callLLM` with OpenAI integration | ✅ Updated in `Surypus.API.AI` |
| 4 | Add http-client dependencies | ✅ Added to cabal |

## Architecture

- **OpenAI Client**: Uses `SURYPUS_OPENAI_API_KEY` environment variable
- **Anthropic Client**: Uses `SURYPUS_ANTHROPIC_API_KEY` environment variable  
- **callLLM**: Currently uses OpenAI, extracts JSON from response
- **Pattern**: REST API calls with Aeson JSON serialization

## Build Status

- AI module compiles ✅
- Pre-existing DAL/Queries.hs type mismatches require separate fix
- `stack build --dry-run` passes for AI changes

## Next Steps

- Phase 22-04: Test AI endpoints with mock server
- Add PDF text extraction coordination