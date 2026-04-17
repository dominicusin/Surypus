{-# LANGUAGE ConstraintKinds #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleInstances #-}
-- ============================================================================
-- Inventory Domain Formal Model
-- ============================================================================
-- Formal specification of inventory operations with invariants
-- ============================================================================
{-# LANGUAGE GADTs #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE StandaloneDeriving #-}
{-# LANGUAGE TypeFamilies #-}

module Surypus.Formal.Inventory where

import Data.List (sortOn)
import Data.Map (Map)
import qualified Data.Map as M
import Data.Ord (Down (..))
import Data.UUID (UUID)
import Surypus.Formal.EventStore

-- ============================================================================
-- DOMAIN TYPES
-- ============================================================================

-- Goods identifier
newtype GoodsId = GoodsId {unGoodsId :: UUID}
  deriving (Eq, Ord, Show)

-- Location identifier
newtype LocationId = LocationId {unLocationId :: UUID}
  deriving (Eq, Ord, Show)

-- Lot identifier
newtype LotId = LotId {unLotId :: UUID}
  deriving (Eq, Ord, Show)

-- Quantity (must be non-negative)
newtype Quantity = Quantity {unQuantity :: Double}
  deriving (Eq, Ord)

instance Show Quantity where
  show (Quantity q) = "Quantity " ++ show q

-- Smart constructor for Quantity
mkQuantity :: Double -> Maybe Quantity
mkQuantity q
  | q >= 0 = Just $ Quantity q
  | otherwise = Nothing

-- Cost (must be non-negative)
newtype Cost = Cost {unCost :: Double}
  deriving (Eq, Ord)

mkCost :: Double -> Maybe Cost
mkCost c
  | c >= 0 = Just $ Cost c
  | otherwise = Nothing

-- ============================================================================
-- LOT DOMAIN
-- ============================================================================

data Lot = Lot
  { lotId :: LotId,
    lotGoodsId :: GoodsId,
    lotLocationId :: LocationId,
    lotQty :: Quantity,
    lotRemaining :: Quantity,
    lotCost :: Cost,
    lotCreatedAt :: UTCTime
  }
  deriving (Show, Eq)

-- Invariant: remaining <= received
lotInvariant :: Lot -> Bool
lotInvariant lot =
  unQuantity (lotRemaining lot) <= unQuantity (lotQty lot)
    && unQuantity (lotRemaining lot) >= 0

-- ============================================================================
-- INVENTORY AGGREGATE
-- ============================================================================

-- Stock key for lookup
data StockKey = StockKey
  { skGoodsId :: GoodsId,
    skLocationId :: LocationId
  }
  deriving (Eq, Ord, Show)

-- Stock aggregate
data Stock = Stock
  { stockKey :: StockKey,
    stockLots :: Map LotId Lot,
    stockCurrent :: Quantity,
    stockReserved :: Quantity
  }
  deriving (Show, Eq)

-- Calculate available quantity
stockAvailable :: Stock -> Quantity
stockAvailable stock = Quantity (unQuantity (stockCurrent stock) - unQuantity (stockReserved stock))

-- Stock invariants
stockInvariant :: Stock -> Bool
stockInvariant stock =
  unQuantity (stockCurrent stock) >= 0
    && unQuantity (stockReserved stock) >= 0
    && unQuantity (stockReserved stock) <= unQuantity (stockCurrent stock)
    && all lotInvariant (M.elems (stockLots stock))
    &&
    -- Sum of lot quantities equals current stock
    abs (unQuantity (stockCurrent stock) - sum (map (unQuantity . lotRemaining) (M.elems (stockLots stock)))) < 0.001

-- ============================================================================
-- COMMANDS
-- ============================================================================

data InventoryCommand
  = ReceiveStock
      { rcGoodsId :: GoodsId,
        rcLocationId :: LocationId,
        rcQty :: Quantity,
        rcCost :: Cost,
        rcLotNumber :: Maybe Text
      }
  | IssueStock
      { isGoodsId :: GoodsId,
        isLocationId :: LocationId,
        isQty :: Quantity,
        isMethod :: IssueMethod
      }
  | ReserveStock
      { rsGoodsId :: GoodsId,
        rsLocationId :: LocationId,
        rsQty :: Quantity
      }
  | ReleaseStock
      { relGoodsId :: GoodsId,
        relLocationId :: LocationId,
        relQty :: Quantity
      }
  | AdjustStock
      { adjGoodsId :: GoodsId,
        adjLocationId :: LocationId,
        adjDelta :: Quantity, -- Can be negative
        adjReason :: Text
      }
  deriving (Show)

data IssueMethod = FIFO | LIFO | FEFO -- First Expired First Out
  deriving (Show, Eq)

-- ============================================================================
-- COMMAND VALIDATION
-- ============================================================================

validateCommand :: InventoryCommand -> Either InvariantViolation ()
validateCommand cmd = case cmd of
  ReceiveStock {..} -> Right ()
  IssueStock {..} ->
    if unQuantity isQty <= 0
      then Left $ InvalidOperation "Issue quantity must be positive"
      else Right ()
  ReserveStock {..} ->
    if unQuantity rsQty <= 0
      then Left $ InvalidOperation "Reserve quantity must be positive"
      else Right ()
  ReleaseStock {..} ->
    if unQuantity relQty <= 0
      then Left $ InvalidOperation "Release quantity must be positive"
      else Right ()
  AdjustStock {..} -> Right ()

-- ============================================================================
-- COMMAND EXECUTION
-- ============================================================================

executeCommand :: Stock -> InventoryCommand -> Either InvariantViolation (Stock, [Event 'Inventory])
executeCommand stock cmd = case cmd of
  ReceiveStock {..} -> receiveStock stock rcGoodsId rcLocationId rcQty rcCost
  IssueStock {..} -> issueStock stock isGoodsId isLocationId isQty isMethod
  ReserveStock {..} -> reserveStock stock rsGoodsId rsLocationId rsQty
  ReleaseStock {..} -> releaseStock stock relGoodsId relLocationId relQty
  AdjustStock {..} -> adjustStock stock adjGoodsId adjLocationId adjDelta

-- Receive stock - creates new lot
receiveStock :: Stock -> GoodsId -> LocationId -> Quantity -> Cost -> Either InvariantViolation (Stock, [Event 'Inventory])
receiveStock stock goodsId locationId qty cost = do
  -- Validate
  validateCommand (ReceiveStock goodsId locationId qty cost Nothing)

  -- Create lot
  let lotId = undefined -- Would generate UUID
      newLot =
        Lot
          { lotId = lotId,
            lotGoodsId = goodsId,
            lotLocationId = locationId,
            lotQty = qty,
            lotRemaining = qty,
            lotCost = cost,
            lotCreatedAt = undefined -- Would use current time
          }

  -- Update stock
  let newStock =
        stock
          { stockLots = M.insert lotId newLot (stockLots stock),
            stockCurrent = Quantity (unQuantity (stockCurrent stock) + unQuantity qty)
          }

  -- Create events
  let events = [StockReceived] -- Simplified

  -- Check invariants
  if stockInvariant newStock
    then Right (newStock, events)
    else Left $ InvalidOperation "Stock invariant violated after receive"

-- Issue stock using FIFO
issueStock :: Stock -> GoodsId -> LocationId -> Quantity -> IssueMethod -> Either InvariantViolation (Stock, [Event 'Inventory])
issueStock stock goodsId locationId qty method = do
  -- Validate
  validateCommand (IssueStock goodsId locationId qty method)

  -- Check available stock
  let available = stockAvailable stock
  if unQuantity qty > unQuantity available
    then Left $ InsufficientStock (unQuantity qty) (unQuantity available)
    else do
      -- Select lots using FIFO
      let sortedLots = case method of
            FIFO -> sortOn lotCreatedAt (M.elems (stockLots stock))
            LIFO -> sortOn (Down . lotCreatedAt) (M.elems (stockLots stock))
            FEFO -> undefined -- Sort by expiry date

      -- Consume lots
      (consumedLots, remainingQty, newLots) <- consumeLots qty sortedLots []

      -- Update stock
      let newStock =
            stock
              { stockLots = M.fromList [(lotId l, l) | l <- newLots],
                stockCurrent = Quantity (unQuantity (stockCurrent stock) - unQuantity qty)
              }

      -- Create events
      let events = map (\_ -> StockIssued) consumedLots -- Simplified

      -- Check invariants
      if stockInvariant newStock
        then Right (newStock, events)
        else Left $ InvalidOperation "Stock invariant violated after issue"

-- Consume lots FIFO style
consumeLots :: Quantity -> [Lot] -> [Lot] -> Either InvariantViolation ([Lot], Quantity, [Lot])
consumeLots (Quantity 0) _ acc = Right (acc, Quantity 0, [])
consumeLots _ [] acc = Right (acc, Quantity 0, [])
consumeLots qty@(Quantity remaining) (lot : lots) acc =
  let lotRem = unQuantity (lotRemaining lot)
      useQty = min remaining lotRem
      newRem = lotRem - useQty
      newLot = lot {lotRemaining = Quantity newRem}
      acc' = if useQty > 0 then lot : acc else acc
   in if remaining <= lotRem
        then Right (acc', Quantity 0, if newRem > 0 then newLot : lots else lots)
        else consumeLots (Quantity (remaining - useQty)) lots acc'

-- Reserve stock
reserveStock :: Stock -> GoodsId -> LocationId -> Quantity -> Either InvariantViolation (Stock, [Event 'Inventory])
reserveStock stock goodsId locationId qty = do
  validateCommand (ReserveStock goodsId locationId qty)

  let available = stockAvailable stock
  if unQuantity qty > unQuantity available
    then Left $ InsufficientStock (unQuantity qty) (unQuantity available)
    else do
      let newStock = stock {stockReserved = Quantity (unQuantity (stockReserved stock) + unQuantity qty)}
      if stockInvariant newStock
        then Right (newStock, [StockReserved])
        else Left $ InvalidOperation "Stock invariant violated after reserve"

-- Release stock
releaseStock :: Stock -> GoodsId -> LocationId -> Quantity -> Either InvariantViolation (Stock, [Event 'Inventory])
releaseStock stock goodsId locationId qty = do
  validateCommand (ReleaseStock goodsId locationId qty)

  if unQuantity qty > unQuantity (stockReserved stock)
    then Left $ InsufficientStock (unQuantity qty) (unQuantity (stockReserved stock))
    else do
      let newStock = stock {stockReserved = Quantity (unQuantity (stockReserved stock) - unQuantity qty)}
      if stockInvariant newStock
        then Right (newStock, [StockReleased])
        else Left $ InvalidOperation "Stock invariant violated after release"

-- Adjust stock
adjustStock :: Stock -> GoodsId -> LocationId -> Quantity -> Either InvariantViolation (Stock, [Event 'Inventory])
adjustStock stock goodsId locationId (Quantity delta) = do
  validateCommand (AdjustStock goodsId locationId (Quantity delta) "")

  let newCurrent = unQuantity (stockCurrent stock) + delta
  if newCurrent < 0
    then Left $ NegativeQuantity newCurrent
    else do
      let newStock = stock {stockCurrent = Quantity newCurrent}
      if stockInvariant newStock
        then Right (newStock, [StockAdjusted])
        else Left $ InvalidOperation "Stock invariant violated after adjust"

-- ============================================================================
-- FIFO INVARIANTS
-- ============================================================================

-- Property: FIFO consumption preserves order
prop_fifoOrder :: [Lot] -> Quantity -> Bool
prop_fifoOrder lots qty =
  let sortedLots = sortOn lotCreatedAt lots
      result = consumeLots qty sortedLots []
   in case result of
        Left _ -> True -- Error case - property holds vacuously
        Right (consumed, _, _) ->
          let dates = map lotCreatedAt consumed
           in dates == sortOn id dates

-- Property: Total quantity is conserved
prop_quantityConserved :: Stock -> InventoryCommand -> Bool
prop_quantityConserved stock cmd =
  case executeCommand stock cmd of
    Left _ -> True
    Right (newStock, _) ->
      let oldTotal = sum $ map (unQuantity . lotRemaining) $ M.elems $ stockLots stock
          newTotal = sum $ map (unQuantity . lotRemaining) $ M.elems $ stockLots newStock
       in case cmd of
            ReceiveStock {..} -> abs (newTotal - oldTotal - unQuantity rcQty) < 0.001
            IssueStock {..} -> abs (oldTotal - newTotal - unQuantity isQty) < 0.001
            _ -> True -- Other commands don't change lot quantities

-- Property: Available is always non-negative
prop_availableNonNegative :: Stock -> Bool
prop_availableNonNegative stock =
  unQuantity (stockAvailable stock) >= 0

-- Property: Cannot issue more than available
prop_cannotOverIssue :: Stock -> Quantity -> Bool
prop_cannotOverIssue stock qty =
  unQuantity qty <= unQuantity (stockAvailable stock)
    || case issueStock stock (GoodsId undefined) (LocationId undefined) qty FIFO of
      Left _ -> True
      Right _ -> False

-- ============================================================================
-- PROJECTION: Stock Balance
-- ============================================================================

-- Read model for stock balance
data StockBalanceRM = StockBalanceRM
  { rmGoodsId :: GoodsId,
    rmLocationId :: LocationId,
    rmCurrentQty :: Double,
    rmReservedQty :: Double,
    rmAvgCost :: Double
  }
  deriving (Show, Eq)

-- Project events to read model
projectStockBalance :: StockBalanceRM -> Event 'Inventory -> StockBalanceRM
projectStockBalance rm event = case evtType event of
  StockReceived -> rm {rmCurrentQty = rmCurrentQty rm + qty}
    where
      qty = 0 -- Parse from event data
  StockIssued -> rm {rmCurrentQty = rmCurrentQty rm - qty}
    where
      qty = 0 -- Parse from event data
  StockReserved -> rm {rmReservedQty = rmReservedQty rm + qty}
    where
      qty = 0 -- Parse from event data
  StockReleased -> rm {rmReservedQty = rmReservedQty rm - qty}
    where
      qty = 0 -- Parse from event data
  StockAdjusted -> rm {rmCurrentQty = rmCurrentQty rm + adj}
    where
      adj = 0 -- Parse from event data
  _ -> rm

-- ============================================================================
-- PROJECTION: FIFO Lots
-- ============================================================================

-- Read model for FIFO lots
data FifoLotsRM = FifoLotsRM
  { flLots :: [(LotId, Double, Cost)] -- (LotId, Remaining, Cost)
  }
  deriving (Show, Eq)

-- Project events to FIFO lots
projectFifoLots :: FifoLotsRM -> Event 'Inventory -> FifoLotsRM
projectFifoLots rm event = case evtType event of
  LotCreated -> rm {flLots = flLots rm ++ [(lotId, qty, cost)]}
    where
      lotId = undefined; qty = 0; cost = Cost 0
  LotConsumed -> rm {flLots = updateLots (flLots rm) lotId qty}
    where
      lotId = undefined; qty = 0
  _ -> rm
  where
    updateLots lots targetId consumedQty =
      map
        ( \(lid, rem, c) ->
            if lid == targetId
              then (lid, max 0 (rem - consumedQty), c)
              else (lid, rem, c)
        )
        lots
