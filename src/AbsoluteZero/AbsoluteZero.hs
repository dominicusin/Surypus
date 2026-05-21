{-# LANGUAGE OverloadedStrings #-}
module AbsoluteZero.AbsoluteZero
  ( ZeroPoint(..)
  , AbsoluteStillness
  , PerfectSilence
  , achieveZero
  ) where

import Data.Text (Text)
import Data.Aeson (Value)

-- | Zero point type
data ZeroPoint = ZeroPoint
  { zpId :: Text
  , zpEnergy :: Double
  , zpIsZero :: Bool
  } deriving (Eq, Show)

-- | Absolute stillness type
type AbsoluteStillness = Value -> IO Value

-- | Perfect silence type
type PerfectSilence = ZeroPoint

-- | Achieve absolute zero
achieveZero :: PerfectSilence
achieveZero = ZeroPoint "zero-001" 0.0 True