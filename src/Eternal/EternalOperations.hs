{-# LANGUAGE OverloadedStrings #-}
module Eternal.EternalOperations
  ( EternalState(..)
  , TimeIndependent
  , PerpetualManager
  , runEternally
  ) where

import Data.Text (Text)
import Data.Aeson (Value)

-- | Eternal state type
data EternalState = EternalState
  { esId :: Text
  , esTimeless :: Bool
  , esPerpetual :: Bool
  } deriving (Eq, Show)

-- | Time-independent computation
type TimeIndependent = Value -> IO Value

-- | Perpetual state manager
type PerpetualManager = EternalState

-- | Run eternally
runEternally :: TimeIndependent
runEternally input = return input