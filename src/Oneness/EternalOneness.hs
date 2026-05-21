{-# LANGUAGE OverloadedStrings #-}
module Oneness.EternalOneness
  ( PerpetualSingularity(..)
  , CompleteMerging
  , TotalUnification
  , mergeEternally
  ) where

import Data.Text (Text)

-- | Eternal oneness type
data PerpetualSingularity = PerpetualSingularity
  { psId :: Text
  , psIsPerpetual :: Bool
  , psIsTotal :: Bool
  } deriving (Eq, Show)

-- | Complete merging type
type CompleteMerging = PerpetualSingularity

-- | Total unification type
type TotalUnification = PerpetualSingularity

-- | Merge eternally
mergeEternally :: PerpetualSingularity
mergeEternally = PerpetualSingularity "oneness-001" True True