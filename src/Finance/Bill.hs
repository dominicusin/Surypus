{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DeriveAnyClass #-}

-- | Bill posting business logic
module Finance.Bill
  ( Bill(..)
  , BillLine(..)
  , BillStatus(..)
  , BillPostingResult(..)
  , createBill
  , postBill
  , validateBill
  , calculateBillTotal
  ) where

import Data.Aeson (ToJSON, FromJSON)
import Data.Decimal (Decimal)
import Data.Text (Text)
import Data.Time (Day)
import GHC.Generics (Generic)

-- | Bill status
data BillStatus
  = BillDraft
  | BillPosted
  | BillCancelled
  deriving (Show, Eq, Generic, ToJSON, FromJSON)

-- | Bill line item
data BillLine = BillLine
  { billLineDescription :: Text
  , billLineQuantity   :: Decimal
  , billLineUnitPrice  :: Decimal
  , billLineTaxRate    :: Decimal
  } deriving (Show, Eq, Generic, ToJSON, FromJSON)

-- | Bill
data Bill = Bill
  { billId          :: !(Maybe Int)
  , billNumber      :: !Text
  , billStatus      :: !BillStatus
  , billDate        :: !Day
  , billCustomerName :: !Text
  , billLines       :: [BillLine]
  , billTotal       :: !Decimal
  , billTaxAmount   :: !Decimal
  } deriving (Show, Eq, Generic, ToJSON, FromJSON)

-- | Bill posting result
data BillPostingResult
  = BillPostedOk
  | BillValidationFailed !Text
  | BillAlreadyPosted
  deriving (Show, Eq)

-- | Create a new bill (draft)
createBill :: Text -> Day -> Text -> [BillLine] -> Bill
createBill number date customer lines =
  let (total, tax) = calculateBillTotal lines
  in Bill
       { billId = Nothing
       , billNumber = number
       , billStatus = BillDraft
       , billDate = date
       , billCustomerName = customer
       , billLines = lines
       , billTotal = total
       , billTaxAmount = tax
       }

-- | Validate bill before posting
validateBill :: Bill -> Either Text ()
validateBill bill
  | null (billLines bill) = Left "Bill must have at least one line"
  | billTotal bill < 0     = Left "Bill total cannot be negative"
  | otherwise              = Right ()

-- | Calculate total and tax for bill lines
calculateBillTotal :: [BillLine] -> (Decimal, Decimal)
calculateBillTotal lines =
  let subtotal = sum [billLineQuantity l * billLineUnitPrice l | l <- lines]
      tax      = sum [billLineQuantity l * billLineUnitPrice l * billLineTaxRate l / 100 | l <- lines]
  in (subtotal + tax, tax)

-- | Post a bill (transition from Draft to Posted)
postBill :: Bill -> BillPostingResult
postBill bill@(Bill { billStatus = BillPosted }) = BillAlreadyPosted
postBill bill = case validateBill bill of
  Left err  -> BillValidationFailed err
  Right ()  -> BillPostedOk
