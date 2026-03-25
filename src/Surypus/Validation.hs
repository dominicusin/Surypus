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
  )
where

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
