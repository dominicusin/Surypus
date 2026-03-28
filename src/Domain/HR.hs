{-# LANGUAGE DeriveGeneric #-}

module Domain.HR
  ( SalaryRecord (..),
    SalaryCharge (..),
    SalaryChargeInput (..),
    SalarySummary (..),
    SalaryFilter (..),
    defaultSalaryFilter,
    validateSalaryRecord,
    validateSalaryChargeInput,
    mkSalaryCharge,
    calcPeriodDays,
    calcSalaryPerDay,
  )
where

import Core.HR.Types
  ( SalaryCharge (..),
    SalaryChargeInput (..),
    SalaryRecord (..),
    SalarySummary (..),
    calcPeriodDays,
    calcSalaryPerDay,
    mkSalaryCharge,
    validateSalaryChargeInput,
    validateSalaryRecord,
  )
import Data.Aeson (FromJSON, ToJSON)
import Data.Int (Int64)
import Data.Time (Day)
import GHC.Generics (Generic)

data SalaryFilter = SalaryFilter
  { sfEmployeeId :: Maybe Int64,
    sfChargeId :: Maybe Int64,
    sfPeriodStart :: Maybe Day,
    sfPeriodEnd :: Maybe Day
  }
  deriving (Eq, Show, Generic)

instance ToJSON SalaryFilter

instance FromJSON SalaryFilter

defaultSalaryFilter :: SalaryFilter
defaultSalaryFilter = SalaryFilter Nothing Nothing Nothing Nothing
