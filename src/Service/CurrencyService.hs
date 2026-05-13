module Service.CurrencyService where
import Data.Text (Text)
import Data.Map.Strict (Map)
import Data.Time (UTCTime)
import Data.Int (Int64)

data CurrencyService = CurrencyService
  { exchangeRates :: Map (Text, Text) Double
  , baseCurrency :: Text
  , lastUpdated :: UTCTime
  } deriving (Show, Eq)

emptyCurrencyService :: Text -> UTCTime -> CurrencyService
emptyCurrencyService base now =
  CurrencyService { exchangeRates = Map.empty, baseCurrency = base, lastUpdated = now }

convert :: CurrencyService -> Text -> Text -> Double -> Either Text Double
convert service from to amount
  | from == to = Right amount
  | otherwise = case Map.lookup (from, to) (exchangeRates service) of
                  Just rate -> Right (amount * rate)
                  Nothing -> Left $ "Exchange rate not found for " <> from <> " to " <> to

updateExchangeRates :: CurrencyService -> Map (Text, Text) Double -> UTCTime -> CurrencyService
updateExchangeRates service newRates now =
  service { exchangeRates = newRates, lastUpdated = now }

setBaseCurrency :: CurrencyService -> Text -> CurrencyService
setBaseCurrency service base = service { baseCurrency = base }

getBaseCurrency :: CurrencyService -> Text
getBaseCurrency = baseCurrency

getLastUpdated :: CurrencyService -> UTCTime
getLastUpdated = lastUpdated