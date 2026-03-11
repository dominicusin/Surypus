{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TupleSections #-}
{-@ LIQUID "--reflection" @-}

module Domain.Production
  ( TechFilter(..)
  , WorkOrder(..)
  , WorkOrderLine(..)
  , WorkOrderStatus(..)
  , BOMEntry(..)
  , MRPNeed(..)
  , MRPPlanItem(..)
  , ProductionPlanSnapshot(..)
  , validateWorkOrder
  , mkMRPNeed
  ) where

import Core.Refined (clampNonNeg)
import Data.Aeson (FromJSON, ToJSON)
import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (Day)
import GHC.Generics (Generic)

-- | Filters for technologies
data TechFilter = TechFilter
  { tfName    :: Maybe Text
  , tfGoodsId :: Maybe Int64
  } deriving (Eq, Show, Generic)

instance ToJSON TechFilter
instance FromJSON TechFilter

-- | Work order status
data WorkOrderStatus
  = WO_Draft
  | WO_Released
  | WO_InProgress
  | WO_Completed
  | WO_Cancelled
  deriving (Eq, Show, Enum)

-- | Work order header
data WorkOrder = WorkOrder
  { woId :: Int64
  , woCode :: Text
  , woProductId :: Int64
  , woQtty :: Double
  , woDueDate :: Maybe Day
  , woStatus :: WorkOrderStatus
  , woOutput :: Double
  } deriving (Eq, Show, Generic)

instance ToJSON WorkOrder
instance FromJSON WorkOrder

-- | Work order line (material requirement)
data WorkOrderLine = WorkOrderLine
  { wolId :: Int64
  , wolOrderId :: Int64
  , wolGoodsId :: Int64
  , wolQtty :: Double
  , wolIssued :: Double
  } deriving (Eq, Show, Generic)

instance ToJSON WorkOrderLine
instance FromJSON WorkOrderLine

-- | Bill of materials entry
data BOMEntry = BOMEntry
  { bomId :: Int64
  , bomProductId :: Int64
  , bomComponentId :: Int64
  , bomQtty :: Double
  } deriving (Eq, Show, Generic)

instance ToJSON BOMEntry
instance FromJSON BOMEntry

-- | MRP need descriptor
{-@ data MRPNeed = MRPNeed
  { mrnGoodsId :: Int64
  , mrnNeed :: {v:Double | v > 0}
  } @-}
data MRPNeed = MRPNeed
  { mrnGoodsId :: Int64
  , mrnNeed :: Double
  } deriving (Eq, Show, Generic)

instance ToJSON MRPNeed
instance FromJSON MRPNeed

-- | Output of mrp_calculate
data MRPPlanItem = MRPPlanItem
  { mpiGoodsId :: Int64
  , mpiNeed :: Double
  , mpiOnHand :: Double
  , mpiOnOrder :: Double
  , mpiPlanned :: Double
  } deriving (Eq, Show, Generic)

instance ToJSON MRPPlanItem
instance FromJSON MRPPlanItem

-- | Production plan snapshot stored via job
data ProductionPlanSnapshot = ProductionPlanSnapshot
  { ppsId :: Int64
  , ppsCreatedAt :: Day
  , ppsPlan :: [MRPPlanItem]
  , ppsParams :: Text
  } deriving (Eq, Show, Generic)

instance ToJSON ProductionPlanSnapshot
instance FromJSON ProductionPlanSnapshot

validateWorkOrder :: WorkOrder -> Either Text WorkOrder
validateWorkOrder wo@WorkOrder{..}
  | woQtty <= 0 = Left "quantity must be positive"
  | otherwise = Right wo

mkMRPNeed :: Int64 -> Double -> Maybe MRPNeed
mkMRPNeed goodsId qty
  | qty <= 0 = Nothing
  | otherwise = Just $ MRPNeed goodsId (clampNonNeg qty)
