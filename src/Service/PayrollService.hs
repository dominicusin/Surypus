{-# LANGUAGE OverloadedStrings #-}

module Service.PayrollService
  ( PayrollService (..),
    computeNetSalary,
  )
where

import Hasql.Pool (Pool)

data PayrollService = PayrollService
  { psPool :: Pool
  }

computeNetSalary :: PayrollService -> Double -> Double -> IO Double
computeNetSalary _ gross taxRate = do
  let net = gross - (gross * taxRate / 100)
  pure net
