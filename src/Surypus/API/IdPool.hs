-- | IdPool API
--
-- This module provides ID pool functionality for generating unique IDs.
module Surypus.API.IdPool
  ( allocateId,
    allocateIds,
  )
where

import Data.Int (Int64)
import qualified Surypus.Domain.IdPool as Domain

allocateId :: Int64 -> Int64 -> IO Int64
allocateId = Domain.allocateId

allocateIds :: Int64 -> Int64 -> Int -> IO [Int64]
allocateIds = Domain.allocateIds
