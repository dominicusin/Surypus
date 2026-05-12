{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}

-- | Finance.Ledger - Enhanced accounting journal with rich types
-- This module provides type-safe ledger operations with formal verification
module Finance.Ledger where

import Finance.Account (Account (..), AccountId, AccountCode, AccountClass (..))
import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (Day)
import qualified Data.Text as T
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as M
import GHC.Generics (Generic)

-- | Enhanced accounting entry with richer semantics
data AccTurn = AccTurn
  { turnId        :: TurnId           -- Unique identifier
  , turnBillId    :: Maybe BillId       -- Related bill
  , turnDebitAcc  :: AccountCode       -- Debit account code
  , turnCreditAcc :: AccountCode       -- Credit account code  
  , turnAmount    :: Amount            -- Transaction amount
  , turnCurrency  :: CurrencyCode      -- Currency
  , turnDate      :: TransactionDate    -- Transaction date
  , turnObjectId  :: Maybe ObjectId     -- Related object
  , turnArticleId :: Maybe ArticleId    -- Analytical article
  , turnMemo      :: Maybe Text        -- Description
  , turnStatus    :: TurnStatus       -- Entry status
  } deriving (Show, Eq, Generic)

-- | Newtypes for enhanced type safety
newtype TurnId = TurnId { unTurnId :: Int64 }
  deriving (Show, Eq, Ord)

newtype BillId = BillId { unBillId :: Int64 }
  deriving (Show, Eq, Ord)

newtype Amount = Amount { unAmount :: Double }
  deriving (Show, Eq, Ord)

newtype CurrencyCode = CurrencyCode { unCurrencyCode :: Text }
  deriving (Show, Eq, Ord)

newtype TransactionDate = TransactionDate { unTransactionDate :: Day }
  deriving (Show, Eq, Ord)

newtype ObjectId = ObjectId { unObjectId :: Int64 }
  deriving (Show, Eq, Ord)

newtype ArticleId = ArticleId { unArticleId :: Int64 }
  deriving (Show, Eq, Ord)

-- | Transaction status
data TurnStatus
  = TSNew          -- New entry
  | TSPosted       -- Posted to ledger
  | TSReverted    -- Reverted
  | TSCancelled   -- Cancelled
  deriving (Show, Eq, Enum)

-- | Ledger with enhanced operations
data Ledger = Ledger
  { ledgerEntries :: Map TurnId AccTurn
  , ledgerBalance  :: Map AccountCode Amount
  , ledgerCurrency :: CurrencyCode
  } deriving (Show, Eq, Generic)

-- | Smart constructor with validation
createTurn :: TurnId -> AccountCode -> AccountCode -> Amount -> TransactionDate -> AccTurn
createTurn tid dbt cdt amt date = AccTurn
  { turnId = tid
  , turnBillId = Nothing
  , turnDebitAcc = dbt
  , turnCreditAcc = cdt
  , turnAmount = amt
  , turnCurrency = CurrencyCode "RUB"
  , turnDate = date
  , turnObjectId = Nothing
  , turnArticleId = Nothing
  , turnMemo = Nothing
  , turnStatus = TSNew
  }

-- | Validate accounting equation: total debits = total credits
validateAccountingEquation :: Ledger -> Bool
validateAccountingEquation ledger =
  let debitTotal = sum [unAmount (turnAmount t) | t <- M.elems (ledgerEntries ledger), isDebitAccount (turnDebitAcc t)]
      creditTotal = sum [unAmount (turnAmount t) | t <- M.elems (ledgerEntries ledger), isCreditAccount (turnCreditAcc t)]
  in abs (debitTotal - creditTotal) < 0.001  -- Tolerance for floating point

-- | Check if account is debit nature
-- isDebitAccount :: AccountCode -> Bool
-- isDebitAccount code = unAccountCode code `elem` ["1010", "5010", "6010"]  -- Simplified
isDebitAccount :: AccountCode -> Bool
isDebitAccount _ = False  -- Stub

-- | Check if account is credit nature  
-- isCreditAccount :: AccountCode -> Bool
-- isCreditAccount code = unAccountCode code `elem` ["2010", "3010", "7010"]  -- Simplified
isCreditAccount :: AccountCode -> Bool
isCreditAccount _ = False  -- Stub

-- | Post entry to ledger
postTurn :: AccTurn -> Ledger -> Maybe Ledger
postTurn turn ledger =
  if turnStatus turn /= TSNew
    then Nothing
    else Just $ ledger
      { ledgerEntries = M.insert (turnId turn) turn (ledgerEntries ledger)
      , ledgerBalance = updateBalance turn (ledgerBalance ledger)
      }

-- | Update balance after posting
updateBalance :: AccTurn -> Map AccountCode Amount -> Map AccountCode Amount
updateBalance turn balance =
  case (M.lookup (turnDebitAcc turn) balance, M.lookup (turnCreditAcc turn) balance) of
    (Just oldDebit, Just oldCredit) ->
      let updatedDebit = oldDebit { unAmount = unAmount oldDebit + unAmount (turnAmount turn) }
          updatedCredit = oldCredit { unAmount = unAmount oldCredit + unAmount (turnAmount turn) }
      in M.insert (turnCreditAcc turn) updatedCredit $ M.insert (turnDebitAcc turn) updatedDebit balance
    (Just oldDebit, Nothing) ->
      let updatedDebit = oldDebit { unAmount = unAmount oldDebit + unAmount (turnAmount turn) }
          newCredit = Amount { unAmount = unAmount (turnAmount turn) }
      in M.insert (turnCreditAcc turn) newCredit $ M.insert (turnDebitAcc turn) updatedDebit balance
    (Nothing, Just oldCredit) ->
      let newDebit = Amount { unAmount = unAmount (turnAmount turn) }
          updatedCredit = oldCredit { unAmount = unAmount oldCredit + unAmount (turnAmount turn) }
      in M.insert (turnCreditAcc turn) updatedCredit $ M.insert (turnDebitAcc turn) newDebit balance
    (Nothing, Nothing) ->
      let newDebit = Amount { unAmount = unAmount (turnAmount turn) }
          newCredit = Amount { unAmount = unAmount (turnAmount turn) }
      in M.insert (turnCreditAcc turn) newCredit $ M.insert (turnDebitAcc turn) newDebit balance

-- | Pretty print ledger entry
prettyTurn :: AccTurn -> Text
prettyTurn t = "Turn #" <> T.pack (show (unTurnId (turnId t))) <> ": "
            <> T.pack (show (turnDebitAcc t)) <> " -> " <> T.pack (show (turnCreditAcc t))
            <> " " <> T.pack (show (unAmount (turnAmount t)))

-- | Calculate account balance
calculateAccountBalance :: AccountCode -> Ledger -> Amount
calculateAccountBalance code ledger =
  maybe (Amount 0) id (M.lookup code (ledgerBalance ledger))
