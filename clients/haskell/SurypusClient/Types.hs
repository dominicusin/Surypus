{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
-- ============================================================================
-- Surypus Client Types
-- ============================================================================
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}

module SurypusClient.Types where

import Data.Aeson (FromJSON, ToJSON)
import Data.Text (Text)
import Data.Time (UTCTime)
import Data.UUID (UUID)
import GHC.Generics (Generic)

-- ============================================================================
-- COMMON TYPES
-- ============================================================================

data Money = Money
  { currency :: Text,
    amountCents :: Int
  }
  deriving (Show, Eq, Generic, FromJSON, ToJSON)

-- ============================================================================
-- REQUEST TYPES
-- ============================================================================

data ReceiveStockRequest = ReceiveStockRequest
  { rsAggregateId :: UUID,
    rsGoodsId :: UUID,
    rsLocationId :: UUID,
    rsQty :: Double,
    rsCost :: Money,
    rsPrice :: Maybe Money,
    rsLotNumber :: Maybe Text,
    rsExpiryDate :: Maybe UTCTime,
    rsExpectedVersion :: Maybe Int
  }
  deriving (Show, Eq, Generic, FromJSON, ToJSON)

data IssueStockRequest = IssueStockRequest
  { isAggregateId :: UUID,
    isGoodsId :: UUID,
    isLocationId :: UUID,
    isQty :: Double,
    isMethod :: IssueMethod,
    isExpectedVersion :: Maybe Int
  }
  deriving (Show, Eq, Generic, FromJSON, ToJSON)

data IssueMethod = FIFO | LIFO | FEFO
  deriving (Show, Eq, Generic, FromJSON, ToJSON)

data CreateBillRequest = CreateBillRequest
  { cbAggregateId :: UUID,
    cbBillCode :: Text,
    cbBillDate :: UTCTime,
    cbPersonId :: UUID,
    cbLocationId :: UUID,
    cbOpKindId :: Maybe UUID,
    cbNotes :: Maybe Text
  }
  deriving (Show, Eq, Generic, FromJSON, ToJSON)

data StartSagaRequest = StartSagaRequest
  { ssSagaType :: Text,
    ssCorrelationId :: UUID,
    ssInputData :: SagaInputData
  }
  deriving (Show, Eq, Generic, FromJSON, ToJSON)

data SagaInputData = SagaInputData
  { sidInventoryAggregateId :: Maybe UUID,
    sidBillAggregateId :: Maybe UUID,
    sidGoodsId :: Maybe UUID,
    sidLocationId :: Maybe UUID,
    sidPersonId :: Maybe UUID,
    sidQty :: Maybe Double,
    sidPrice :: Maybe Money,
    sidCost :: Maybe Money,
    sidBillCode :: Maybe Text
  }
  deriving (Show, Eq, Generic, FromJSON, ToJSON)

-- ============================================================================
-- RESPONSE TYPES
-- ============================================================================

data CommandResponse = CommandResponse
  { crSuccess :: Bool,
    crEventId :: Maybe Int,
    crSequenceNumber :: Maybe Int,
    crAggregateVersion :: Maybe Int,
    crErrorMessage :: Maybe Text
  }
  deriving (Show, Eq, Generic, FromJSON, ToJSON)

data IssueStockResponse = IssueStockResponse
  { isrSuccess :: Bool,
    isrEventId :: Maybe Int,
    isrSequenceNumber :: Maybe Int,
    isrAggregateVersion :: Maybe Int,
    isrLots :: [LotUsage]
  }
  deriving (Show, Eq, Generic, FromJSON, ToJSON)

data LotUsage = LotUsage
  { luLotId :: UUID,
    luQtyUsed :: Double,
    luCost :: Money,
    luAmount :: Money
  }
  deriving (Show, Eq, Generic, FromJSON, ToJSON)

data StockBalanceResponse = StockBalanceResponse
  { sbrBalances :: [StockBalance]
  }
  deriving (Show, Eq, Generic, FromJSON, ToJSON)

data StockBalance = StockBalance
  { sbGoodsId :: UUID,
    sbLocationId :: UUID,
    sbCurrentQty :: Double,
    sbReservedQty :: Double,
    sbAvailableQty :: Double,
    sbAvgCost :: Maybe Money,
    sbTotalValue :: Maybe Money,
    sbLastMovementAt :: Maybe UTCTime
  }
  deriving (Show, Eq, Generic, FromJSON, ToJSON)

data StartSagaResponse = StartSagaResponse
  { ssrSagaId :: UUID,
    ssrStatus :: SagaStatus
  }
  deriving (Show, Eq, Generic, FromJSON, ToJSON)

data SagaStatusResponse = SagaStatusResponse
  { ssrSagaId :: UUID,
    ssrSagaType :: Text,
    ssrStatus :: SagaStatus,
    ssrCurrentStep :: Int,
    ssrTotalSteps :: Int,
    ssrProgressPct :: Double,
    ssrStartedAt :: UTCTime,
    ssrUpdatedAt :: UTCTime,
    ssrCompletedAt :: Maybe UTCTime,
    ssrErrorMessage :: Maybe Text
  }
  deriving (Show, Eq, Generic, FromJSON, ToJSON)

data SagaStatus
  = SagaStarted
  | SagaRunning
  | SagaCompleted
  | SagaCompensating
  | SagaCompensated
  | SagaFailed
  deriving (Show, Eq, Generic, FromJSON, ToJSON)
