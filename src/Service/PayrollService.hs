{-# LANGUAGE OverloadedStrings #-}

-- | Payroll service skeleton (Phase 1)
module Service.PayrollService
  ( PayrollService (..),
    computeNetSalary,
  )
where

import Core.Payroll.Types (SalaryDetails (..))
import Hasql.Pool (Pool)

data PayrollService = PayrollService
  { psPool :: Pool
  }

-- | Placeholder for net salary computation
computeNetSalary :: PayrollService -> SalaryDetails -> IO SalaryDetails
computeNetSalary _ _ = error "PayrollService.computeNetSalary: not implemented"
