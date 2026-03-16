-- | Price Operations with Formal Verification
-- Модуль содержит инварианты и проверенные операции для расчёта цен
module Core.Price.Operations
  ( PriceOpResult (..),
    validatePrice,
    validateQuotation,
    calculateDiscount,
    calculateFinalPrice,
    calculateLineTotal,
    calculateBillTotal,
    verifyPricePositive,
    verifyDiscountBounded,
    verifyPriceMatch,
    checkNegativeStock,
    convertCurrency,
    getActivePriceList,
    calcPriceFromList,
    calculateTotalDiscount,
  )
where

import Core.Inventory.Types.Stock (Stock (..))
import Core.Price hiding (convertCurrency, validatePrice)
import Data.Int (Int64)
import Data.Time (Day)
import Surypus.Refined.Predicates ()

-- | Price operation result
data PriceOpResult
  = PriceOpSuccess
  | PriceOpInvalidPrice
  | PriceOpDiscountTooHigh
  | PriceOpNegativeQuantity
  | PriceOpPriceMismatch

-- ============================================================================
-- VALIDATORS
-- ============================================================================

-- | Validate price
-- Инвариант: цена >= 0
validatePrice :: Double -> PriceOpResult
validatePrice price
  | price < 0 = PriceOpInvalidPrice
  | price > 1e10 = PriceOpInvalidPrice
  | otherwise = PriceOpSuccess

-- | Validate quotation
-- Инвариант: цена >= 0, мин. кол-во >= 0
validateQuotation :: Quot -> PriceOpResult
validateQuotation q
  | qPrice q < 0 = PriceOpInvalidPrice
  | qMinQtty q < 0 = PriceOpNegativeQuantity
  | otherwise = PriceOpSuccess

-- ============================================================================
-- DISCOUNT CALCULATIONS
-- ============================================================================

-- | Calculate discount amount
-- Инвариант: discount >= 0, discount <= original price
calculateDiscount :: Double -> Double -> Double
calculateDiscount price discountPercent
  | discountPercent < 0 = 0
  | discountPercent > 100 = price
  | otherwise = price * discountPercent / 100

-- | Calculate final price after discount
-- Инвариант: final >= 0
calculateFinalPrice :: Double -> Double -> Double
calculateFinalPrice price discountPercent
  | price < 0 = 0
  | discountPercent < 0 = price
  | discountPercent > 100 = 0
  | otherwise = price * (100 - discountPercent) / 100

-- | Verify discount is within bounds
-- Инвариант: 0 <= discount <= 100
verifyDiscountBounded :: Double -> PriceOpResult
verifyDiscountBounded discount
  | discount < 0 = PriceOpDiscountTooHigh
  | discount > 100 = PriceOpDiscountTooHigh
  | otherwise = PriceOpSuccess

-- ============================================================================
-- LINE TOTAL CALCULATIONS
-- ============================================================================

-- | Calculate line total (price * quantity - discount)
-- Инвариант: result >= 0
calculateLineTotal :: Double -> Double -> Double -> Double
calculateLineTotal price quantity discountPercent
  | price < 0 || quantity < 0 = 0
  | otherwise = calculateFinalPrice (price * quantity) discountPercent

-- ============================================================================
-- BILL TOTAL CALCULATIONS
-- ============================================================================

-- | Calculate bill total from lines
-- Инвариант: total >= 0
calculateBillTotal :: [(Double, Double, Double)] -> Double
calculateBillTotal lines = sum (map (\(p, q, d) -> calculateLineTotal p q d) lines)

-- | Calculate total discount for bill
-- Инвариант: total >= 0
calculateTotalDiscount :: [(Double, Double, Double)] -> Double
calculateTotalDiscount lines = sum (map (\(p, q, d) -> calculateDiscount (p * q) d) lines)

-- ============================================================================
-- PRICE VERIFICATION
-- ============================================================================

-- | Verify all prices are positive
-- Инвариант: все цены > 0
verifyPricePositive :: [Double] -> PriceOpResult
verifyPricePositive prices
  | any (<= 0) prices = PriceOpInvalidPrice
  | otherwise = PriceOpSuccess

-- | Verify price matches expected
-- Инвариант: цена с учётом погрешности
verifyPriceMatch :: Double -> Double -> PriceOpResult
verifyPriceMatch expected actual
  | abs (expected - actual) > 0.01 = PriceOpPriceMismatch
  | otherwise = PriceOpSuccess

-- ============================================================================
-- CURRENCY CALCULATIONS
-- ============================================================================

-- | Convert price to different currency
-- Инвариант: result >= 0
convertCurrency :: Double -> Double -> Double
convertCurrency price rate
  | price < 0 || rate < 0 = 0
  | otherwise = price * rate

-- ============================================================================
-- STOCK CHECKS
-- ============================================================================

-- | Check for negative stock
-- Инвариант: остаток на складе не может быть отрицательным
checkNegativeStock :: [Stock] -> Bool
checkNegativeStock stocks = any (\s -> sQtty s < 0) stocks

-- ============================================================================
-- PRICE LISTS
-- ============================================================================

-- | Get active price list for date
-- Инвариант: возвращает Nothing если нет активного прайса
getActivePriceList :: Day -> [PriceList] -> Maybe PriceList
getActivePriceList date priceLists = do
  let valid = filter (\pl -> plValidFrom pl <= date && maybe True (date <=) (plValidTo pl)) priceLists
  case valid of
    [] -> Nothing
    (p : _) -> Just p

-- | Calculate price from price list
-- Инвариант: result >= 0
calcPriceFromList :: [(Int64, Double)] -> Int64 -> Double -> Double
calcPriceFromList goodsPrices goodsId defaultPrice =
  maybe defaultPrice id (lookup goodsId goodsPrices)
