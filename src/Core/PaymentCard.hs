-- | PaymentCard module - Payment cards
module Core.PaymentCard where

import           Data.Int (Int64)

-- | PaymentCard - Payment card
data PaymentCard = PaymentCard
  { pcId       :: Int64
  , pcNumber   :: String
  , pcHolderId :: Int64
  , pcExpiry   :: String
  , pcType     :: CardType
  } deriving (Show, Eq)

data CardType = CT_Visa | CT_MasterCard | CT_MIR | CT_Amex
  deriving (Show, Eq)

-- | Mask card number
maskCard :: PaymentCard -> String
maskCard pc = replicate 12 '*' ++ drop 12 (pcNumber pc)
