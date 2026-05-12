-- | Surypus core types
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
module Surypus.Types
  ( Decimal,
    unDecimal
  ) where

import Prelude hiding (div)

newtype Decimal = Decimal Double
  deriving (Show, Eq, Num, Ord, Fractional)

unDecimal :: Decimal -> Double
unDecimal (Decimal d) = d

div :: Double -> Double -> Double
div = (/)