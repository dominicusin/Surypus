-- | Accounting Operations with Formal Verification
-- Модуль содержит инварианты и проверенные операции для бухгалтерии
-- LiquidHaskell refinement types for accounting
{-@ type NonNegAmount = {v:Double | v >= 0} @-}
{-@ type BalancedTransaction = {v:Transaction | sum [amount | Entry Debit amount _ <- txEntries v] == sum [amount | Entry Credit amount _ <- txEntries v]} @-}
  ( AccOpResult (..),
    validateEntry,
    verifyBalance,
    verifyDoubleEntry,
    calcAccountBalance,
    calcTurnover,
  )
where

import Core.Accounting.Types
import Data.Text (Text)

-- | Accounting operation result
data AccOpResult
  = AccOpSuccess
  | AccOpInvalidAmount
  | AccOpBalanceError Text
  | AccOpDoubleEntryError
  deriving (Show, Eq)

-- | Validate accounting entry
-- Инвариант: сумма > 0
validateEntry :: Double -> AccOpResult
validateEntry amount
  | amount <= 0 = AccOpInvalidAmount
  | otherwise = AccOpSuccess

-- | Verify account balance
-- Инвариант: сальдо должно быть корректным
verifyBalance :: Double -> Double -> AccOpResult
verifyBalance debit credit
  | debit < 0 || credit < 0 = AccOpInvalidAmount
  | otherwise = AccOpSuccess

-- | Verify double-entry bookkeeping: sum(debit) = sum(credit)
-- Критический инвариант: ∑Debit = ∑Credit
verifyDoubleEntry :: [AccTurn] -> AccOpResult
verifyDoubleEntry entries
  | totalDebit == totalCredit = AccOpSuccess
  | otherwise = AccOpDoubleEntryError
  where
    totalDebit = sum (fmap atAmount entries)
    totalCredit = sum (fmap (negate . atAmount) entries)

-- | Calculate account balance
-- Баланс = дебет - кредит
calcAccountBalance :: [AccTurn] -> Double
calcAccountBalance entries = sum (fmap atAmount entries)

-- | Calculate turnover (оборот) for period
calcTurnover :: [AccTurn] -> (Double, Double)
calcTurnover entries = (debitTurnover, creditTurnover)
  where
    debitTurnover = sum [abs a | a <- fmap atAmount entries, a > 0]
    creditTurnover = sum [abs a | a <- fmap atAmount entries, a < 0]
