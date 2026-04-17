-- | BankAccount module - Bank accounts
module Core.BankAccount where

import Data.Int (Int64)

-- | BankAccount - Bank account
data BankAccount = BankAccount
  { baId :: Int64,
    baBankId :: Int64,
    baNumber :: String,
    baType :: AccountType,
    baCurrencyId :: Int64,
    baBalance :: Double
  }
  deriving (Show, Eq)

data AccountType = ATChecking | ATSavings | ATCurrent
  deriving (Show, Eq)

-- | Mask account number
maskAccount :: BankAccount -> String
maskAccount ba = replicate 8 '*' <> drop (length (baNumber ba) - 4) (baNumber ba)
