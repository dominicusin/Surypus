{-# LANGUAGE OverloadedStrings #-}
module AbsoluteFulfillmentPt2.AbsoluteFulfillmentPt2
  ( TotalSatisfaction(..)
  , CompletePurpose
  , UltimateDestiny
  , realizeAbsoluteFulfillment
  ) where

import Data.Text (Text)

-- | Absolute fulfillment type
data TotalSatisfaction = TotalSatisfaction
  { tsId :: Text
  , tsIsTotal :: Bool
  , tsIsUltimate :: Bool
  } deriving (Eq, Show)

-- | Complete purpose type
type CompletePurpose = TotalSatisfaction

-- | Ultimate destiny type
type UltimateDestiny = TotalSatisfaction

-- | Realize absolute fulfillment
realizeAbsoluteFulfillment :: TotalSatisfaction
realizeAbsoluteFulfillment = TotalSatisfaction "absolutefulfillment-001" True True