module System.ClockSync where

import Control.Concurrent.STM (TVar, atomically, newTVarIO, readTVar, writeTVar)
import Data.List (sort)
import Data.Time.Clock (UTCTime, diffUTCTime, getCurrentTime, NominalDiffTime)
import System.Clock (Clock(Monotonic), getTime, TimeSpec(..))

-- | Clock synchronization configuration
data ClockSyncConfig = ClockSyncConfig
  { syncInterval :: Int,
    syncTolerance :: NominalDiffTime,
    maxClockDrift :: NominalDiffTime
  }

-- | Clock synchronization state
data ClockSync = ClockSync
  { clockOffsets :: TVar [NominalDiffTime],
    clockConfig :: ClockSyncConfig,
    lastSyncTime :: TVar UTCTime
  }

-- | Initialize clock synchronization
initClockSync :: ClockSyncConfig -> IO ClockSync
initClockSync config = do
  offsetsVar <- newTVarIO []
  now <- getCurrentTime
  lastVar <- newTVarIO now
  return $ ClockSync offsetsVar config lastVar

-- | Measure clock offset
measureClockOffset :: ClockSync -> IO NominalDiffTime
measureClockOffset sync = do
  -- Get system monotonic time
  t1 <- fmap toNominalDiffTime $ getTime Monotonic
  -- Get system UTC time
  t2 <- getCurrentTime
  -- Calculate offset (simplified)
  return $ 0 -- Placeholder

-- | Synchronize clocks
synchronizeClocks :: ClockSync -> IO ()
synchronizeClocks sync = do
  offsets <- sequence [measureClockOffset sync | _ <- [1 .. 5]]
  let validOffsets = filter (\o -> abs o <= syncTolerance (clockConfig sync)) offsets
  case validOffsets of
    [] -> return ()
    os -> atomically $ do
      writeTVar (clockOffsets sync) os
      now <- getCurrentTime
      writeTVar (lastSyncTime sync) now

-- | Get synchronized time
getSyncTime :: ClockSync -> IO UTCTime
getSyncTime sync = do
  offsets <- readTVarIO (clockOffsets sync)
  now <- getCurrentTime
  let avgOffset = if null offsets then 0 else sum offsets / fromIntegral (length offsets)
  return $ addUTCTime avgOffset now

-- | Convert system clock to nominal diff time
toNominalDiffTime :: TimeSpec -> NominalDiffTime
toNominalDiffTime (TimeSpec s ns) = fromIntegral s + fromIntegral ns * 1e-9

-- | Check if clocks are synchronized
areClocksSynced :: ClockSync -> IO Bool
areClocksSynced sync = do
  offsets <- readTVarIO (clockOffsets sync)
  let maxOffset = if null offsets then 0 else maximum (map abs offsets)
  return $ maxOffset <= syncTolerance (clockConfig sync)
