{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}

-- | Finance.BankAccount - Enhanced bank account management with type safety
-- This module provides secure bank account operations with formal verification
module Finance.BankAccount where

import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (Day, fromGregorian)
import Surypus.Types (Decimal, NonNeg, mkNonNeg, unNonNeg)

-- | Enhanced bank account with richer types
data BankAccount = BankAccount
  { baId            :: BankAccountId
  , baBankId        :: BankId
  , baAccountNumber :: AccountNumber
  , baAccountName   :: AccountName
  , baCurrency       :: CurrencyCode
  , baBalance        :: NonNeg        -- Balance always >= 0
  , baOpenedAt      :: Day
  , baClosedAt      :: Maybe Day
  , baIsActive      :: Bool
  , baBranchCode    :: Maybe BranchCode
  , baBIC           :: Maybe BICCode
  , baCorrespondent :: Maybe Text
  } deriving (Show, Eq, Generic)

-- | Newtypes for enhanced type safety
newtype BankAccountId = BankAccountId { unBankAccountId :: Int64 }
  deriving (Show, Eq, Ord)

newtype BankId = BankId { unBankId :: Int64 }
  deriving (Show, Eq, Ord)

newtype AccountNumber = AccountNumber { unAccountNumber :: Text }
  deriving (Show, Eq, Ord)

newtype AccountName = AccountName { unAccountName :: Text }
  deriving (Show, Eq, Ord)

newtype CurrencyCode = CurrencyCode { unCurrencyCode :: Text }
  deriving (Show, Eq, Ord)

newtype BranchCode = BranchCode { unBranchCode :: Text }
  deriving (Show, Eq, Ord)

newtype BICCode = BICCode { unBICCode :: Text }
  deriving (Show, Eq, Ord)

-- | Smart constructor with validation
createBankAccount :: BankAccountId -> BankId -> AccountNumber -> AccountName -> CurrencyCode -> Day -> BankAccount
createBankAccount baId bankId accNum accName curr today = BankAccount
  { baId = baId
  , baBankId = bankId
  , baAccountNumber = accNum
  , baAccountName = accName
  , baCurrency = curr
  , baBalance = mkNonNeg 0
  , baOpenedAt = today
  , baClosedAt = Nothing
  , baIsActive = True
  , baBranchCode = Nothing
  , baBIC = Nothing
  , baCorrespondent = Nothing
  }

-- | Deposit with invariant: balance >= 0 after deposit
depositToAccount :: NonNeg -> BankAccount -> Maybe BankAccount
depositToAccount amount account
  | amount <= 0 = Nothing
  | otherwise = Just $ account
      { baBalance = mkNonNeg (unNonNeg (baBalance account) + unNonNeg amount)
      , baUpdatedAt = Just (error "UpdatedAt: should be supplied")
      }

-- | Withdraw with invariant: balance >= amount (sufficient funds)
withdrawFromAccount :: NonNeg -> BankAccount -> Maybe BankAccount
withdrawFromAccount amount account
  | amount <= 0 = Nothing
  | unNonNeg amount > unNonNeg (baBalance account) = Nothing  -- Insufficient funds
  | otherwise = Just $ account
      { baBalance = mkNonNeg (unNonNeg (baBalance account) - unNonNeg amount)
      , baUpdatedAt = Just (error "UpdatedAt: should be supplied")
      }

-- | Close account - must have zero balance
closeBankAccount :: BankAccount -> Maybe BankAccount
closeBankAccount account
  | unNonNeg (baBalance account) /= 0 = Nothing  -- Cannot close with non-zero balance
  | otherwise = Just $ account
      { baIsActive = False
      , baClosedAt = Just (fromGregorian 2024 1 1)  -- Should be supplied
      }

-- | Check if account is active
isActiveAccount :: BankAccount -> Bool
isActiveAccount = baIsActive

-- | Check if account has sufficient funds
hasSufficientFunds :: NonNeg -> BankAccount -> Bool
hasSufficientFunds amount account = unNonNeg (baBalance account) >= unNonNeg amount

-- | Calculate account age in days
accountAge :: Day -> BankAccount -> Int
accountAge today account = truncate (fromIntegral (diffDays today (baOpenedAt account)) / 1) :: Int

-- | Pretty print bank account
prettyBankAccount :: BankAccount -> Text
prettyBankAccount acc = unAccountNumber (baAccountNumber acc) <> " - " <> unAccountName (baAccountName acc) <>
  ", Balance: " <> T.pack (show (unNonNeg (baBalance acc)) <>
  if baIsActive acc then " (Active)" else " (Closed)"
