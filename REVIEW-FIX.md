---
phase: manual
fixed_at: 2026-06-08T00:00:00Z
review_path: src/System/ (manual review)
iteration: 1
findings_in_scope: 10
fixed: 10
skipped: 0
status: all_fixed
---

# Phase Manual: Code Review Fix Report

**Fixed at:** 2026-06-08
**Source review:** Manual review of src/System/ directory
**Iteration:** 1

**Summary:**
- Findings in scope: 10
- Fixed: 10
- Skipped: 0

## Fixed Issues

### Tracing.hs: Missing language pragmas and imports

**Files modified:** `src/System/Tracing.hs`
**Applied fix:**
- Added `{-# LANGUAGE DuplicateRecordFields #-}` for `spanId`/`spanName` in both `TraceContext` and `Span`
- Added `{-# LANGUAGE OverloadedStrings #-}` for aeson 2.x `Key` type in `(.=)` usage
- Added `{-# LANGUAGE RecordWildCards #-}` for `TraceContext {..}` and `Span {..}` patterns
- Added `{-# LANGUAGE ScopedTypeVariables #-}` and `{-# LANGUAGE TypeApplications #-}`
- Added missing imports: `Data.Text (pack)`, `Data.Time.Clock (getCurrentTime)`, `Control.Exception (try, SomeException)`, `Data.Aeson (ToJSON(..), (.=))`, `Data.UUID.V4 (nextRandom)`
- Fixed `UUID.nextRandom` → `nextRandom` (function is in `Data.UUID.V4`, not `Data.UUID`)
- Removed unused STM imports
- Added type application `try @SomeException action`

### MetricsCollector.hs: Multiple compilation errors

**Files modified:** `src/System/MetricsCollector.hs`
**Applied fix:**
- Moved `{-# LANGUAGE OverloadedStrings #-}` before module declaration
- Added `Data.Int (Int64)` import
- Restructured `recordMetric`: moved `getCurrentTime` outside `atomically`, fixed `MetricPoint` construction, fixed `Map.insertWith (..)` → `Map.insertWith (++)`
- Renamed function to match type signature (`aggregateMetrics` instead of `aggregatePoints`)
- Changed return type to `Either Text Double` for Text/<> consistency
- Simplified `exportMetrics` stub to remove dependency on hidden `postgresql-simple` package

### MetricsExport.hs: Missing imports and type errors

**Files modified:** `src/System/MetricsExport.hs`
**Applied fix:**
- Added `{-# LANGUAGE OverloadedStrings #-}`
- Added `Data.Text (Text)` import
- Added `Data.Time.Clock (UTCTime, getCurrentTime)` import
- Added `qualified Data.Map.Strict as Map` and `qualified Data.Text as T` imports
- Added `System.Random (randomIO)` import
- Fixed `exportMetrics` → `doExportMetrics` to avoid conflict with record field name
- Fixed `let series = ...` → `series <- ...` (monadic binding)
- Added type annotation for `randomIO :: IO Int`

### Monitoring.hs: Missing imports and type errors

**Files modified:** `src/System/Monitoring.hs`
**Applied fix:**
- Moved `{-# LANGUAGE OverloadedStrings #-}` before module declaration
- Added `readTVarIO` and `Control.Monad (when)` imports
- Added `Data.Text (Text)` and `Data.Map.Strict (Map)` imports
- Fixed `Data.Map.Strict.insertWith (..)` → `Map.insertWith (++)`
- Fixed `checkThresholds` body: replaced `readTVarIO (config state >>= ...)` with proper record field access
- Fixed `Data.Map.Strict.findWithDefault` → `Map.findWithDefault`

### RateLimiterAdvanced.hs: Multiple type errors

