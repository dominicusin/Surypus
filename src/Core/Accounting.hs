-- | Accounting Module - Double-entry bookkeeping
-- Re-exports all accounting types and functions
module Core.Accounting
  ( module Core.Accounting.Account,
    module Core.Accounting.Ledger,
    validateAccTurn,
    calcBalance,
    getDebit,
    getCredit,
    isDebitBalanced,
    isCreditBalanced,
  )
where

import Core.Accounting.Account
import Core.Accounting.Ledger
import Data.Int (Int64)

-- ============================================================================
-- ACCOUNTING FUNCTIONS
-- ============================================================================

-- | Validate accounting entry: debits must equal credits
validateAccTurn :: [AccTurn] -> Bool
validateAccTurn turns =
  let totalDebit = sum (fmap (max 0 . atAmount) turns)
      totalCredit = sum (fmap (max 0 . negate . atAmount) turns)
   in totalDebit == totalCredit

-- | Calculate balance for account
calcBalance :: [AccTurn] -> Int64 -> Double
calcBalance turns accountId =
  let debitSum = sum [atAmount t | t <- turns, atDbtAccId t == accountId]
      creditSum = sum [atAmount t | t <- turns, atCrdAccId t == accountId]
   in debitSum - creditSum

-- | Get debit side of entry
getDebit :: AccTurn -> Double
getDebit at = max (atAmount at) 0

-- | Get credit side of entry
getCredit :: AccTurn -> Double
getCredit at = if atAmount at < 0 then abs (atAmount at) else 0

-- | Check if account is debit-balanced (assets, expenses)
isDebitBalanced :: AccountType -> Bool
isDebitBalanced at = at == ATAsset || at == ATExpense

-- | Check if account is credit-balanced (liabilities, equity, revenue)
isCreditBalanced :: AccountType -> Bool
isCreditBalanced at = at == ATLiability || at == ATEquity || at == ATRevenue
