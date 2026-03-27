{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE MultiParamTypeClasses #-}

module Surypus.Types where

import Data.Aeson (FromJSON, ToJSON, parseJSON, toJSON, withScientific)
import Data.Int (Int64)
import Data.Text (Text)
import GHC.Generics (Generic)
import Test.QuickCheck

newtype Decimal = Decimal {unDecimal :: Integer}
  deriving (Eq, Generic, Ord)

instance Show Decimal where
  show (Decimal d) = show (fromInteger d / 100 :: Double)

instance Num Decimal where
  (Decimal a) + (Decimal b) = Decimal (a + b)
  (Decimal a) - (Decimal b) = Decimal (a - b)
  (Decimal a) * (Decimal b) = Decimal (div (a * b) 100)
  abs (Decimal d) = Decimal (abs d)
  signum (Decimal d) = Decimal (signum d)
  fromInteger i = Decimal (i * 100)

instance Real Decimal where
  toRational (Decimal d) = toRational d / 100

instance Fractional Decimal where
  (Decimal a) / (Decimal b) = Decimal (div (a * 10000) b)
  fromRational r = Decimal (round (r * 100))

decimalPlaces :: Int
decimalPlaces = 2

decimalScale :: Integer
decimalScale = 100

toDecimal :: Double -> Decimal
toDecimal d = Decimal (round (d * 100))

fromDecimal :: Decimal -> Double
fromDecimal (Decimal d) = fromInteger d / 100

instance ToJSON Decimal where
  toJSON (Decimal d) = toJSON (realToFrac d :: Double)

instance FromJSON Decimal where
  parseJSON = withScientific "Decimal" $ \n ->
    pure (Decimal (round ((realToFrac n :: Double) * 100) :: Integer))

newtype Money = Money {unMoney :: Decimal}
  deriving (Eq, Generic, Ord)

instance Show Money where
  show (Money d) = show d

instance Num Money where
  (Money a) + (Money b) = Money (a + b)
  (Money a) - (Money b) = Money (a - b)
  (Money a) * (Money b) = Money (a * b)
  abs (Money d) = Money (abs d)
  signum (Money d) = Money (signum d)
  fromInteger i = Money (fromInteger i)

instance Semigroup Money where
  (<>) = (+)

instance Monoid Money where
  mempty = Money 0

moneyFromInteger :: Int64 -> Money
moneyFromInteger i = Money (Decimal (toInteger i * 100))

moneyRound :: Money -> Money
moneyRound (Money d) = Money d

moneyFromDouble :: Double -> Money
moneyFromDouble = Money . toDecimal

toDouble :: Money -> Double
toDouble (Money d) = fromDecimal d

instance Arbitrary Decimal where
  arbitrary = Decimal <$> arbitrary

type NonNeg = Decimal

type NonNegMoney = Money

data AppError
  = ValidationError Text
  | NotFound Text
  | DatabaseError Text
  | AuthError Text
  | RateLimitError
  | InternalError Text
  deriving (Show, Eq, Generic)

type AppResult a = Either AppError a
