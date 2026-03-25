{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeFamilies #-}

-- | Accounting Types - Account, Ledger, Transactions
module Core.Accounting.Types where

import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (Day)

-- ============================================================================
-- ACCOUNT TYPES (from account.cpp)
-- ============================================================================

-- | Account
data Account = Account
  { aId :: Int64,
    aCode :: Text,
    aName :: Text,
    aType :: AccountType,
    aKind :: AccountKind,
    aParentId :: Int64,
    aCurId :: Int64,
    aFlags :: Int,
    aBalance :: Double,
    aTurns :: Int
  }
  deriving (Show, Eq)

data AccountType = AT_Asset | AT_Liability | AT_Equity | AT_Revenue | AT_Expense
  deriving (Show, Eq)

data AccountKind = AK_Active | AK_Passive | AK_Auxiliary | AK_OffBalance
  deriving (Show, Eq)

-- | Article (sub-account)
data Article = Article
  { arId :: Int64,
    arCode :: Text,
    arName :: Text,
    arAcctId :: Int64,
    arObjId :: Int64,
    arFlags :: Int
  }
  deriving (Show, Eq)

-- ============================================================================
-- ACCOUNTING TRANSACTIONS (from accturn.cpp)
-- ============================================================================

-- | Accounting turn
data AccTurn = AccTurn
  { atId :: Int64,
    atAcctId :: Int64,
    atArId :: Int64,
    atDate :: Day,
    atAmount :: Double,
    atCurId :: Int64,
    atCurRate :: Double,
    atFlags :: Int,
    atBillId :: Int64,
    atCorrId :: Int64,
    atDbtAmt :: Double,
    atCrdAmt :: Double
  }
  deriving (Show, Eq)

-- | Accrued expenses/revenue
data Accrual = Accrual
  { acId :: Int64,
    acAcctId :: Int64,
    acArId :: Int64,
    acAmount :: Double,
    acDate :: Day,
    acFlags :: Int
  }
  deriving (Show, Eq)

-- ============================================================================
-- BALANCE TYPES
-- ============================================================================

-- | Balance
data Balance = Balance
  { bAcctId :: Int64,
    bDebit :: Double,
    bCredit :: Double,
    bBalance :: Double
  }
  deriving (Show, Eq)

-- | Account plan (chart of accounts)
data AccountPlan = AccountPlan
  { apId :: Int64,
    apName :: Text,
    apDate :: Day,
    apStatus :: PlanStatus,
    apAccounts :: [Account]
  }
  deriving (Show, Eq)

data PlanStatus = PS_Draft | PS_Active | PS_Closed
  deriving (Show, Eq)

-- ============================================================================
-- VALIDATORS
-- ============================================================================

-- | Validate account
validateAccount :: Account -> Bool
validateAccount a =
  aId a >= 0
    && aParentId a >= 0
    && aBalance a >= 0
    && aTurns a >= 0

-- | Validate accounting turn
validateAccTurn :: AccTurn -> Bool
validateAccTurn t =
  atId t >= 0
    && atAcctId t > 0
    && atAmount t >= 0
    && atCurRate t > 0
    && (atDbtAmt t >= 0)
    && (atCrdAmt t >= 0)
    && ((atDbtAmt t > 0) /= (atCrdAmt t > 0))

-- | Validate balance
validateBalance :: Balance -> Bool
validateBalance b =
  bAcctId b >= 0
    && bDebit b >= 0
    && bCredit b >= 0

-- ============================================================================
-- ACCOUNTING INVARIANTS
-- ============================================================================

-- | Double entry balance
doubleEntryBalance :: [AccTurn] -> Bool
doubleEntryBalance turns =
  let totalDebit = sum (map atDbtAmt turns)
      totalCredit = sum (map atCrdAmt turns)
   in totalDebit == totalCredit

-- | Account balance invariant
accountBalanceInvariant :: Account -> [AccTurn] -> Bool
accountBalanceInvariant acc turns =
  let acctTurns = filter (\t -> atAcctId t == aId acc) turns
      debitSum = sum (map atDbtAmt acctTurns)
      creditSum = sum (map atCrdAmt acctTurns)
      calcBalance = case aType acc of
        AT_Asset -> debitSum - creditSum
        AT_Liability -> creditSum - debitSum
        AT_Equity -> creditSum - debitSum
        AT_Revenue -> creditSum - debitSum
        AT_Expense -> debitSum - creditSum
   in abs (calcBalance - aBalance acc) < 0.01

-- | Trial balance
trialBalance :: [Balance] -> Double
trialBalance balances =
  let totalDebit = sum (map bDebit balances)
      totalCredit = sum (map bCredit balances)
   in abs (totalDebit - totalCredit)

-- | Trial balance zero
trialBalanceZero :: [Balance] -> Bool
trialBalanceZero balances = trialBalance balances < 0.01
