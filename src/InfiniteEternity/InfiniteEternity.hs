{-# LANGUAGE OverloadedStrings #-}
module InfiniteEternity.InfiniteEternity
  ( EndlessDuration(..)
  , BoundlessPermanence
  , TimelessContinuation
  , embodyInfiniteEternity
  ) where

import Data.Text (Text)

-- | Infinite eternity type
data EndlessDuration = EndlessDuration
  { edId :: Text
  , edIsEndless :: Bool
  , edIsTimeless :: Bool
  } deriving (Eq, Show)

-- | Boundless permanence type
type BoundlessPermanence = EndlessDuration

-- | Timeless continuation type
type TimelessContinuation = EndlessDuration

-- | Embody infinite eternity
embodyInfiniteEternity :: EndlessDuration
embodyInfiniteEternity = EndlessDuration "infiniteeternity-001" True True