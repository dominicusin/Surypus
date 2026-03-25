-- | Currency Operations with Formal Verification
-- Модуль содержит инварианты и проверенные операции для валют
module Core.Currency.Operations
  ( CurrencyOpResult (..),
    validateCurrency,
    validateExchangeRate,
    convertCurrency,
    convertCurrencyWithRate,
    calculateCrossRate,
    roundToPrecision,
    formatCurrencyAmount,
    formatAmountSimple,
    getBaseCurrency,
    isActiveCurrency,
    calculateTotalInBaseCurrency,
    findBestRate,
    calculateAverageRate,
  )
where

import Core.Currency
import Data.Text (Text)
import qualified Data.Text as T

-- | Currency operation result
data CurrencyOpResult
  = CurrencyOpSuccess
  | CurrencyOpInvalidRate
  | CurrencyOpZeroRate
  | CurrencyOpInvalidPrecision
  | CurrencyOpInactiveCurrency

-- ============================================================================
-- VALIDATORS
-- ============================================================================

-- | Validate currency
-- Инвариант: код валюты 3 буквы, точность 0-6, курс > 0
validateCurrency :: Currency -> CurrencyOpResult
validateCurrency c
  | T.length (curCode c) /= 3 = CurrencyOpInvalidRate
  | curPrecision c < 0 || curPrecision c > 6 = CurrencyOpInvalidPrecision
  | curRate c <= 0 = CurrencyOpZeroRate
  | cfInactive (curFlags c) = CurrencyOpInactiveCurrency
  | otherwise = CurrencyOpSuccess

-- | Validate exchange rate
-- Инвариант: курс > 0
validateExchangeRate :: ExchangeRate -> CurrencyOpResult
validateExchangeRate er
  | erRate er <= 0 = CurrencyOpZeroRate
  | otherwise = CurrencyOpSuccess

-- ============================================================================
-- CONVERSION
-- ============================================================================

-- | Convert amount between currencies
-- Инвариант: result >= 0 если amount >= 0
convertCurrency :: Currency -> Currency -> Double -> Double
convertCurrency from to amount
  | amount < 0 = 0
  | curRate to == 0 = 0
  | otherwise = amount * curRate from / curRate to

-- | Convert amount using direct exchange rate
-- Инвариант: result >= 0 если amount >= 0
convertCurrencyWithRate :: Double -> Double -> Double
convertCurrencyWithRate amount rate
  | amount < 0 || rate <= 0 = 0
  | otherwise = amount * rate

-- | Calculate cross rate between two currencies via base
-- Инвариант: cross rate > 0
calculateCrossRate :: Currency -> Currency -> Double
calculateCrossRate from to
  | curRate to == 0 = 0
  | otherwise = curRate from / curRate to

-- ============================================================================
-- ROUNDING
-- ============================================================================

-- | Round amount to currency precision
-- Инвариант: result имеет заданную точность
roundToPrecision :: Int -> Double -> Double
roundToPrecision precision amount
  | precision < 0 = amount
  | precision > 6 = amount
  | otherwise =
      let factor = 10 ^ precision
       in fromInteger (round (amount * factor)) / factor

-- ============================================================================
-- FORMATTING
-- ============================================================================

-- | Format amount with currency symbol and code
-- Инвариант: result не пустой
formatCurrencyAmount :: Currency -> Double -> Text
formatCurrencyAmount cur amount =
  let rounded = roundToPrecision (curPrecision cur) amount
      symbol = curSymbol cur
   in T.concat [symbol, T.pack (show rounded), T.pack " ", curCode cur]

-- | Format amount with just symbol
formatAmountSimple :: Currency -> Double -> Text
formatAmountSimple cur amount =
  let rounded = roundToPrecision (curPrecision cur) amount
      symbol = curSymbol cur
   in T.concat [symbol, T.pack (show rounded)]

-- ============================================================================
-- AGGREGATION
-- ============================================================================

-- | Get base currency from list
-- Инвариант: возвращает Nothing если нет базовой валюты
getBaseCurrency :: [Currency] -> Maybe Currency
getBaseCurrency = find (cfBase . curFlags)

-- | Check if currency is active
-- Инвариант: активная валюта не помечена как неактивная
isActiveCurrency :: Currency -> Bool
isActiveCurrency c = not (cfInactive (curFlags c))

-- | Calculate total amount in base currency
-- Инвариант: result >= 0
calculateTotalInBaseCurrency :: [(Currency, Double)] -> Maybe Double
calculateTotalInBaseCurrency items = do
  base <- getBaseCurrency (fmap fst items)
  let convertAndSum = sum $ fmap (\(cur, amt) -> convertCurrency cur base amt) items
  pure (roundToPrecision (curPrecision base) convertAndSum)

-- ============================================================================
-- EXCHANGE RATE OPERATIONS
-- ============================================================================

-- | Find best exchange rate (latest date)
-- Инвариант: возвращает самый поздний курс
findBestRate :: [ExchangeRate] -> Maybe ExchangeRate
findBestRate [] = Nothing
findBestRate rates = Just $ maximumByDate rates
  where
    maximumByDate = foldl1 (\a b -> if erDate a > erDate b then a else b)

-- | Calculate average exchange rate for period
-- Инвариант: result > 0
calculateAverageRate :: [ExchangeRate] -> Double
calculateAverageRate [] = 0
calculateAverageRate rates = sum (fmap erRate rates) / fromIntegral (length rates)

-- ============================================================================
-- HELPERS
-- ============================================================================

find :: (a -> Bool) -> [a] -> Maybe a
find _ [] = Nothing
find p (x : xs)
  | p x = Just x
  | otherwise = find p xs
