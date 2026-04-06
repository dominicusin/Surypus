module Surypus.Domain.IdPool where

import Data.Int (Int64)

allocateId :: Int64 -> Int64 -> IO Int64
allocateId start _end = pure start -- Simple allocation
