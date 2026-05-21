{-# LANGUAGE OverloadedStrings #-}
module Genesis.PrimordialCode
  ( PrimordialLogic(..)
  , OriginAlgorithm
  , PreExistence
  , generatePrimordial
  ) where

import Data.Text (Text)
import Data.Aeson (Value)

-- | Primordial logic type
data PrimordialLogic = PrimordialLogic
  { plId :: Text
  , plIsOrigin :: Bool
  , plIsInfinite :: Bool
  } deriving (Eq, Show)

-- | Origin algorithm type
type OriginAlgorithm = Value -> Value

-- | Pre-existence type
type PreExistence = PrimordialLogic

-- | Generate primordial code
generatePrimordial :: PreExistence
generatePrimordial = PrimordialLogic "primordial-001" True True