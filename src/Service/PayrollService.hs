{-# LANGUAGE OverloadedStrings #-}

module Service.PayrollService
  ( PayrollService (..),
    createPayrollService,
    computeNetSalary,
    computeSalaryBreakdown,
    payrollProcessSnapshot,
    PayrollBreakdown (..),
    TaxConfig (..),
    applyDeductions,
    calculateBonus,
  )
where

import qualified DAL.Mutations as Mutations
import DAL.Types (MutationResult (..), QueryResult (..))
import Data.Aeson (Value)
import qualified Data.Aeson as A
import Data.Text (Text)
import qualified Data.Text as T
import Hasql.Pool (Pool)

data PayrollService = PayrollService
  { psPool :: Pool
  }

createPayrollService :: Pool -> PayrollService
createPayrollService = PayrollService

data TaxConfig = TaxConfig
  { tcIncomeTaxRate :: Double,
    tcSocialTaxRate :: Double,
    tcMedicalTaxRate :: Double,
    tcPensionTaxRate :: Double,
    tcMinTaxable :: Double
  }
  deriving (Show, Eq)

defaultTaxConfig :: TaxConfig
defaultTaxConfig =
  TaxConfig
    { tcIncomeTaxRate = 13.0,
      tcSocialTaxRate = 22.0,
      tcMedicalTaxRate = 5.1,
      tcPensionTaxRate = 2.9,
      tcMinTaxable = 0
    }

data PayrollBreakdown = PayrollBreakdown
  { pbGrossSalary :: Double,
    pbIncomeTax :: Double,
    pbSocialTax :: Double,
    pbMedicalTax :: Double,
    pbPensionTax :: Double,
    pbTotalDeductions :: Double,
    pbBonuses :: Double,
    pbNetSalary :: Double
  }
  deriving (Show, Eq)

computeNetSalary :: PayrollService -> Double -> Double -> IO Double
computeNetSalary _ gross taxRate = do
  let net = gross * (1 - taxRate / 100)
  pure net

computeSalaryBreakdown :: PayrollService -> Double -> Maybe Double -> TaxConfig -> IO PayrollBreakdown
computeSalaryBreakdown _ gross mBonus config = do
  let bonus = maybe 0.0 id mBonus
      grossWithBonus = gross + bonus
      incomeTax =
        if grossWithBonus > tcMinTaxable config
          then grossWithBonus * (tcIncomeTaxRate config / 100)
          else 0
      socialTax = grossWithBonus * (tcSocialTaxRate config / 100)
      medicalTax = grossWithBonus * (tcMedicalTaxRate config / 100)
      pensionTax = grossWithBonus * (tcPensionTaxRate config / 100)
      totalDeductions = incomeTax + socialTax + medicalTax + pensionTax
      net = grossWithBonus - totalDeductions
  pure $
    PayrollBreakdown
      { pbGrossSalary = gross,
        pbIncomeTax = incomeTax,
        pbSocialTax = socialTax,
        pbMedicalTax = medicalTax,
        pbPensionTax = pensionTax,
        pbTotalDeductions = totalDeductions,
        pbBonuses = bonus,
        pbNetSalary = net
      }

applyDeductions :: Double -> [(Text, Double)] -> Double
applyDeductions salary deductions = salary - sum (map snd deductions)

calculateBonus :: Double -> Double -> Double -> Double
calculateBonus baseSalary performanceRating yearsOfService
  | performanceRating >= 4.0 = baseSalary * 0.2
  | performanceRating >= 3.0 = baseSalary * 0.1
  | otherwise =
      0
        + (baseSalary * 0.01 * yearsOfService)

-- Real payroll snapshot processing via DAL mutations
payrollProcessSnapshot :: Pool -> Value -> IO (Either Text Text)
payrollProcessSnapshot pool payload = do
  res <- Mutations.payrollSnapshotMutation pool payload
  case res of
    QuerySuccess t -> pure $ Right t
    QueryError err -> pure $ Left err
