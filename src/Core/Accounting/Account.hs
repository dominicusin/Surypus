-- | Account types - Chart of accounts
module Core.Accounting.Account where

import Data.Int (Int64)
import Data.Text (Text)

-- | Account type
data AccountType
  = Asset -- Активы (01-19)
  | Liability -- Пассивы (60-79)
  | Equity -- Капитал (80-89)
  | Revenue -- Доходы (90-99)
  | Expense -- Расходы (20-29, 44)
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
  = AK_Regular -- Regular (обычный)
  | AK_Analytic -- Analytic (аналитический)
  | AK_Subconto -- Subconto (субконто)
  | AK_Bank -- Bank (банк)
  | AK_Cash -- Cash (касса)
  | AK_VAT -- VAT account
  deriving (Show, Eq, Enum)

-- | Account flags
data AccountFlags = AccountFlags
  { afInactive :: Bool, -- Inactive (не активен)
    afCurrency :: Bool, -- Currency account (валютный)
    objspec :: Bool -- Has objects (по объектам)
  }
  deriving (Show, Eq)
