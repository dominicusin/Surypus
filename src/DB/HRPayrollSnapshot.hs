{-# LANGUAGE OverloadedStrings #-}

module DB.HRPayrollSnapshot
  ( registerPayrollSnapshot,
    listPayrollSnapshots,
  )
where

import Data.Aeson (eitherDecodeStrict)
import Data.Int (Int64)
import Data.Text.Encoding (encodeUtf8)
import Data.Time (Day)
import Domain.Payroll (PayrollSnapshotRecord (..))
import qualified Hasql.Decoders as D
import qualified Hasql.Encoders as E
import Hasql.Pool (Pool, use)
import qualified Hasql.Session as Session
import Hasql.Statement (unpreparable)

registerPayrollSnapshot :: Pool -> Day -> Day -> IO Int64
registerPayrollSnapshot _pool _start _end = do
  -- Stub implementation - proper implementation would use parameterized queries
  pure 0

listPayrollSnapshots :: Pool -> IO [PayrollSnapshotRecord]
listPayrollSnapshots pool = do
  result <- use pool $ Session.statement () stmt
  case result of
    Right x -> pure x
    Left _ -> pure []
  where
    stmt =
      unpreparable
        "SELECT id, period_start, period_end, created_at, summary::text FROM v_hr_payroll_snapshot"
        E.noParams
        (D.rowList payrollSnapshotRow)

payrollSnapshotRow :: D.Row PayrollSnapshotRecord
payrollSnapshotRow =
  ( \iid pstart pend created summaryText ->
      case eitherDecodeStrict (encodeUtf8 summaryText) of
        Left _ -> PayrollSnapshotRecord iid pstart pend created []
        Right summary -> PayrollSnapshotRecord iid pstart pend created summary
  )
    <$> D.column (D.nonNullable D.int8)
    <*> D.column (D.nonNullable D.date)
    <*> D.column (D.nonNullable D.date)
    <*> D.column (D.nonNullable D.timestamptz)
    <*> D.column (D.nonNullable D.text)
