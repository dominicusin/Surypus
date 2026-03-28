{-# LANGUAGE OverloadedStrings #-}

module DB.HRCharge
  ( listSalaryCharges,
    createSalaryCharge,
    updateSalaryCharge,
  )
where

import Core.HR.Types (SalaryCharge (..), SalaryChargeInput (..))
import Data.Int (Int64)
import qualified Hasql.Decoders as D
import qualified Hasql.Encoders as E
import Hasql.Pool (Pool, use)
import qualified Hasql.Session as Session
import Hasql.Statement (unpreparable)

salaryChargeRow :: D.Row SalaryCharge
salaryChargeRow =
  SalaryCharge
    <$> (Just <$> D.column (D.nonNullable D.int8))
    <*> D.column (D.nonNullable D.text)
    <*> D.column (D.nullable D.text)
    <*> (fromIntegral <$> D.column (D.nonNullable D.int4))

listSalaryCharges :: Pool -> IO [SalaryCharge]
listSalaryCharges pool = do
  result <- use pool $ Session.statement () stmt
  case result of
    Right x -> pure x
    Left _ -> pure []
  where
    stmt =
      unpreparable
        "SELECT id, name, code, flags FROM hr_salary_charge ORDER BY name"
        E.noParams
        (D.rowList salaryChargeRow)

createSalaryCharge :: Pool -> SalaryChargeInput -> IO Int64
createSalaryCharge _pool _input = pure 0

updateSalaryCharge :: Pool -> Int64 -> SalaryChargeInput -> IO (Maybe SalaryCharge)
updateSalaryCharge _pool _chargeId _input = pure Nothing
