{-# LANGUAGE OverloadedStrings #-}

module Domain.HRPropertySpec (spec_salaryProperties) where

import Test.Hspec
import Test.QuickCheck
import Domain.HR
import Data.Time.Calendar (Day(ModifiedJulianDay))
import Data.Either (isRight)

spec_salaryProperties :: Spec
spec_salaryProperties = describe "Salary property-based tests" $ do
  it "calcSalaryPerDay never returns negative values for valid records" $
    property $ \amount startLen spanLen ->
      let periodStart = ModifiedJulianDay startLen
          periodEnd = ModifiedJulianDay (startLen + abs spanLen)
          record = SalaryRecord
            { srId = Nothing
            , srEmployeeId = 1
            , srChargeId = 1
            , srPeriodStart = periodStart
            , srPeriodEnd = periodEnd
            , srAmount = abs amount
            , srExtObjId = Nothing
            , srLinkBillId = Nothing
            , srGenBillId = Nothing
            }
      in calcSalaryPerDay record >= 0.0

  it "validateSalaryRecord succeeds for generated valid salary records" $
    property $ \amount startLen spanLen ->
      let periodStart = ModifiedJulianDay startLen
          periodEnd = ModifiedJulianDay (startLen + abs spanLen)
          record = SalaryRecord
            { srId = Nothing
            , srEmployeeId = 2
            , srChargeId = 3
            , srPeriodStart = periodStart
            , srPeriodEnd = periodEnd
            , srAmount = abs amount
            , srExtObjId = Nothing
            , srLinkBillId = Nothing
            , srGenBillId = Nothing
            }
      in validateSalaryRecord record `shouldSatisfy` isRight

instance Arbitrary Day where
  arbitrary = ModifiedJulianDay <$> choose (55000, 62000)
