-- | Ledger types - Accounting journal entries
module Core.Accounting.Ledger where

import Core.Accounting.Account (Account (..), AccountType (..))
import Data.Int (Int64)
import Data.Text (Text)

-- | AccTurn - Accounting entry (проводка)
data AccTurn = AccTurn
  { atId :: Int64,
    atBillId :: Maybe Int64, -- Linked bill ID
    atDbtAccId :: Int64, -- Debit account ID
    atCrdAccId :: Int64, -- Credit account ID
    atAmount :: Double, -- Amount (positive = debit, negative = credit)
    atCurrencyId :: Maybe Int64,
    atDate :: Int, -- Days since epoch
    atObjectId :: Maybe Int64, -- Object (contractor)
    atArticleId :: Maybe Int64,
    atMemo :: Maybe Text
  }
  deriving (Show, Eq)

-- | Ledger entry (expanded view)
data LedgerEntry = LedgerEntry
  { leId :: Int64,
    leBillId :: Int64,
    leDate :: Int,
    leAccount :: Account,
    leAmount :: Double,
    leDebit :: Double,
    leCredit :: Double,
    leObjectId :: Maybe Int64,
    leMemo :: Maybe Text
  }
  deriving (Show, Eq)

-- | AccSheet - Analytical register (аналитика)
data AccSheet = AccSheet
  { asId :: Int64,
    asCode :: Text,
    asName :: Text,
    asType :: AccSheetType
  }
  deriving (Show, Eq)

-- | AccSheet type
data AccSheetType
  = AstAgents -- Agents (контрагенты)
  | AstContracts -- Contracts (договоры)
  | AstProjects -- Projects (проекты)
  | AstOrders -- Orders (заказы)
  | AstEmployees -- Employees (сотрудники)
  deriving (Show, Eq, Enum)
