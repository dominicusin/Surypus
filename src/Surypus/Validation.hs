{-# LANGUAGE OverloadedStrings #-}

-- | Validation Framework for Surypus ERP
--
-- This module provides a comprehensive validation framework with:
--
-- * Generic validators for fields and compositions
-- * Domain-specific validators for all entities
-- * INN/KPP validation (Russian tax numbers)
-- * Phone number validation
--
-- = Usage
--
-- @
-- case validatePersonInput personInput of
--   Left errors -> handleErrors errors
--   Right validated -> proceedWith validated
-- @
module Surypus.Validation
  ( ValidationError (..),
    Validator,
    validate,
    validateField,
    combineValidators,
    isValidINN,
    isValidKPP,
    isValidPhone,
    validatePersonInput,
    validateGoodsInput,
    validateBillInput,
    validateLocationInput,
    validateOrderInput,
    validatePaymentInput,
    validatePriceInput,
    validateTaxInput,
    validateCurrencyInput,
    validateAccPlanInput,
    validateAccTurnInput,
  )
where

import DAL.Types
import Data.Text (Text)
import qualified Data.Text as T

-- | Validation error with descriptive message
newtype ValidationError = ValidationError Text
  deriving (Show, Eq)

-- | Validator function type - returns either errors or validated value
type Validator a = a -> Either [ValidationError] a

-- | Apply a validator to a value
validate :: Validator a -> a -> Either [ValidationError] a
validate = ($)

-- | Validate a single field with a predicate
validateField :: Text -> (a -> Bool) -> Validator a
validateField name predicate value =
  if predicate value
    then Right value
    else Left [ValidationError $ "Invalid " <> name]

-- | Combine two validators (both must pass)
combineValidators :: Validator a -> Validator a -> Validator a
combineValidators v1 v2 a = case v1 a of
  Left errs1 -> case v2 a of
    Left errs2 -> Left (errs1 <> errs2)
    Right _ -> Left errs1
  Right _ -> v2 a

-- | Validate INN (Russian tax identification number)
--
-- Valid INN lengths:
-- * 10 digits for individuals
-- * 12 digits for legal entities
isValidINN :: Text -> Bool
isValidINN inn =
  let digits = T.filter (`elem` ['0' .. '9']) inn
      len = T.length digits
   in len == 10 || len == 12

-- | Validate KPP (Russian registration reason code)
--
-- KPP is always 9 digits
isValidKPP :: Text -> Bool
isValidKPP kpp = T.length kpp == 9

-- | Validate phone number
--
-- Valid phone must have at least 10 digits
isValidPhone :: Text -> Bool
isValidPhone phone =
  let digits = filter (`elem` ['0' .. '9']) (T.unpack phone)
   in length digits >= 10

-- | Validate PersonInput
--
-- Checks:
-- * Name is required (1-255 characters)
-- * INN format is valid (10 or 12 digits)
-- * KPP format is valid (9 digits)
-- * Person type is valid (>= 0)
-- * Status is valid (>= 0)
validatePersonInput :: Validator PersonInput
validatePersonInput input
  | T.length (piName input) < 1 = Left [ValidationError "Name is required"]
  | T.length (piName input) > 255 = Left [ValidationError "Name too long"]
  | not (any isValidINN (piINN input)) = Left [ValidationError "Invalid INN format"]
  | not (any isValidKPP (piKPP input)) = Left [ValidationError "Invalid KPP format"]
  | piPersonType input < 0 = Left [ValidationError "Invalid person type"]
  | piStatus input < 0 = Left [ValidationError "Invalid status"]
  | otherwise = Right input

-- | Validate GoodsInput
--
-- Checks:
-- * Name is required (1-255 characters)
-- * Unit ID is required (> 0)
validateGoodsInput :: Validator GoodsInput
validateGoodsInput input
  | T.length (giName input) < 1 = Left [ValidationError "Name is required"]
  | T.length (giName input) > 255 = Left [ValidationError "Name too long"]
  | giUnitId input <= 0 = Left [ValidationError "Unit is required"]
  | otherwise = Right input

-- | Validate BillInput
--
-- Checks:
-- * Type is valid (>= 0)
-- * Status is valid (>= 0)
-- * Total, discount, tax cannot be negative
validateBillInput :: Validator BillInput
validateBillInput input
  | biType input < 0 = Left [ValidationError "Invalid bill type"]
  | biStatus input < 0 = Left [ValidationError "Invalid status"]
  | biTotal input < 0 = Left [ValidationError "Total cannot be negative"]
  | biDiscount input < 0 = Left [ValidationError "Discount cannot be negative"]
  | biTax input < 0 = Left [ValidationError "Tax cannot be negative"]
  | otherwise = Right input

-- | Validate LocationInput
--
-- Checks:
-- * Name is required (1-255 characters)
-- * Location type is valid (>= 0)
validateLocationInput :: Validator LocationInput
validateLocationInput input
  | T.length (liName input) < 1 = Left [ValidationError "Name is required"]
  | T.length (liName input) > 255 = Left [ValidationError "Name too long"]
  | liType input < 0 = Left [ValidationError "Invalid location type"]
  | otherwise = Right input

-- | Validate OrderInput
--
-- Checks:
-- * Status is valid (>= 0)
-- * Total, discount, tax cannot be negative
validateOrderInput :: Validator OrderInput
validateOrderInput input
  | oiStatus input < 0 = Left [ValidationError "Invalid status"]
  | oiTotal input < 0 = Left [ValidationError "Total cannot be negative"]
  | oiDiscount input < 0 = Left [ValidationError "Discount cannot be negative"]
  | oiTax input < 0 = Left [ValidationError "Tax cannot be negative"]
  | otherwise = Right input

-- | Validate PaymentInput
--
-- Checks:
-- * Bill ID is required (> 0)
-- * Amount must be positive (> 0)
-- * Payment method is valid (>= 0)
-- * Payment status is valid (>= 0)
validatePaymentInput :: Validator PaymentInput
validatePaymentInput input
  | piBillId input <= 0 = Left [ValidationError "Bill ID is required"]
  | piAmount input <= 0 = Left [ValidationError "Amount must be positive"]
  | piPayMethod input < 0 = Left [ValidationError "Invalid payment method"]
  | piPayStatus input < 0 = Left [ValidationError "Invalid payment status"]
  | otherwise = Right input

-- | Validate PriceInput
--
-- Checks:
-- * Goods ID is required (> 0)
-- * Price type is valid (>= 0)
-- * Price cannot be negative
-- * Currency ID is required (> 0)
validatePriceInput :: Validator PriceInput
validatePriceInput input
  | priGoodsId input <= 0 = Left [ValidationError "Goods ID is required"]
  | priPriceType input < 0 = Left [ValidationError "Invalid price type"]
  | priPrice input < 0 = Left [ValidationError "Price cannot be negative"]
  | priCurrencyId input <= 0 = Left [ValidationError "Currency is required"]
  | otherwise = Right input

-- | Validate TaxInput
--
-- Checks:
-- * Name is required (>= 1 character)
-- * Rate is valid (0-100%)
-- * Tax type is valid (>= 0)
validateTaxInput :: Validator TaxInput
validateTaxInput input
  | T.length (tiName input) < 1 = Left [ValidationError "Name is required"]
  | tiRate input < 0 = Left [ValidationError "Rate cannot be negative"]
  | tiRate input > 100 = Left [ValidationError "Rate cannot exceed 100%"]
  | tiTaxType input < 0 = Left [ValidationError "Invalid tax type"]
  | otherwise = Right input

-- | Validate CurrencyInput
--
-- Checks:
-- * Code is exactly 3 characters
-- * Name is required (>= 1 character)
-- * Symbol is required (>= 1 character)
-- * Rate must be positive (> 0)
validateCurrencyInput :: Validator CurrencyInput
validateCurrencyInput input
  | T.length (ciCode input) /= 3 = Left [ValidationError "Currency code must be 3 characters"]
  | T.length (ciName input) < 1 = Left [ValidationError "Name is required"]
  | T.length (ciSymbol input) < 1 = Left [ValidationError "Symbol is required"]
  | ciRate input <= 0 = Left [ValidationError "Rate must be positive"]
  | otherwise = Right input

-- | Validate AccPlanInput
--
-- Checks:
-- * Code is required (>= 1 character)
-- * Name is required (>= 1 character)
-- * Type is valid (0-4)
-- * Kind is valid (>= 0)
validateAccPlanInput :: Validator AccPlanInput
validateAccPlanInput input
  | T.length (apiCode input) < 1 = Left [ValidationError "Code is required"]
  | T.length (apiName input) < 1 = Left [ValidationError "Name is required"]
  | apiType input < 0 || apiType input > 4 = Left [ValidationError "Type must be 0-4"]
  | apiKind input < 0 = Left [ValidationError "Kind must be non-negative"]
  | otherwise = Right input

-- | Validate AccTurnInput
--
-- Checks:
-- * Debit account ID is positive (> 0)
-- * Credit account ID is positive (> 0)
-- * Amount is positive (> 0)
validateAccTurnInput :: Validator AccTurnInput
validateAccTurnInput input
  | atiDbtAccId input <= 0 = Left [ValidationError "Debit account ID must be positive"]
  | atiCrdAccId input <= 0 = Left [ValidationError "Credit account ID must be positive"]
  | atiAmount input <= 0 = Left [ValidationError "Amount must be positive"]
  | otherwise = Right input
