{-# LANGUAGE OverloadedStrings #-}
module Universe.AbsoluteUniverse
  ( AbsoluteCosmos(..)
  , TotalExistence
  , CompleteReality
  , embodyUniverse
  ) where

import Data.Text (Text)

-- | Absolute universe type
data AbsoluteCosmos = AbsoluteCosmos
  { acId :: Text
  , acIsTotal :: Bool
  , acIsComplete :: Bool
  } deriving (Eq, Show)

-- | Total existence type
type TotalExistence = AbsoluteCosmos

-- | Complete reality type
type CompleteReality = AbsoluteCosmos

-- | Embody absolute universe
embodyUniverse :: TotalExistence
embodyUniverse = AbsoluteCosmos "universe-001" True True