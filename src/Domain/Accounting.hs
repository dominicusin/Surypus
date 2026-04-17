{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}

{-@ LIQUID "--reflection" @-}

module Domain.Accounting
  ( AccAccount (..),
    AccAccountInput (..),
    AccountFilter (..),
    AccEntry (..),
    AccEntryInput (..),
    EntryFilter (..),
    TrialBalanceRow (..),
    prepareAccount,
    validateAccount,
    prepareEntry,
    validateEntry,
  )
where

import Core.Refined (clampNonNeg)
import Data.Aeson (FromJSON, ToJSON)
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (Day)
import GHC.Generics (Generic)

{-@ type NonNegDouble = {v:Double | v >= 0} @-}
{-@ type NonNegInt = {v:Int | v >= 0} @-}
{-@ type NonEmptyText = {v:Text | T.length v > 0} @-}

{-@ data AccAccount = AccAccount
  { accAccountId      :: Maybe Int64
  , accAccountSheet   :: Int64
  , accAccountCode    :: NonEmptyText
  , accAccountName    :: NonEmptyText
  , accAccountType    :: Int
  , accAccountParent  :: Maybe Int64
  , accAccountCurrency:: Maybe Int64
  , accAccountBalance :: NonNegDouble
  } @-}
data AccAccount = AccAccount
  { accAccountId :: Maybe Int64,
    accAccountSheet :: Int64,
    accAccountCode :: Text,
    accAccountName :: Text,
    accAccountType :: Int,
    accAccountParent :: Maybe Int64,
    accAccountCurrency :: Maybe Int64,
    accAccountBalance :: Double
  }
  deriving (Eq, Show, Generic)

instance FromJSON AccAccount

instance ToJSON AccAccount

{-@ data AccAccountInput = AccAccountInput
  { aaiSheetId   :: Int64
  , aaiCode      :: NonEmptyText
  , aaiName      :: NonEmptyText
  , aaiType      :: Int
  , aaiParentId  :: Maybe Int64
  , aaiCurrency  :: Maybe Int64
  } @-}
data AccAccountInput = AccAccountInput
  { aaiSheetId :: Int64,
    aaiCode :: Text,
    aaiName :: Text,
    aaiType :: Int,
    aaiParentId :: Maybe Int64,
    aaiCurrency :: Maybe Int64
  }
  deriving (Eq, Show, Generic)

instance FromJSON AccAccountInput

instance ToJSON AccAccountInput

data AccountFilter = AccountFilter
  { afSheetId :: Maybe Int64,
    afCode :: Maybe Text,
    afType :: Maybe Int,
    afLimit :: Int,
    afOffset :: Int
  }
  deriving (Eq, Show)

{-@ data AccEntry = AccEntry
  { accEntryId        :: Maybe Int64
  , accEntryDate      :: Day
  , accEntryBillId    :: Maybe Int64
  , accEntryDebitAcc  :: Int64
  , accEntryCreditAcc :: Int64
  , accEntryAmount    :: NonNegDouble
  , accEntryCurrency  :: Maybe Int64
  , accEntryMemo      :: Maybe Text
  } @-}
data AccEntry = AccEntry
  { accEntryId :: Maybe Int64,
    accEntryDate :: Day,
    accEntryBillId :: Maybe Int64,
    accEntryDebitAcc :: Int64,
    accEntryCreditAcc :: Int64,
    accEntryAmount :: Double,
    accEntryCurrency :: Maybe Int64,
    accEntryMemo :: Maybe Text
  }
  deriving (Eq, Show, Generic)

instance FromJSON AccEntry

instance ToJSON AccEntry

{-@ data AccEntryInput = AccEntryInput
  { aeiDate      :: Day
  , aeiBillId    :: Maybe Int64
  , aeiDebitAcc  :: Int64
  , aeiCreditAcc :: Int64
  , aeiAmount    :: NonNegDouble
  , aeiCurrency  :: Maybe Int64
  , aeiMemo      :: Maybe Text
  } @-}
data AccEntryInput = AccEntryInput
  { aeiDate :: Day,
    aeiBillId :: Maybe Int64,
    aeiDebitAcc :: Int64,
    aeiCreditAcc :: Int64,
    aeiAmount :: Double,
    aeiCurrency :: Maybe Int64,
    aeiMemo :: Maybe Text
  }
  deriving (Eq, Show, Generic)

instance FromJSON AccEntryInput

instance ToJSON AccEntryInput

data EntryFilter = EntryFilter
  { efAccountId :: Maybe Int64,
    efSince :: Maybe Day,
    efUntil :: Maybe Day,
    efLimit :: Int,
    efOffset :: Int
  }
  deriving (Eq, Show)

{-@ data TrialBalanceRow = TrialBalanceRow
  { tbAccountId      :: Int64
  , tbAccountCode    :: Text
  , tbAccountName    :: Text
  , tbDebitTurnover  :: NonNegDouble
  , tbCreditTurnover :: NonNegDouble
  , tbDebitEnd       :: NonNegDouble
  , tbCreditEnd      :: NonNegDouble
  , tbBalance        :: Double
  } @-}
data TrialBalanceRow = TrialBalanceRow
  { tbAccountId :: Int64,
    tbAccountCode :: Text,
    tbAccountName :: Text,
    tbDebitTurnover :: Double,
    tbCreditTurnover :: Double,
    tbDebitEnd :: Double,
    tbCreditEnd :: Double,
    tbBalance :: Double
  }
  deriving (Eq, Show, Generic)

instance FromJSON TrialBalanceRow

instance ToJSON TrialBalanceRow

prepareAccount :: AccAccountInput -> Either Text AccAccount
prepareAccount AccAccountInput {..}
  | T.null (T.strip aaiCode) = Left "account code is required"
  | T.null (T.strip aaiName) = Left "account name is required"
  | aaiSheetId <= 0 = Left "sheet id must be positive"
  | aaiType < 0 || aaiType > 4 = Left "account type 0..4"
  | otherwise =
      Right $
        AccAccount
          { accAccountId = Nothing,
            accAccountSheet = aaiSheetId,
            accAccountCode = T.strip aaiCode,
            accAccountName = T.strip aaiName,
            accAccountType = aaiType,
            accAccountParent = aaiParentId,
            accAccountCurrency = aaiCurrency,
            accAccountBalance = 0
          }

validateAccount :: AccAccount -> Either Text AccAccount
validateAccount acc@AccAccount {..}
  | T.null (T.strip accAccountCode) = Left "account code is required"
  | T.null (T.strip accAccountName) = Left "account name is required"
  | accAccountSheet <= 0 = Left "sheet id must be positive"
  | accAccountType < 0 || accAccountType > 4 = Left "account type 0..4"
  | otherwise = Right acc

prepareEntry :: AccEntryInput -> Either Text AccEntry
prepareEntry AccEntryInput {..} =
  validateEntry $
    AccEntry
      { accEntryId = Nothing,
        accEntryDate = aeiDate,
        accEntryBillId = aeiBillId,
        accEntryDebitAcc = aeiDebitAcc,
        accEntryCreditAcc = aeiCreditAcc,
        accEntryAmount = clampNonNeg aeiAmount,
        accEntryCurrency = aeiCurrency,
        accEntryMemo = aeiMemo
      }

validateEntry :: AccEntry -> Either Text AccEntry
validateEntry entry@AccEntry {..}
  | accEntryAmount <= 0 = Left "entry amount must be greater than zero"
  | accEntryDebitAcc == accEntryCreditAcc = Left "debit and credit accounts must differ"
  | otherwise = Right entry
