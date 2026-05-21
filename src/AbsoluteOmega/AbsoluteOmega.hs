{-# LANGUAGE OverloadedStrings #-}
module AbsoluteOmega.AbsoluteOmega
  ( UltimateCessation(..)
  , FinalTermination
  , AbsoluteEnding
  , completeAbsoluteOmega
  ) where

import Data.Text (Text)

-- | Absolute omega type
data UltimateCessation = UltimateCessation
  { ucId :: Text
  , ucIsUltimate :: Bool
  , ucIsAbsolute :: Bool
  } deriving (Eq, Show)

-- | Final termination type
type FinalTermination = UltimateCessation

-- | Absolute ending type
type AbsoluteEnding = UltimateCessation

-- | Complete absolute omega
completeAbsoluteOmega :: UltimateCessation
completeAbsoluteOmega = UltimateCessation "absoluteomega-001" True True