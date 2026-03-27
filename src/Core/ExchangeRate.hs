-- | ExchangeRate module - Exchange rates
module Core.ExchangeRate where

import Data.Int (Int64)
import Data.Time (Day)

-- | ExchangeRate - Exchange rate
data ExchangeRate = ExchangeRate
  { erId :: Int64,
    erFromCurId :: Int64,
    erToCurId :: Int64,
    erRate :: Double,
    erDate :: Day
  }
  deriving (Show, Eq)

-- | Get rate for date
getRateForDate :: [ExchangeRate] -> Day -> Maybe Double
getRateForDate rates date =
  case filter (\r -> erDate r == date) rates of
    (r : _) -> Just (erRate r)
    [] -> Nothing
