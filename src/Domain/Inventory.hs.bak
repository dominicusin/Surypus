{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-@ LIQUID "--reflection" @-}

-- | Domain-level helpers for inventory (инвентаризации, отклонения, сводки)
module Domain.Inventory
  ( InventoryDocument(..)
  , InventoryDocumentInput(..)
  , InventoryDocumentDetail(..)
  , InventoryLine(..)
  , InventoryLineInput(..)
  , InventorySummary(..)
  , InventoryStatus(..)
  , InventoryResult(..)
  , inventoryLineDiff
  , inventoryLineResult
  , inventorySummary
  , validateInventoryDocumentInput
  , validateInventoryLineInput
  )
where

import Core.Inventory.Types.Inventory
  ( InventoryResult(..)
  , InventoryStatus(..)
  )
import Core.Refined (NonNegDouble)
import Data.Aeson (FromJSON, ToJSON)
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (Day, UTCTime)
import GHC.Generics (Generic)
import qualified Data.List as List

-- | Inventory document persisted in PostgreSQL
data InventoryDocument = InventoryDocument
  { invDocId :: Int64
  , invDocCode :: Text
  , invDocDate :: Day
  , invDocWarehouseId :: Int64
  , invDocStatus :: InventoryStatus
  , invDocMemo :: Maybe Text
  , invDocCreatedBy :: Maybe Int64
  , invDocCreatedAt :: Maybe UTCTime
  , invDocUpdatedAt :: Maybe UTCTime
  }
  deriving (Eq, Show, Generic)

instance FromJSON InventoryDocument
instance ToJSON InventoryDocument

-- | Input payload for inventory document creation
data InventoryDocumentInput = InventoryDocumentInput
  { idiCode :: Text
  , idiDate :: Day
  , idiWarehouseId :: Int64
  , idiMemo :: Maybe Text
  , idiCreatedBy :: Maybe Int64
  }
  deriving (Eq, Show, Generic)

instance FromJSON InventoryDocumentInput
instance ToJSON InventoryDocumentInput

-- | Document with lines (DTO used by API)
data InventoryDocumentDetail = InventoryDocumentDetail
  { iddDocument :: InventoryDocument
  , iddLines :: [InventoryLine]
  , iddSummary :: Maybe InventorySummary
  }
  deriving (Eq, Show, Generic)

instance FromJSON InventoryDocumentDetail
instance ToJSON InventoryDocumentDetail

-- | Single inventory line stored in the database
data InventoryLine = InventoryLine
  { ilId :: Int64
  , ilInventoryId :: Int64
  , ilLineNo :: Int
  , ilGoodsId :: Int64
  , ilUnitId :: Maybe Int64
  , ilExpectedQtty :: Double
  , ilActualQtty :: Double
  , ilDiffQtty :: Double
  , ilDiffAmount :: Double
  , ilPrice :: Double
  , ilFlags :: Int
  }
  deriving (Eq, Show, Generic)

instance FromJSON InventoryLine
instance ToJSON InventoryLine

-- | Line input coming from API client
data InventoryLineInput = InventoryLineInput
  { iliInventoryId :: Int64
  , iliLineNo :: Int
  , iliGoodsId :: Int64
  , iliUnitId :: Maybe Int64
  , iliExpectedQtty :: Double
  , iliActualQtty :: Double
  , iliPrice :: Double
  }
  deriving (Eq, Show, Generic)

instance FromJSON InventoryLineInput
instance ToJSON InventoryLineInput

-- | Aggregated inventory totals
data InventorySummary = InventorySummary
  { isSummaryBooked :: Double
  , isSummaryFact :: Double
  , isSummaryDiff :: Double
  , isSummarySurplus :: Double
  , isSummaryShortage :: Double
  , isSummaryItemCount :: Int
  , isSummarySurplusCount :: Int
  , isSummaryShortageCount :: Int
  , isSummaryExactCount :: Int
  }
  deriving (Eq, Show, Generic)

instance FromJSON InventorySummary
instance ToJSON InventorySummary

{-@ measure inventoryLineDiffField @-}
inventoryLineDiffField :: InventoryLine -> Double
inventoryLineDiffField = ilDiffQtty

{-@ inventoryLineDiff :: expected:NonNegDouble -> actual:NonNegDouble -> {v:Double | v == actual - expected} @-}
inventoryLineDiff :: Double -> Double -> Double
inventoryLineDiff expected actual = actual - expected

{-@ inventorySummary :: ls:[InventoryLine] -> {v:InventorySummary | isSummaryDiff v == sumDiff ls} @-}
inventorySummary :: [InventoryLine] -> InventorySummary
inventorySummary ls = InventorySummary
  { isSummaryBooked = totalBooked
  , isSummaryFact = totalFact
  , isSummaryDiff = sumDiff ls
  , isSummarySurplus = sumSurplus ls
  , isSummaryShortage = sumShortage ls
  , isSummaryItemCount = length ls
  , isSummarySurplusCount = count (> 0) ls
  , isSummaryShortageCount = count (< 0) ls
  , isSummaryExactCount = count (== 0) ls
  }
  where
    totalBooked = List.foldl' (+) 0 (map ilExpectedQtty ls)
    totalFact = List.foldl' (+) 0 (map ilActualQtty ls)
    count p = length (filter (p . ilDiffQtty) ls)

{-@ sumDiff :: [InventoryLine] -> Double @-}
sumDiff :: [InventoryLine] -> Double
sumDiff [] = 0
sumDiff (l : ls) = inventoryLineDiffField l + sumDiff ls

sumSurplus :: [InventoryLine] -> Double
sumSurplus = List.foldl' (+) 0 . map (max 0 . ilDiffQtty)

sumShortage :: [InventoryLine] -> Double
sumShortage = List.foldl' (+) 0 . map (negate . min 0 . ilDiffQtty)

inventoryLineResult :: InventoryLine -> InventoryResult
inventoryLineResult InventoryLine {..}
  | ilDiffQtty > 0 = IR_Overage
  | ilDiffQtty < 0 = IR_Shortage
  | otherwise = IR_Match

validateInventoryDocumentInput :: InventoryDocumentInput -> Either Text InventoryDocumentInput
validateInventoryDocumentInput input@InventoryDocumentInput {..}
  | T.null idiCode = Left "inventory code cannot be empty"
  | idiWarehouseId <= 0 = Left "warehouse id must be positive"
  | otherwise = Right input

validateInventoryLineInput :: InventoryLineInput -> Either Text InventoryLineInput
validateInventoryLineInput input@InventoryLineInput {..}
  | iliExpectedQtty < 0 = Left "expected quantity cannot be negative"
  | iliActualQtty < 0 = Left "actual quantity cannot be negative"
  | iliPrice < 0 = Left "price cannot be negative"
  | otherwise = Right input
