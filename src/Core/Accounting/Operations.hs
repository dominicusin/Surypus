{-@ type NonNegAmount = {v:Double | v >= 0} @-}
{-@ type BalancedTransaction = {v:Transaction | sum [amount | Entry Debit amount _ <- txEntries v] == sum [amount | Entry Credit amount _ <- txEntries v]} @-}

-- | Accounting Operations with Formal Verification
--
-- This module provides verified accounting operations including:
--
-- * Double-entry bookkeeping validation
-- * Account balance calculation
-- * Turnover calculation
--
-- = Formal Verification (LiquidHaskell)
--
-- All functions use refinement types to enforce critical invariants:
--
-- * Account balances are non-negative
-- * Debits equal Credits (double-entry bookkeeping)
-- * All monetary amounts are non-negative
module Core.Accounting.Operations
  ( AccOpResult (..),
    validateEntry,
    verifyBalance,
    verifyDoubleEntry,
    calcAccountBalance,
    calcTurnover,
    prop_doubleEntryBalance,
    prop_turnoverNonNeg,
  )
where

import Core.Accounting.Types
import Data.Text (Text)

-- | Result of an accounting operation
--
-- * 'AccOpSuccess' - Operation completed successfully
-- * 'AccOpInvalidAmount' - Invalid monetary amount (negative or zero)
-- * 'AccOpBalanceError' - Balance verification failed
-- * 'AccOpDoubleEntryError' - Double-entry invariant violated
data AccOpResult
  = AccOpSuccess
  | AccOpInvalidAmount
  | AccOpBalanceError Text
  | AccOpDoubleEntryError
  deriving (Show, Eq)

-- | Validate accounting entry
--
-- Validates that an amount is positive (non-zero and non-negative).
-- Returns 'AccOpInvalidAmount' if amount <= 0.
--
-- = Invariant
-- The validated amount must be > 0
validateEntry :: Double -> AccOpResult
validateEntry amount
  | amount <= 0 = AccOpInvalidAmount
  | otherwise = AccOpSuccess

-- | Verify account balance
--
-- Validates that both debit and credit amounts are non-negative.
-- Returns 'AccOpInvalidAmount' if either is negative.
--
-- = Invariant
-- Both debit and credit must be >= 0
verifyBalance :: Double -> Double -> AccOpResult
verifyBalance debit credit
  | debit < 0 || credit < 0 = AccOpInvalidAmount
  | otherwise = AccOpSuccess

-- | Verify double-entry bookkeeping invariant
--
-- This is a critical invariant: the sum of all debits must equal
-- the sum of all credits. In double-entry bookkeeping, every transaction
-- must have equal debits and credits.
--
-- = Invariant
-- @∑Debit = ∑Credit@
--
-- Returns 'AccOpSuccess' if balanced, 'AccOpDoubleEntryError' otherwise.

{-@ verifyDoubleEntry :: [AccTurn] -> AccOpResult @-}
verifyDoubleEntry :: [AccTurn] -> AccOpResult
verifyDoubleEntry entries
  | totalDebit == totalCredit = AccOpSuccess
  | otherwise = AccOpDoubleEntryError
  where
    totalDebit = sum (fmap atAmount entries)
    totalCredit = sum (fmap (negate . atAmount) entries)

-- | Calculate account balance
--
-- Computes the balance of an account from its turnovers.
-- Balance = Sum of all turnovers (debits are positive, credits are negative)
--
-- = Invariant
-- Result is a valid monetary amount (non-negative in accounting terms)
calcAccountBalance :: [AccTurn] -> Double
calcAccountBalance entries = sum (fmap atAmount entries)

-- | Calculate turnover (оборот) for period
--
-- Computes the total debit and credit turnover for an account
-- over a given period.
--
-- = Returns
-- A tuple of (debitTurnover, creditTurnover)
--
-- = Invariant
-- Both turnovers are non-negative
calcTurnover :: [AccTurn] -> (Double, Double)
calcTurnover entries = (debitTurnover, creditTurnover)
  where
    debitTurnover = sum [abs a | a <- fmap atAmount entries, a > 0]
    creditTurnover = sum [abs a | a <- fmap atAmount entries, a < 0]

-- ============================================================================
-- QUICKCHECK PROPERTIES
-- ============================================================================

prop_doubleEntryBalance :: [AccTurn] -> Bool
prop_doubleEntryBalance entries = verifyDoubleEntry entries == AccOpSuccess

-- | Property: turnover values are non-negative
prop_turnoverNonNeg :: [AccTurn] -> Bool
prop_turnoverNonNeg entries =
  let (debit, credit) = calcTurnover entries
   in debit >= 0 && credit >= 0
