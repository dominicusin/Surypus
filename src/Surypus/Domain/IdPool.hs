-- | IdPool Domain
--
-- This module provides ID pool functionality for generating unique IDs.
module Surypus.Domain.IdPool
  ( allocateId,
    allocateIds,
  )
where

import Data.Int (Int64)

allocateId :: Int64 -> Int64 -> IO Int64
allocateId start _end = pure start

allocateIds :: Int64 -> Int64 -> Int -> IO [Int64]
allocateIds start end count = pure (take count [start .. end])