**Files modified:** `src/System/RateLimiterAdvanced.hs`
**Applied fix:**
- Added `readTVarIO`, `addUTCTime`, `NominalDiffTime` to imports
- Fixed `initState` in `initRateLimiterAdvanced`: changed `TokenState 0 =<< getCurrentTime` to pure `initState` taking `now` parameter
- Fixed `initState` in `resetRateLimiterAdvanced`: moved `getCurrentTime` outside `atomically`
- Fixed `evaluateStrategy`: changed `<-` to `let` binding (pure function used in STM)
- Fixed field access: `rateWindowSec limiter` → `rateWindowSec (limiterConfig limiter)`, `rateStrategy limiter` → `rateStrategy (limiterConfig limiter)`
- Fixed `windowStart` calculation: changed from `diffUTCTime` (returns `NominalDiffTime`) to `addUTCTime (negate ...) now` (returns `UTCTime`)
- Fixed `Int`/`Double` comparisons: added `fromIntegral` calls
- Replaced undefined `updateMetrics` call with inline logic

### Transform.hs: Unused imports removed

**Files modified:** `src/System/Transform.hs`
**Applied fix:**
- Removed unused `import qualified Data.Map.Strict as Map`
- Removed unused `formatErrors` from `System.Validation` import

### Retry.hs: Type errors with monadic returns and field access

**Files modified:** `src/System/Retry.hs`
**Applied fix:**
- Added `{-# LANGUAGE ScopedTypeVariables #-}`
- Fixed `withRetries`: extracted field accessors (`maxAttemptsNum`, `baseDelayNum`, etc.) to avoid ambiguity with record field names
- Fixed `Failure errs =<< getCurrentTime` → `Failure errs <$> getCurrentTime`
- Fixed `min maxDelay (baseDelay config * ...)` → `min maxDelayNum (baseDelayNum * ...)`
- Added `SomeException` type annotations in `Left` patterns
- Fixed `untilSuccessWithTimeout`: added `SomeException` type annotation

### Scheduler.hs: Data.PriorityQueue.FingerTree not available, type errors

**Files modified:** `src/System/Scheduler.hs`
**Applied fix:**
- Replaced `Data.PriorityQueue.FingerTree` (from unavailable `PriorityQueue` package) with `Data.Map.Strict`
- Added `pqueue` to cabal build-depends, but then replaced with `Map` since it's already a dependency
- Changed all `PQueue` types to `Map UTCTime [ScheduledJob]`
- Changed `PQ.empty` → `Map.empty`, `PQ.insert` → `Map.insertWith (++)`, `PQ.span` → `Map.split`/`Map.splitLookup`
- Changed `JobType` `Recurring` from `Day -> Day` to `Day -> Bool` to match usage
- Added manual `Show`/`Eq` instances for `JobType` (function fields can't be derived)
- Fixed `calculateNextRun` to use `secondsToDiffTime 0` (not bare integer)
- Added missing STM imports (`writeTVar`, `readTVarIO`, etc.)

### SchedulerJob.hs: Missing imports and type errors

**Files modified:** `src/System/SchedulerJob.hs`
**Applied fix:**
- Added `{-# LANGUAGE OverloadedStrings #-}`
- Added `Data.Text (Text)`, `Data.Int (Int64)` imports, `qualified Data.Text as T`
- Added `System.Random (randomIO)` import
- Fixed `System.HealthCheckCheck` → `System.HealthCheck`
- Fixed `Seconds` type → `Int64` (with manual `Show`/`Eq` instances for `JobSchedule`)
- Restructured `newTVarIO Pending` calls outside constructor field initializers
- Wrapped `writeTVar` calls in `atomically` in `executeJob`
- Fixed `calculateRetryTime`: changed `=<< getCurrentTime` → `<$> getCurrentTime`
- Fixed `Running _ _` → `Running _` (wrong arity)
- Added type annotation for `randomIO :: IO Int`

### Secrets.hs: OverloadedStrings and atomically/stm type errors

**Files modified:** `src/System/Secrets.hs`
**Applied fix:**
- Added `{-# LANGUAGE OverloadedStrings #-}`
- Added `Data.Word (Word8)` import
- Moved `getCurrentTime` outside `atomically` in `rotateSecret` and `logAudit`
- Moved `logAudit` calls outside `atomically` in `storeSecret`, `retrieveSecret`, `rotateSecret`
- Fixed `Data.Text.pack` → `Text.pack` (qualified import is `Text`, not `Data.Text`)
- Fixed `generateSecret`: renamed `length` parameter to `len` (shadowed Prelude), used `Word8` instead of `Int`

---

_Fixed: 2026-06-08_
_Fixer: gsd-code-fixer agent_
_Iteration: 1_
