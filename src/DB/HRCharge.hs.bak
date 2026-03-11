{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}

module DB.HRCharge
  ( listSalaryCharges
  , createSalaryCharge
  , updateSalaryCharge
  ) where

import Domain.HR (SalaryCharge(..), SalaryChargeInput(..))
import Hasql.Pool (Pool, use)
import Hasql.Statement (Statement(..))
import qualified Hasql.Decoders as D
import qualified Hasql.Encoders as E
import qualified Hasql.Session as Session
import Data.Int (Int64)
import Data.Text (Text)

salaryChargeRow :: D.Row SalaryCharge
salaryChargeRow = SalaryCharge
  <$> (Just <$> D.column (D.nonNullable D.int8))
  <*> D.column (D.nonNullable D.text)
  <*> D.column (D.nullable D.text)
  <*> D.column (D.nonNullable D.int4)

listSalaryCharges :: Pool -> IO [SalaryCharge]
listSalaryCharges pool = use pool $ Session.statement () stmt
  where
    stmt = Statement
      "SELECT id, name, code, flags FROM hr_salary_charge ORDER BY name"
      (E.noParams)
      (D.rowList salaryChargeRow)
      False

createSalaryCharge :: Pool -> SalaryChargeInput -> IO Int64
createSalaryCharge pool SalaryChargeInput{ sciName = name, sciCode = code, sciFlags = flags } = use pool $ Session.statement params stmt
  where
    params = (name, code, flags)
    stmt = Statement
      "INSERT INTO hr_salary_charge (name, code, flags) VALUES ($1, $2, $3) RETURNING id"
      (  E.param (E.nonNullable E.text)
      <> E.param (E.nullable E.text)
      <> E.param (E.nonNullable E.int4)
      )
      (D.singleRow $ D.column (D.nonNullable D.int8))
      False

updateSalaryCharge :: Pool -> Int64 -> SalaryChargeInput -> IO (Maybe SalaryCharge)
updateSalaryCharge pool chargeId SalaryChargeInput{ sciName = name, sciCode = code, sciFlags = flags } = use pool $ Session.statement params stmt
  where
    params = (name, code, flags, chargeId)
    stmt = Statement
      "UPDATE hr_salary_charge SET name = $1, code = $2, flags = $3 WHERE id = $4 RETURNING id, name, code, flags"
      (  E.param (E.nonNullable E.text)
      <> E.param (E.nullable E.text)
      <> E.param (E.nonNullable E.int4)
      <> E.param (E.nonNullable E.int8)
      )
      (D.rowMaybe salaryChargeRow)
      False
