{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module Domain.Production
  ( TechFilter (..),
    Tech (..),
    WorkOrder (..),
    WorkOrderLine (..),
    WorkOrderStatus (..),
    BOMEntry (..),
    MRPNeed (..),
    MRPPlanItem (..),
    ProductionPlanSnapshot (..),
    validateWorkOrder,
    mkMRPNeed,
  )
where

import Data.Aeson (FromJSON, ToJSON)
import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (Day)
import GHC.Generics (Generic)

data TechFilter = TechFilter
  { tfName :: Maybe Text,
    tfGoodsId :: Maybe Int64
  }
  deriving (Eq, Show, Generic)

instance ToJSON TechFilter

instance FromJSON TechFilter

data Tech = Tech
  { techId :: Int64,
    techName :: Text,
    techGoodsId :: Maybe Int64,
    techOperationId :: Int64,
    techNorm :: Int,
    techRating :: Int,
    techFlag :: Int
  }
  deriving (Eq, Show, Generic)

instance ToJSON Tech

instance FromJSON Tech

data WorkOrderStatus
  = WODraft
  | WOReleased
  | WOInProgress
  | WOCompleted
  | WOCancelled
  deriving (Eq, Show, Enum, Generic)

instance ToJSON WorkOrderStatus

instance FromJSON WorkOrderStatus

data WorkOrder = WorkOrder
  { woId :: Int64,
    woCode :: Text,
    woProductId :: Int64,
    woQtty :: Double,
    woDueDate :: Maybe Day,
    woStatus :: WorkOrderStatus,
    woOutput :: Double
  }
  deriving (Eq, Show, Generic)

instance ToJSON WorkOrder

instance FromJSON WorkOrder

data WorkOrderLine = WorkOrderLine
  { wolId :: Int64,
    wolOrderId :: Int64,
    wolGoodsId :: Int64,
    wolQtty :: Double,
    wolIssued :: Double
  }
  deriving (Eq, Show, Generic)

instance ToJSON WorkOrderLine

instance FromJSON WorkOrderLine

data BOMEntry = BOMEntry
  { bomId :: Int64,
    bomProductId :: Int64,
    bomComponentId :: Int64,
    bomQtty :: Double
  }
  deriving (Eq, Show, Generic)

instance ToJSON BOMEntry

instance FromJSON BOMEntry

data MRPNeed = MRPNeed
  { mrnGoodsId :: Int64,
    mrnNeed :: Double
  }
  deriving (Eq, Show, Generic)

instance ToJSON MRPNeed

instance FromJSON MRPNeed

data MRPPlanItem = MRPPlanItem
  { mpiGoodsId :: Int64,
    mpiNeed :: Double,
    mpiOnHand :: Double,
    mpiOnOrder :: Double,
    mpiPlanned :: Double
  }
  deriving (Eq, Show, Generic)

instance ToJSON MRPPlanItem

instance FromJSON MRPPlanItem

data ProductionPlanSnapshot = ProductionPlanSnapshot
  { ppsId :: Int64,
    ppsCreatedAt :: Day,
    ppsPlan :: [MRPPlanItem],
    ppsParams :: Text
  }
  deriving (Eq, Show, Generic)

instance ToJSON ProductionPlanSnapshot

instance FromJSON ProductionPlanSnapshot

validateWorkOrder :: WorkOrder -> Either Text WorkOrder
validateWorkOrder wo
  | woQtty wo < 0 = Left "Quantity must be non-negative"
  | otherwise = Right wo

mkMRPNeed :: Int64 -> Double -> Maybe MRPNeed
mkMRPNeed _ qty
  | qty <= 0 = Nothing
  | otherwise = Just $ MRPNeed 0 qty
