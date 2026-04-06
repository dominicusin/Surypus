-- | Core Types for Surypus ERP
--
-- This module provides the fundamental numeric types used throughout
-- the system, particularly for monetary calculations.
--
-- = Decimal Type
--
-- The 'Decimal' type represents fixed-point decimal numbers with
-- 2 decimal places (stored as Int64 multiplied by 100).
--
-- This design choice provides:
--
-- * Exact arithmetic for monetary values (no floating-point errors)
-- * Efficient storage and comparison
-- * Easy serialization to JSON
module Surypus.Types
  ( Decimal (..),
    fromDecimal,
    toDecimal,
  )
where

import Data.Aeson (FromJSON (..), ToJSON (..))
import Data.Int (Int64)
import Test.QuickCheck

-- | Fixed-point decimal with 2 decimal places
--
-- Internally stored as 'Int64' where the value represents cents.
-- For example, @Decimal 1234@ represents @12.34@.
newtype Decimal = Decimal {unDecimal :: Int64}
  deriving (Eq, Ord, Show)

instance Num Decimal where
  Decimal a + Decimal b = Decimal (a + b)
  Decimal a - Decimal b = Decimal (a - b)
  Decimal a * Decimal b = Decimal (a * b `div` 100)
  negate (Decimal a) = Decimal (negate a)
  abs (Decimal a) = Decimal (abs a)
  signum (Decimal a) = Decimal (signum a * 100)
  fromInteger i = Decimal (fromInteger i * 100)

instance Fractional Decimal where
  Decimal a / Decimal b = Decimal (div (a * 10000) b)
  fromRational r = Decimal (round (r * 100) :: Int64)

instance Arbitrary Decimal where
  arbitrary = Decimal <$> arbitrary

-- | Convert Decimal to 'Double'
--
-- Example: @fromDecimal (Decimal 1234) = 12.34@
fromDecimal :: Decimal -> Double
fromDecimal (Decimal a) = fromIntegral a / 100.0

-- | Convert 'Double' to Decimal
--
-- Example: @toDecimal 12.34 = Decimal 1234@
--
-- Note: Uses rounding, so @toDecimal 12.345 = Decimal 1235@
toDecimal :: Double -> Decimal
toDecimal d = Decimal (round (d * 100))

instance ToJSON Decimal where
  toJSON (Decimal a) = toJSON (fromIntegral a / 100.0 :: Double)

instance FromJSON Decimal where
  parseJSON v = do
    d <- parseJSON v
    pure (Decimal (round (d * 100 :: Double) :: Int64))
