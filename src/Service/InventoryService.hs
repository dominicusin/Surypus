-- | Inventory Service — orchestrates inventory/stock operations
-- Patch F: Inventory lifecycle (receipts, issues, adjustments, inventory)
{-# LANGUAGE OverloadedStrings #-}
module Service.InventoryService where

import qualified Data.List as L
import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (Day, getCurrentTime)
import Inventory.Stock

-- | Inventory document type
data InventoryDocType
  = IDTReceipt      -- Поступление товаров
  | IDTIssue        -- Списание товаров
  | IDTTransfer     -- Перемещение между складами
  | IDTWriteOff     -- Списание потерь
  | IDTAdjustment   -- Корректировка остатков
  deriving (Show, Eq)

-- | Inventory document status
data InventoryDocStatus
  = IDSDraft
  | IDSApproved
  | IDSPosted
  | IDSArchived
  deriving (Show, Eq, Enum)

-- | Inventory document line
data InventoryDocLine = InventoryDocLine
  { idlGoodsId :: Int64
  , idlLocationId :: Int64
  , idlQty :: Double
  , idlCost :: Double
  , idlPrice :: Double
  } deriving (Show, Eq)

-- | Inventory document
data InventoryDoc = InventoryDoc
  { idId :: Int64
  , idDocType :: InventoryDocType
  , idStatus :: InventoryDocStatus
  , idDate :: Day
  , idLines :: [InventoryDocLine]
  , idDescription :: Text
  }

-- | Stock movement record
data StockMovement = StockMovement
  { smGoodsId :: Int64
  , smFromLocation :: Maybe Int64
  , smToLocation :: Maybe Int64
  , smQty :: Double
  , smType :: StockMotionType
  }

-- | Post inventory document — apply stock movements
postInventoryDoc :: InventoryDoc -> IO (Either Text [StockMovement])
postInventoryDoc doc = do
  let status = idStatus doc
  if status /= IDSApproved && status /= IDSDraft
    then pure $ Left "Only draft or approved documents can be posted"
    else do
      let movements = generateMovements doc
      pure $ Right movements

-- | Generate stock movements from inventory document lines
generateMovements :: InventoryDoc -> [StockMovement]
generateMovements doc =
  case idDocType doc of
    IDTReceipt -> map receiptMovement (idLines doc)
    IDTIssue   -> map issueMovement (idLines doc)
    IDTTransfer -> concatMap transferMovements (idLines doc)
    IDTWriteOff -> map writeOffMovement (idLines doc)
    IDTAdjustment -> map adjustmentMovement (idLines doc)
  where
    receiptMovement line = StockMovement
      { smGoodsId = idlGoodsId line
      , smFromLocation = Nothing
      , smToLocation = Just (idlLocationId line)
      , smQty = abs (idlQty line)
      , smType = SMTReceipt
      }
    issueMovement line = StockMovement
      { smGoodsId = idlGoodsId line
      , smFromLocation = Just (idlLocationId line)
      , smToLocation = Nothing
      , smQty = -abs (idlQty line)
      , smType = SMTShipment
      }
    transferMovements line =
      [ StockMovement
          { smGoodsId = idlGoodsId line
          , smFromLocation = Just (idlLocationId line)
          , smToLocation = Nothing
          , smQty = -abs (idlQty line)
          , smType = SMTTransferOut
          }
      , StockMovement
          { smGoodsId = idlGoodsId line
          , smFromLocation = Nothing
          , smToLocation = Just (idlLocationId line)
          , smQty = abs (idlQty line)
          , smType = SMTTransferIn
          }
      ]
    writeOffMovement line = StockMovement
      { smGoodsId = idlGoodsId line
      , smFromLocation = Just (idlLocationId line)
      , smToLocation = Nothing
      , smQty = -abs (idlQty line)
      , smType = SMTWriteOff
      }
    adjustmentMovement line = StockMovement
      { smGoodsId = idlGoodsId line
      , smFromLocation = Just (idlLocationId line)
      , smToLocation = Just (idlLocationId line)
      , smQty = idlQty line  -- can be positive or negative
      , smType = SMTAdjustment
      }

-- | Calculate stock balance after applying movements
calculateStockBalance :: [Stock] -> [StockMovement] -> [Stock]
calculateStockBalance initialStocks movements =
  L.foldl' applyMovement initialStocks movements

applyMovement :: [Stock] -> StockMovement -> [Stock]
applyMovement stocks movement = case lookupStock stocks of
  Nothing -> stocks  -- No existing stock entry, skip
  Just (idx, existing) ->
    let updated = existing { sQtty = sQtty existing + smQty movement }
    in replaceAt idx updated stocks
  where
    lookupStock s = case filter (\s' -> sGoodsId s' == smGoodsId movement) s of
      (found : _) | sLocationId found == fromMaybe 0 (smFromLocation movement)
                  || sLocationId found == fromMaybe 0 (smToLocation movement)
        -> Nothing -- Simplified: find proper match
      _ -> Nothing

replaceAt :: Int -> Stock -> [Stock] -> [Stock]
replaceAt 0 x (_ : rest) = x : rest
replaceAt n x (y : rest) = y : replaceAt (n - 1) x rest
replaceAt _ _ [] = []

fromMaybe :: a -> Maybe a -> a
fromMaybe d Nothing = d
fromMaybe _ (Just x) = x