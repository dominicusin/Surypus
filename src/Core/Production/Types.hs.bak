{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}

{-@ LIQUID "--reflection" @-}

module Core.Production.Types
  ( TechCard(..)
  , TechLine(..)
  , WorkOrder(..)
  , WorkOrderStatusCode(..)
  , mkWorkOrder
  , validateTechCard
  , validateTechLine
  , validateWorkOrderCore
  , toWorkOrderStatus
  ) where

import Data.Aeson (FromJSON, ToJSON)
import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (UTCTime)
import GHC.Generics (Generic)
import qualified Data.Text as T

{-@ type NonNegQty = {v:Double | v >= 0} @-}
{-@ type NonNegCost = {v:Double | v >= 0} @-}

{-@ data TechCard = TechCard
  { tcId :: Maybe Int64
  , tcProcessorId :: Int64
  , tcGoodsGroupId :: Int64
  , tcKind :: {v:Int | v == 0 || v == 1}
  , tcCode :: Text
  , tcFlags :: Int
  , tcFormula :: Maybe Text
  } @-}
data TechCard = TechCard
  { tcId :: Maybe Int64
  , tcProcessorId :: Int64
  , tcGoodsGroupId :: Int64
  , tcKind :: Int
  , tcCode :: Text
  , tcFlags :: Int
  , tcFormula :: Maybe Text
  } deriving (Show, Eq, Generic)

instance ToJSON TechCard
instance FromJSON TechCard

{-@ data TechLine = TechLine
  { tlTechCardId :: Int64
  , tlLineNo :: Int
  , tlGoodsId :: Int64
  , tlQtty :: NonNegQty
  , tlSign :: {v:Int | v >= -1 && v <= 1}
  , tlFormula :: Maybe Text
  , tlLineTime :: NonNegCost
  , tlLineCost :: NonNegCost
  } @-}
data TechLine = TechLine
  { tlTechCardId :: Int64
  , tlLineNo :: Int
  , tlGoodsId :: Int64
  , tlQtty :: Double
  , tlSign :: Int
  , tlFormula :: Maybe Text
  , tlLineTime :: Double
  , tlLineCost :: Double
  } deriving (Show, Eq, Generic)

instance ToJSON TechLine
instance FromJSON TechLine

{-@ data WorkOrderStatusCode = WO_Draft | WO_Released | WO_InProgress | WO_Completed | WO_Cancelled @-}
data WorkOrderStatusCode =
    WO_Draft
  | WO_Released
  | WO_InProgress
  | WO_Completed
  | WO_Cancelled
  deriving (Eq, Show, Enum)

{-@ data WorkOrder = WorkOrder
  { woId :: Maybe Int64
  , woCode :: Text
  , woProcessorId :: Int64
  , woProductId :: Int64
  , woQtyPlan :: NonNegQty
  , woQtyReleased :: NonNegQty
  , woStatus :: WorkOrderStatusCode
  , woScheduledAt :: UTCTime
  , woStartAt :: Maybe UTCTime
  , woEndAt :: Maybe UTCTime
  } @-}
data WorkOrder = WorkOrder
  { woId :: Maybe Int64
  , woCode :: Text
  , woProcessorId :: Int64
  , woProductId :: Int64
  , woQtyPlan :: Double
  , woQtyReleased :: Double
  , woStatus :: WorkOrderStatusCode
  , woScheduledAt :: UTCTime
  , woStartAt :: Maybe UTCTime
  , woEndAt :: Maybe UTCTime
  } deriving (Show, Eq, Generic)

instance ToJSON WorkOrder
instance FromJSON WorkOrder

validateTechCard :: TechCard -> Either Text TechCard
validateTechCard tc@TechCard{..}
  | tcKind < 0 || tcKind > 1 = Left "tech kind must be 0 or 1"
  | T.null (T.strip tcCode) = Left "tech code cannot be empty"
  | tcProcessorId <= 0 = Left "processor id must be positive"
  | tcGoodsGroupId <= 0 = Left "goods group id must be positive"
  | otherwise = Right tc

validateTechLine :: TechLine -> Either Text TechLine
validateTechLine line@TechLine{..}
  | tlQtty < 0 = Left "tech line quantity must be non-negative"
  | tlLineTime < 0 = Left "line time must be non-negative"
  | tlLineCost < 0 = Left "line cost must be non-negative"
  | tlSign < -1 || tlSign > 1 = Left "line sign must be -1,0,1"
  | otherwise = Right line

validateWorkOrderCore :: WorkOrder -> Either Text WorkOrder
validateWorkOrderCore wo@WorkOrder{..}
  | T.null (T.strip woCode) = Left "work order code must be set"
  | woQtyPlan < 0 = Left "planned quantity must be non-negative"
  | woQtyReleased < 0 = Left "released quantity cannot be negative"
  | woQtyReleased > woQtyPlan = Left "released cannot exceed planned"
  | otherwise = Right wo

mkWorkOrder :: Text -> Int64 -> Int64 -> Double -> UTCTime -> WorkOrder
mkWorkOrder code processor product qty scheduled =
  WorkOrder Nothing code processor product qty 0 WO_Draft scheduled Nothing Nothing

toWorkOrderStatus :: Int -> Maybe WorkOrderStatusCode
toWorkOrderStatus n
  | n >= 0 && n <= 4 = Just (toEnum n)
  | otherwise = Nothing
