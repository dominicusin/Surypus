-- | Account types - Chart of accounts
module Core.Accounting.Account where

import Data.Int (Int64)
import Data.Text (Text)

-- | Account type
data AccountType
  = ATAsset -- Активы (01-19)
  | ATLiability -- Пассивы (60-79)
  | ATEquity -- Капитал (80-89)
  | ATRevenue -- Доходы (90-99)
  | ATExpense -- Расходы (20-29, 44)
  deriving (Show, Eq, Enum)

-- | Account - Chart of accounts entry (счет)
data Account = Account
  { accId :: Int64,
    accCode :: Text, -- Account code (номер счета)
    accName :: Text, -- Account name (название)
    accType :: AccountType, -- Account type
    accParent :: Maybe Int64, -- Parent account ID
    accKind :: AccountKind,
    accFlags :: Int
  }
  deriving (Show, Eq)

-- | Account kind
data AccountKind
  = AKRegular -- Regular (обычный)
  | AKAnalytic -- Analytic (аналитический)
  | AKSubconto -- Subconto (субконто)
  | AKBank -- Bank (банк)
  | AKCash -- Cash (касса)
  | AKVAT -- VAT account
  deriving (Show, Eq, Enum)

-- | Account flags
data AccountFlags = AccountFlags
  { afInactive :: Bool, -- Inactive (не активен)
    afCurrency :: Bool, -- Currency account (валютный)
    objspec :: Bool -- Has objects (по объектам)
  }
  deriving (Show, Eq)
