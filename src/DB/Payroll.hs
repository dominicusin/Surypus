{-# LANGUAGE OverloadedStrings #-}

module DB.Payroll
  ( listSalaryRecords
  , createSalaryRecord
  , calcSalarySum
  , getPayrollSummary
  ) where

import Data.Int (Int64)
import Data.Maybe (fromMaybe)
import Data.Scientific (toRealFloat)
import Data.Time (Day)
import Hasql.Pool (Pool, use)
import Hasql.Statement (Statement(..))
import qualified Hasql.Encoders as E
import qualified Hasql.Decoders as D
import qualified Hasql.Session as Session
import Domain.HR (SalaryRecord(..), SalarySummary(..), SalaryFilter(..))

salaryRecordRow :: D.Row SalaryRecord
salaryRecordRow =
  SalaryRecord
    <$> (Just <$> D.column (D.nonNullable D.int8))
    <*> D.column (D.nonNullable D.int8)
    <*> D.column (D.nonNullable D.int8)
    <*> D.column (D.nonNullable D.date)
    <*> D.column (D.nonNullable D.date)
    <*> (toRealFloat <$> D.column (D.nonNullable D.numeric))
    <*> (Just <$> D.column (D.nullable D.int8))
    <*> (Just <$> D.column (D.nullable D.int8))
    <*> (Just <$> D.column (D.nullable D.int8))

listSalaryRecords :: Pool -> SalaryFilter -> IO [SalaryRecord]
listSalaryRecords pool SalaryFilter{..} = use pool $
  Session.statement (sfEmployeeId, sfChargeId, sfPeriodStart, sfPeriodEnd) stmt
  where
    stmt = Statement
      "SELECT id, employee_id, charge_id, period_start, period_end, amount, ext_obj_id, link_bill_id, gen_bill_id FROM hr_salary WHERE ($1 IS NULL OR employee_id = $1) AND ($2 IS NULL OR charge_id = $2) AND ($3 IS NULL OR period_start >= $3) AND ($4 IS NULL OR period_end <= $4) ORDER BY period_start DESC"
      (  E.param (E.nullable E.int8)
      <> E.param (E.nullable E.int8)
      <> E.param (E.nullable E.date)
      <> E.param (E.nullable E.date)
      )
      (D.rowList salaryRecordRow)
      False

createSalaryRecord :: Pool -> SalaryRecord -> IO Int64
createSalaryRecord pool SalaryRecord{..} = use pool $
  Session.statement
    ( srEmployeeId
    , srChargeId
    , srPeriodStart
    , srPeriodEnd
    , srAmount
    , fromMaybe 0 srExtObjId
    , fromMaybe 0 srLinkBillId
    , fromMaybe 0 srGenBillId
    ) stmt
  where
    stmt = Statement
      "SELECT create_salary_record($1,$2,$3,$4,$5,$6,$7,$8)"
      (  E.param (E.nonNullable E.int8)
      <> E.param (E.nonNullable E.int8)
      <> E.param (E.nonNullable E.date)
      <> E.param (E.nonNullable E.date)
      <> E.param (E.nonNullable E.numeric)
      <> E.param (E.nonNullable E.int8)
      <> E.param (E.nonNullable E.int8)
      <> E.param (E.nonNullable E.int8)
      )
      (D.singleRow $ D.column (D.nonNullable D.int8))
      False

calcSalarySum :: Pool -> Int64 -> Int64 -> Day -> Day -> IO Double
calcSalarySum pool emp charge start end = use pool $
  Session.statement (emp, charge, start, end) stmt
  where
    stmt = Statement
      "SELECT calc_salary_sum($1,$2,$3,$4)"
      (  E.param (E.nonNullable E.int8)
      <> E.param (E.nonNullable E.int8)
      <> E.param (E.nonNullable E.date)
      <> E.param (E.nonNullable E.date)
      )
      (D.singleRow $ toRealFloat <$> D.column (D.nonNullable D.numeric))
      False

payrollRow :: D.Row SalarySummary
payrollRow =
  SalarySummary
    <$> D.column (D.nonNullable D.int8)
    <*> D.column (D.nonNullable D.text)
    <*> D.column (D.nonNullable D.text)
    <*> (toRealFloat <$> D.column (D.nonNullable D.numeric))

getPayrollSummary :: Pool -> Day -> Day -> IO [SalarySummary]
getPayrollSummary pool start end = use pool $
  Session.statement (start, end) stmt
  where
    stmt = Statement
      "SELECT employee_id, employee_name, position_name, total_salary FROM hr_payroll_summary($1,$2)"
      (  E.param (E.nonNullable E.date)
      <> E.param (E.nonNullable E.date)
      )
      (D.rowList payrollRow)
      False
