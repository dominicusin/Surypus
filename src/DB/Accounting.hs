{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}

module DB.Accounting
  ( listAccounts,
    createAccount,
    getAccount,
    listEntries,
    createEntry,
    trialBalance,
  )
where

import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (Day)
import Domain.Accounting
import Domain.Types (Pagination (..))
import qualified Hasql.Decoders as D
import qualified Hasql.Encoders as E
import Hasql.Pool (Pool, use)
import qualified Hasql.Session as Session
import Hasql.Statement (Statement)

listAccounts :: Pool -> Pagination -> AccountFilter -> IO [AccAccount]
listAccounts pool (Pagination limit offset) AccountFilter {..} = do
  result <- use pool $ Session.statement params stmt
  case result of
    Right x -> pure x
    Left _ -> pure []
  where
    params = (limit, offset, afSheetId, afCodeLike, afType)
    afCodeLike = fmap (\txt -> T.concat ["%", T.strip txt, "%"]) afCode
    stmt =
      Statement
        "SELECT id, sheet_id, code, name, atype, parent_id, currency_id, balance FROM accounting.account WHERE ($3 IS NULL OR sheet_id = $3) AND ($4 IS NULL OR code ILIKE $4) AND ($5 IS NULL OR atype = $5) ORDER BY id LIMIT $1 OFFSET $2"
        ( E.param (E.nonNullable E.int4)
            <> E.param (E.nonNullable E.int4)
            <> E.param (E.nullable E.int8)
            <> E.param (E.nullable E.text)
            <> E.param (E.nullable E.int4)
        )
        (D.rowList accountRowDecoder)

accountRowDecoder :: D.Row AccAccount
accountRowDecoder =
  AccAccount
    <$> (Just <$> D.column (D.nonNullable D.int8))
    <*> D.column (D.nonNullable D.int8)
    <*> D.column (D.nonNullable D.text)
    <*> D.column (D.nonNullable D.text)
    <*> D.column (D.nonNullable D.int4)
    <*> D.column (D.nullable D.int8)
    <*> D.column (D.nullable D.int8)
    <*> D.column (D.nonNullable D.float8)

createAccount :: Pool -> AccAccount -> IO Int64
createAccount pool AccAccount {..} = do
  result <- use pool $ Session.statement params stmt
  case result of
    Right x -> pure x
    Left _ -> pure 0
  where
    params =
      ( accAccountSheet,
        accAccountCode,
        accAccountName,
        accAccountType,
        accAccountParent,
        accAccountCurrency
      )
    stmt =
      Statement
        "INSERT INTO accounting.account (sheet_id, code, name, atype, parent_id, currency_id) VALUES ($1,$2,$3,$4,$5,$6) RETURNING id"
        ( E.param (E.nonNullable E.int8)
            <> E.param (E.nonNullable E.text)
            <> E.param (E.nonNullable E.text)
            <> E.param (E.nonNullable E.int4)
            <> E.param (E.nullable E.int8)
            <> E.param (E.nullable E.int8)
        )
        (D.singleRow $ D.column (D.nonNullable D.int8))

getAccount :: Pool -> Int64 -> IO (Maybe AccAccount)
getAccount pool aid = do
  result <- use pool $ Session.statement aid stmt
  case result of
    Right x -> pure x
    Left _ -> pure Nothing
  where
    stmt =
      Statement
        "SELECT id, sheet_id, code, name, atype, parent_id, currency_id, balance FROM accounting.account WHERE id = $1"
        (E.param (E.nonNullable E.int8))
        (D.rowMaybe accountRowDecoder)

listEntries :: Pool -> Pagination -> EntryFilter -> IO [AccEntry]
listEntries pool (Pagination limit offset) EntryFilter {..} = do
  result <- use pool $ Session.statement params stmt
  case result of
    Right x -> pure x
    Left _ -> pure []
  where
    params = (efAccountId, efSince, efUntil, limit, offset)
    stmt =
      Statement
        "SELECT id, dt, bill_id, debit_acc_id, credit_acc_id, amount, currency_id, memo FROM accounting.acct_entry WHERE ($1 IS NULL OR debit_acc_id = $1 OR credit_acc_id = $1) AND ($2 IS NULL OR dt >= $2) AND ($3 IS NULL OR dt <= $3) ORDER BY dt DESC LIMIT $4 OFFSET $5"
        ( E.param (E.nullable E.int8)
            <> E.param (E.nullable E.date)
            <> E.param (E.nullable E.date)
            <> E.param (E.nonNullable E.int4)
            <> E.param (E.nonNullable E.int4)
        )
        (D.rowList entryRowDecoder)

entryRowDecoder :: D.Row AccEntry
entryRowDecoder =
  AccEntry
    <$> (Just <$> D.column (D.nonNullable D.int8))
    <*> D.column (D.nonNullable D.date)
    <*> D.column (D.nullable D.int8)
    <*> D.column (D.nonNullable D.int8)
    <*> D.column (D.nonNullable D.int8)
    <*> D.column (D.nonNullable D.float8)
    <*> D.column (D.nullable D.int8)
    <*> D.column (D.nullable D.text)

createEntry :: Pool -> AccEntry -> IO Int64
createEntry pool AccEntry {..} = do
  result <- use pool $ Session.statement params stmt
  case result of
    Right x -> pure x
    Left _ -> pure 0
  where
    params =
      ( accEntryDate,
        accEntryBillId,
        accEntryDebitAcc,
        accEntryCreditAcc,
        accEntryAmount,
        accEntryCurrency,
        accEntryMemo
      )
    stmt =
      Statement
        "INSERT INTO accounting.acct_entry (dt, bill_id, debit_acc_id, credit_acc_id, amount, currency_id, memo) VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING id"
        ( E.param (E.nonNullable E.date)
            <> E.param (E.nullable E.int8)
            <> E.param (E.nonNullable E.int8)
            <> E.param (E.nonNullable E.int8)
            <> E.param (E.nonNullable E.float8)
            <> E.param (E.nullable E.int8)
            <> E.param (E.nullable E.text)
        )
        (D.singleRow $ D.column (D.nonNullable D.int8))

trialBalance :: Pool -> Int64 -> Day -> IO [TrialBalanceRow]
trialBalance pool sheetId asOf = do
  result <- use pool $ Session.statement (sheetId, asOf) stmt
  case result of
    Right x -> pure x
    Left _ -> pure []
  where
    stmt =
      Statement
        "SELECT account_id, account_code, account_name, debit_turnover, credit_turnover, debit_end, credit_end, balance FROM accounting.trial_balance($1,$2)"
        ( E.param (E.nonNullable E.int8)
            <> E.param (E.nonNullable E.date)
        )
        (D.rowList trialBalanceRowDecoder)

trialBalanceRowDecoder :: D.Row TrialBalanceRow
trialBalanceRowDecoder =
  TrialBalanceRow
    <$> D.column (D.nonNullable D.int8)
    <*> D.column (D.nonNullable D.text)
    <*> D.column (D.nonNullable D.text)
    <*> D.column (D.nonNullable D.float8)
    <*> D.column (D.nonNullable D.float8)
    <*> D.column (D.nonNullable D.float8)
    <*> D.column (D.nonNullable D.float8)
    <*> D.column (D.nonNullable D.float8)
