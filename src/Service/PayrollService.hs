{-# LANGUAGE OverloadedStrings #-}

-- | Payroll service - Salary computation
module Service.PayrollService
  ( PayrollService (..),
    computeNetSalary,
  )
where

import Core.Payroll.Calculation (calcNetSalaryFromGross)
import Core.Payroll.Types (SalaryDetails (..))
import Hasql.Pool (Pool)

data PayrollService = PayrollService
  { psPool :: Pool
  }

-- | Compute net salary from gross
-- = Invariant: result has non-negative amount
computeNetSalary :: PayrollService -> SalaryDetails -> IO SalaryDetails
computeNetSalary _ details = do
  let gross = sdGross details
      taxRate = sdTaxRate details
      net = calcNetSalaryFromGross gross taxRate
  pure $ details {sdNet = net}
