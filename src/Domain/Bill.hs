{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}

module Domain.Bill
  ( Bill (..),
    BillLine (..),
    BillFilter (..),
    calcBillLineAmount,
    calcBillTotal,
    validateBillLine,
    validateBill,
  )
where

import Core.Refined (clampNonNeg)
import Core.Tax (calcVAT)
import Data.Aeson (FromJSON, ToJSON)
import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (Day)
import GHC.Generics (Generic)
import Surypus.Types (fromDecimal, toDecimal)

{-@ type NonNegDouble = {v:Double | v >= 0} @-}
{-@ type VatRate = {v:Double | 0 <= v && v <= 100} @-}

{-@ data BillLine = BillLine
  { billLineId      :: Maybe Int64
  , billLineGoodsId :: Int64
  , billLinePrice   :: NonNegDouble
  , billLineQuantity:: NonNegDouble
  , billLineDiscount:: NonNegDouble
  , billLineVatRate :: VatRate
  , billLineTax     :: NonNegDouble
  , billLineAmount  :: NonNegDouble
  } @-}
data BillLine = BillLine
  { billLineId :: Maybe Int64,
    billLineGoodsId :: Int64,
    billLinePrice :: Double,
    billLineQuantity :: Double,
    billLineDiscount :: Double,
    billLineVatRate :: Double,
    billLineTax :: Double,
    billLineAmount :: Double
  }
  deriving (Eq, Show, Generic)

instance FromJSON BillLine

instance ToJSON BillLine

{-@ data Bill = Bill
  { billId        :: Maybe Int64
  , billCode      :: Maybe Text
  , billOpId      :: Int
  , billDate      :: Day
  , billPersonId  :: Maybe Int64
  , billLocationId:: Maybe Int64
  , billAmount    :: NonNegDouble
  , billVat       :: NonNegDouble
  , billDiscount  :: NonNegDouble
  , billStatus    :: Int
  , billCurrency  :: Maybe Int64
  , billCreatedBy :: Maybe Int64
  , billNotes     :: Maybe Text
  , billLines     :: [BillLine]
  } @-}
data Bill = Bill
  { billId :: Maybe Int64,
    billCode :: Maybe Text,
    billOpId :: Int,
    billDate :: Day,
    billPersonId :: Maybe Int64,
    billLocationId :: Maybe Int64,
    billAmount :: Double,
    billVat :: Double,
    billDiscount :: Double,
    billStatus :: Int,
    billCurrency :: Maybe Int64,
    billCreatedBy :: Maybe Int64,
    billNotes :: Maybe Text,
    billLines :: [BillLine]
  }
  deriving (Eq, Show, Generic)

instance FromJSON Bill

instance ToJSON Bill

{-@ data BillFilter = BillFilter
  { bfPersonId :: Maybe Int64
  , bfLocationId:: Maybe Int64
  , bfStatus   :: Maybe Int
  , bfLimit    :: Int
  , bfOffset   :: Int
  } @-}
data BillFilter = BillFilter
  { bfPersonId :: Maybe Int64,
    bfLocationId :: Maybe Int64,
    bfStatus :: Maybe Int,
    bfLimit :: Int,
    bfOffset :: Int
  }
  deriving (Eq, Show, Generic)

instance FromJSON BillFilter

instance ToJSON BillFilter

epsilon :: Double
epsilon = 1e-6

calcBillLineAmount :: BillLine -> Double
calcBillLineAmount BillLine {..} =
  clampNonNeg (billLineQuantity * billLinePrice - billLineDiscount + billLineTax)

calcBillTotal :: [BillLine] -> Double
calcBillTotal = sum . fmap calcBillLineAmount

calcLineNet :: BillLine -> Double
calcLineNet BillLine {..} = clampNonNeg (billLineQuantity * billLinePrice - billLineDiscount)

calcLineTaxExpected :: BillLine -> Double
calcLineTaxExpected line = fromDecimal $ calcVAT (toDecimal $ calcLineNet line) (toDecimal $ billLineVatRate line)

validateBillLine :: BillLine -> Either Text BillLine
validateBillLine line@BillLine {..}
  | billLinePrice < 0 = Left "price must be non-negative"
  | billLineQuantity < 0 = Left "quantity must be non-negative"
  | billLineDiscount < 0 = Left "discount must be non-negative"
  | billLineVatRate < 0 || billLineVatRate > 100 = Left "vat rate must be between 0 and 100"
  | billLineTax < 0 = Left "tax must be non-negative"
  | billLineAmount < 0 = Left "line amount must be non-negative"
  | abs (calcLineTaxExpected line - billLineTax) > epsilon = Left "line tax mismatch"
  | abs (calcBillLineAmount line - billLineAmount) > epsilon = Left "line amount mismatch"
  | otherwise = Right line

validateBill :: Bill -> Either Text Bill
validateBill bill@Bill {..}
  | billAmount < 0 = Left "bill amount must be non-negative"
  | billVat < 0 = Left "VAT must be non-negative"
  | billDiscount < 0 = Left "discount must be non-negative"
  | otherwise =
      case firstError (fmap validateBillLine billLines) of
        Just err -> Left err
        Nothing
          | abs (calcBillTotal billLines - billAmount) > epsilon -> Left "bill total mismatch"
          | otherwise -> Right bill
  where
    firstError = foldr go Nothing
    go (Left err) _ = Just err
    go (Right _) acc = acc
