---
phase: 1
plan: 1
type: execute
wave: 1
depends_on: []
files_modified:
  - src/Surypus/WebSocket.hs
  - Surypus.cabal
autonomous: true
status: passed
---
# Phase 1: Project Bootstrap - Summary

## What Was Done

Fixed compilation errors in the Surypus Haskell project:

1. **Added websockets dependency** to Surypus.cabal - the module imported Network.WebSockets but the package wasn't listed in build-depends.

2. **Fixed WS.Connection Eq constraint** - WS.Connection doesn't have an Eq instance, so changed the WebSocket handler to use Int keys for tracking connections instead of comparing connection objects directly.

## Key Changes

### src/Surypus/WebSocket.hs
- Changed `Map Text [WS.Connection]` to `Map Text [(Int, WS.Connection)]`
- Added `handlerNextKey :: TVar Int` for unique connection identification
- Updated `broadcastToRoom` to extract connection from tuple with `\(_, c)`

### Surypus.cabal
- Added `websockets >=0.13` to build-depends

## Verification

- `stack build Surypus` completes successfully
- All 20 modules compile without errors
- Library is ready for use

## Tech Stack Added
- websockets-0.13.0.0 (for WebSocket support)

## Patterns Established
- Use Int keys for tracking resources without Eq instances
- Store keyed tuples instead of bare objects when removal is needed
