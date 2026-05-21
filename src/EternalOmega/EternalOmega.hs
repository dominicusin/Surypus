{-# LANGUAGE OverloadedStrings #-}
module EternalOmega.EternalOmega
  ( PerpetualCompletion(..)
  , InfiniteClosure
  , TotalEnding
  , achieveEternalOmega
  ) where

import Data.Text (Text)

-- | Eternal omega type
data PerpetualCompletion = PerpetualCompletion
  { pcId :: Text
  , pcIsPerpetual :: Bool
  , pcIsTotal :: Bool
  } deriving (Eq, Show)

-- | Infinite closure type
type InfiniteClosure = PerpetualCompletion

-- | Total ending type
type TotalEnding = PerpetualCompletion

-- | Achieve eternal omega
achieveEternalOmega :: PerpetualCompletion
achieveEternalOmega = PerpetualCompletion "eternalomega-001" True True