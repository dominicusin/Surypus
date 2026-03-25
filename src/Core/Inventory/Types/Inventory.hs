{-# LANGUAGE DeriveGeneric #-}

-- | Inventory types - Stock counts and inventories
module Core.Inventory.Types.Inventory where

import Data.Aeson (FromJSON, ToJSON)
import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (Day)
import GHC.Generics (Generic)

-- | Inventory - Stock count/check document
data Inventory = Inventory
  { invId :: Int64,
    invCode :: Text,
    invDate :: Day,
    invLocationId :: Int64,
    invStatus :: InventoryStatus,
    invStartDate :: Maybe Day,
    invEndDate :: Maybe Day,
    invNotes :: Text
  }
  deriving (Show, Eq)

-- | Inventory status
data InventoryStatus
  = ISDraft -- Черновик (0)
  | ISInProgress -- В процессе (1)
  | ISCounted -- Подсчитано (2)
  | ISAnalyzed -- Проанализировано (3)
  | ISApproved -- Утверждено (4)
  | ISCompleted -- Завершена (5)
  | ISCancelled -- Отменена (6)
  deriving (Show, Eq, Enum, Generic)

instance ToJSON InventoryStatus

instance FromJSON InventoryStatus

-- | Inventory line - actual vs expected
data InventoryLine = InventoryLine
  { ilId :: Int64,
    ilInventoryId :: Int64,
    ilGoodsId :: Int64,
    ilLotId :: Maybe Int64,
    ilExpectedQtty :: Double, -- Expected quantity (по учету)
    ilActualQtty :: Double, -- Actual quantity (по факту)
    ilDiffQtty :: Double -- Difference (ilActual - ilExpected)
  }
  deriving (Show, Eq)

-- | Inventory result
data InventoryResult
  = IRMatch -- Quantity matches
  | IROverage -- More than expected (излишек)
  | IRShortage -- Less than expected (недостача)
  deriving (Show, Eq)
