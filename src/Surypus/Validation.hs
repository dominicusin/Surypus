{-# LANGUAGE OverloadedStrings #-}

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
  )
where

import DAL.Types
import Data.Text (Text)
import qualified Data.Text as T

newtype ValidationError = ValidationError Text
  deriving (Show, Eq)

type Validator a = a -> Either [ValidationError] a

validate :: Validator a -> a -> Either [ValidationError] a
validate = ($)

validateField :: Text -> (a -> Bool) -> Validator a
validateField name predicate value =
  if predicate value
    then Right value
    else Left [ValidationError $ "Invalid " <> name]

combineValidators :: Validator a -> Validator a -> Validator a
combineValidators v1 v2 a = case v1 a of
  Left errs1 -> case v2 a of
    Left errs2 -> Left (errs1 <> errs2)
    Right _ -> Left errs1
  Right _ -> v2 a

isValidINN :: Text -> Bool
isValidINN inn =
  let digits = T.filter (`elem` ['0' .. '9']) inn
      len = T.length digits
   in len == 10 || len == 12

isValidKPP :: Text -> Bool
isValidKPP kpp = T.length kpp == 9

isValidPhone :: Text -> Bool
isValidPhone phone =
  let digits = filter (`elem` ['0' .. '9']) (T.unpack phone)
   in length digits >= 10

-- | Validate PersonInput
validatePersonInput :: Validator PersonInput
validatePersonInput input
  | T.length (piName input) < 1 = Left [ValidationError "Name is required"]
  | T.length (piName input) > 255 = Left [ValidationError "Name too long"]
  | maybe True (not . isValidINN) (piINN input) = Left [ValidationError "Invalid INN format"]
  | maybe True (not . isValidKPP) (piKPP input) = Left [ValidationError "Invalid KPP format"]
  | piPersonType input < 0 = Left [ValidationError "Invalid person type"]
  | piStatus input < 0 = Left [ValidationError "Invalid status"]
  | otherwise = Right input

-- | Validate GoodsInput
validateGoodsInput :: Validator GoodsInput
validateGoodsInput input
  | T.length (giName input) < 1 = Left [ValidationError "Name is required"]
  | T.length (giName input) > 255 = Left [ValidationError "Name too long"]
  | giUnitId input <= 0 = Left [ValidationError "Unit is required"]
  | otherwise = Right input

-- | Validate BillInput
validateBillInput :: Validator BillInput
validateBillInput input
  | biType input < 0 = Left [ValidationError "Invalid bill type"]
  | biStatus input < 0 = Left [ValidationError "Invalid status"]
  | biTotal input < 0 = Left [ValidationError "Total cannot be negative"]
  | biDiscount input < 0 = Left [ValidationError "Discount cannot be negative"]
  | biTax input < 0 = Left [ValidationError "Tax cannot be negative"]
  | otherwise = Right input

-- | Validate LocationInput
validateLocationInput :: Validator LocationInput
validateLocationInput input
  | T.length (liName input) < 1 = Left [ValidationError "Name is required"]
  | T.length (liName input) > 255 = Left [ValidationError "Name too long"]
  | liType input < 0 = Left [ValidationError "Invalid location type"]
  | otherwise = Right input

-- | Validate OrderInput
validateOrderInput :: Validator OrderInput
validateOrderInput input
  | oiStatus input < 0 = Left [ValidationError "Invalid status"]
  | oiTotal input < 0 = Left [ValidationError "Total cannot be negative"]
  | oiDiscount input < 0 = Left [ValidationError "Discount cannot be negative"]
  | oiTax input < 0 = Left [ValidationError "Tax cannot be negative"]
  | otherwise = Right input

-- | Validate PaymentInput
validatePaymentInput :: Validator PaymentInput
validatePaymentInput input
  | piBillId input <= 0 = Left [ValidationError "Bill ID is required"]
  | piAmount input <= 0 = Left [ValidationError "Amount must be positive"]
  | piPayMethod input < 0 = Left [ValidationError "Invalid payment method"]
  | piPayStatus input < 0 = Left [ValidationError "Invalid payment status"]
  | otherwise = Right input

-- | Validate PriceInput
validatePriceInput :: Validator PriceInput
validatePriceInput input
  | priGoodsId input <= 0 = Left [ValidationError "Goods ID is required"]
  | priPriceType input < 0 = Left [ValidationError "Invalid price type"]
  | priPrice input < 0 = Left [ValidationError "Price cannot be negative"]
  | priCurrencyId input <= 0 = Left [ValidationError "Currency is required"]
  | otherwise = Right input

-- | Validate TaxInput
validateTaxInput :: Validator TaxInput
validateTaxInput input
  | T.length (tiName input) < 1 = Left [ValidationError "Name is required"]
  | tiRate input < 0 = Left [ValidationError "Rate cannot be negative"]
  | tiRate input > 100 = Left [ValidationError "Rate cannot exceed 100%"]
  | tiTaxType input < 0 = Left [ValidationError "Invalid tax type"]
  | otherwise = Right input

-- | Validate CurrencyInput
validateCurrencyInput :: Validator CurrencyInput
validateCurrencyInput input
  | T.length (ciCode input) /= 3 = Left [ValidationError "Currency code must be 3 characters"]
  | T.length (ciName input) < 1 = Left [ValidationError "Name is required"]
  | T.length (ciSymbol input) < 1 = Left [ValidationError "Symbol is required"]
  | ciRate input <= 0 = Left [ValidationError "Rate must be positive"]
  | otherwise = Right input
