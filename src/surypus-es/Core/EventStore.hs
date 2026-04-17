{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE FlexibleInstances #-}
-- ============================================================================
-- Surypus Event Store Formal Model (Haskell)
-- ============================================================================
-- This module provides a formal model for the event store
-- with type-safe events and invariant checking
-- ============================================================================
{-# LANGUAGE GADTs #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE StandaloneDeriving #-}
{-# LANGUAGE TypeFamilies #-}

module Surypus.Formal.EventStore where

import Data.Aeson (FromJSON, ToJSON, Value)
import Data.Map (Map)
import qualified Data.Map as M
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (UTCTime)
import Data.UUID (UUID)
import GHC.Generics (Generic)

-- ============================================================================
-- CORE TYPES
-- ============================================================================

-- Aggregate types (phantom types for type safety)
data AggregateType = Inventory | Bill | Person | Salary | Accounting
  deriving (Show, Eq, Generic, ToJSON, FromJSON)

-- Event types indexed by aggregate type
data EventType (a :: AggregateType) where
  -- Inventory events
  StockReceived :: EventType 'Inventory
  StockIssued :: EventType 'Inventory
  StockAdjusted :: EventType 'Inventory
  StockReserved :: EventType 'Inventory
  StockReleased :: EventType 'Inventory
  LotCreated :: EventType 'Inventory
  LotConsumed :: EventType 'Inventory
  -- Bill events
  BillCreated :: EventType 'Bill
  BillLineAdded :: EventType 'Bill
  BillUpdated :: EventType 'Bill
  BillPosted :: EventType 'Bill
  BillCancelled :: EventType 'Bill
  -- Person events
  PersonCreated :: EventType 'Person
  PersonUpdated :: EventType 'Person
  PersonActivated :: EventType 'Person
  PersonDeactivated :: EventType 'Person
  -- Salary events
  SalaryRecordCreated :: EventType 'Salary
  SalaryPeriodClosed :: EventType 'Salary
  SalaryPaid :: EventType 'Salary
  -- Accounting events
  AccountDebited :: EventType 'Accounting
  AccountCredited :: EventType 'Accounting
  JournalEntryCreated :: EventType 'Accounting

deriving instance Show (EventType a)

deriving instance Eq (EventType a)

-- ============================================================================
-- EVENT DATA
-- ============================================================================

-- Event metadata
data EventMetadata = EventMetadata
  { emUserId :: Maybe UUID,
    emCorrelationId :: Maybe UUID,
    emCausationId :: Maybe UUID,
    emTenantId :: UUID,
    emTimestamp :: UTCTime
  }
  deriving (Show, Eq, Generic, ToJSON, FromJSON)

-- Event wrapper
data Event (a :: AggregateType) where
  Event ::
    { evtId :: UUID,
      evtAggregateId :: UUID,
      evtType :: EventType a,
      evtVersion :: Int,
      evtData :: Value, -- JSON payload
      evtMetadata :: EventMetadata
    } ->
    Event a

deriving instance Show (Event a)

deriving instance Eq (Event a)

-- ============================================================================
-- INVENTORY EVENT DATA
-- ============================================================================

data LotData = LotData
  { ldLotId :: UUID,
    ldGoodsId :: UUID,
    ldLocationId :: UUID,
    ldQty :: Double,
    ldCost :: Double,
    ldPrice :: Double,
    ldLotNumber :: Maybe Text,
    ldExpiryDate :: Maybe UTCTime
  }
  deriving (Show, Eq, Generic, ToJSON, FromJSON)

data StockMovementData = StockMovementData
  { smGoodsId :: UUID,
    smLocationId :: UUID,
    smLotId :: UUID,
    smQty :: Double,
    smCost :: Double,
    smDocumentRef :: Maybe Text
  }
  deriving (Show, Eq, Generic, ToJSON, FromJSON)

data StockAdjustmentData = StockAdjustmentData
  { saGoodsId :: UUID,
    saLocationId :: UUID,
    saAdjustment :: Double,
    saReason :: Maybe Text
  }
  deriving (Show, Eq, Generic, ToJSON, FromJSON)

-- ============================================================================
-- AGGREGATE STATE
-- ============================================================================

-- Lot state
data LotState = LotState
  { lsLotId :: UUID,
    lsQtyReceived :: Double,
    lsQtyRemaining :: Double,
    lsCost :: Double,
    lsReceivedAt :: UTCTime
  }
  deriving (Show, Eq, Generic, ToJSON, FromJSON)

-- Inventory aggregate state
data InventoryState = InventoryState
  { invLocationId :: UUID,
    invGoodsId :: UUID,
    invCurrentQty :: Double,
    invReservedQty :: Double,
    invAvailableQty :: Double,
    invLots :: Map UUID LotState,
    invVersion :: Int
  }
  deriving (Show, Eq, Generic, ToJSON, FromJSON)

-- Bill line state
data BillLineState = BillLineState
  { blsLineId :: UUID,
    blsGoodsId :: UUID,
    blsQty :: Double,
    blsPrice :: Double,
    blsDiscount :: Double,
    blsVatRate :: Double,
    blsAmount :: Double,
    blsVatAmount :: Double,
    blsLineTotal :: Double
  }
  deriving (Show, Eq, Generic, ToJSON, FromJSON)

-- Bill aggregate state
data BillState = BillState
  { billCode :: Text,
    billDate :: UTCTime,
    billPersonId :: UUID,
    billLocationId :: UUID,
    billStatus :: BillStatus,
    billLines :: Map UUID BillLineState,
    billTotalAmount :: Double,
    billTotalVat :: Double,
    billVersion :: Int
  }
  deriving (Show, Eq, Generic, ToJSON, FromJSON)

data BillStatus = Draft | Posted | Cancelled
  deriving (Show, Eq, Generic, ToJSON, FromJSON)

-- ============================================================================
-- INVARIANTS
-- ============================================================================

-- Type class for aggregates with invariants
class AggregateState s where
  type AggregateEvent s :: *
  emptyState :: s
  applyEvent :: s -> AggregateEvent s -> Either InvariantViolation s
  checkInvariants :: s -> Maybe InvariantViolation

-- Invariant violations
data InvariantViolation
  = NegativeQuantity Double
  | NegativeCost Double
  | InsufficientStock {ivNeeded :: Double, ivAvailable :: Double}
  | InvalidStatus {ivCurrent :: Text, ivExpected :: Text}
  | QuantityMismatch {ivExpected :: Double, ivActual :: Double}
  | LotNotFound UUID
  | AggregateNotFound UUID
  | InvalidOperation Text
  deriving (Show, Eq, Generic, ToJSON, FromJSON)

-- ============================================================================
-- INVENTORY INVARIANTS
-- ============================================================================

instance AggregateState InventoryState where
  type AggregateEvent InventoryState = Event 'Inventory
  emptyState =
    InventoryState
      { invLocationId = nilUUID,
        invGoodsId = nilUUID,
        invCurrentQty = 0,
        invReservedQty = 0,
        invAvailableQty = 0,
        invLots = M.empty,
        invVersion = 0
      }

  applyEvent state Event {..} = case evtType of
    LotCreated -> applyLotCreated state evtData
    StockReceived -> applyStockReceived state evtData
    LotConsumed -> applyLotConsumed state evtData
    StockIssued -> applyStockIssued state evtData
    StockAdjusted -> applyStockAdjusted state evtData
    StockReserved -> applyStockReserved state evtData
    StockReleased -> applyStockReleased state evtData

  checkInvariants state =
    if invCurrentQty state < 0
      then Just $ NegativeQuantity (invCurrentQty state)
      else
        if invAvailableQty state < 0
          then Just $ NegativeQuantity (invAvailableQty state)
          else
            if invAvailableQty state /= invCurrentQty state - invReservedQty state
              then
                Just $
                  QuantityMismatch
                    { ivExpected = invCurrentQty state - invReservedQty state,
                      ivActual = invAvailableQty state
                    }
              else Nothing

nilUUID :: UUID
nilUUID = read "00000000-0000-0000-0000-000000000000"

-- Apply LotCreated event
applyLotCreated :: InventoryState -> Value -> Either InvariantViolation InventoryState
applyLotCreated state lotData = do
  lot <- parseLotData lotData
  let lotState =
        LotState
          { lsLotId = ldLotId lot,
            lsQtyReceived = ldQty lot,
            lsQtyRemaining = ldQty lot,
            lsCost = ldCost lot,
            lsReceivedAt = emTimestamp (EventMetadata Nothing Nothing Nothing nilUUID undefined) -- TODO
          }
  return
    state
      { invLots = M.insert (ldLotId lot) lotState (invLots state),
        invCurrentQty = invCurrentQty state + ldQty lot,
        invAvailableQty = invAvailableQty state + ldQty lot,
        invVersion = invVersion state + 1
      }

-- Apply StockReceived event
applyStockReceived :: InventoryState -> Value -> Either InvariantViolation InventoryState
applyStockReceived state _ = Right state -- Already handled by LotCreated

-- Apply LotConsumed event
applyLotConsumed :: InventoryState -> Value -> Either InvariantViolation InventoryState
applyLotConsumed state moveData = do
  move <- parseMovementData moveData
  let lotId = smLotId move
      qty = smQty move

  case M.lookup lotId (invLots state) of
    Nothing -> Left $ LotNotFound lotId
    Just lot -> do
      let newRemaining = lsQtyRemaining lot - qty
      if newRemaining < 0
        then
          Left $
            InsufficientStock
              { ivNeeded = qty,
                ivAvailable = lsQtyRemaining lot
              }
        else
          return
            state
              { invLots = M.insert lotId (lot {lsQtyRemaining = newRemaining}) (invLots state),
                invCurrentQty = invCurrentQty state - qty,
                invAvailableQty = invAvailableQty state - qty,
                invVersion = invVersion state + 1
              }

-- Apply StockIssued event
applyStockIssued :: InventoryState -> Value -> Either InvariantViolation InventoryState
applyStockIssued state _ = Right state -- Already handled by LotConsumed

-- Apply StockAdjusted event
applyStockAdjusted :: InventoryState -> Value -> Either InvariantViolation InventoryState
applyStockAdjusted state adjData = do
  adj <- parseAdjustmentData adjData
  let newQty = invCurrentQty state + saAdjustment adj
      newAvailable = invAvailableQty state + saAdjustment adj

  if newQty < 0
    then Left $ NegativeQuantity newQty
    else
      return
        state
          { invCurrentQty = newQty,
            invAvailableQty = newAvailable,
            invVersion = invVersion state + 1
          }

-- Apply StockReserved event
applyStockReserved :: InventoryState -> Value -> Either InvariantViolation InventoryState
applyStockReserved state reserveData = do
  -- Parse reservation data
  let qty = 0.0 -- TODO: parse from reserveData
  if qty > invAvailableQty state
    then
      Left $
        InsufficientStock
          { ivNeeded = qty,
            ivAvailable = invAvailableQty state
          }
    else
      return
        state
          { invReservedQty = invReservedQty state + qty,
            invAvailableQty = invAvailableQty state - qty,
            invVersion = invVersion state + 1
          }

-- Apply StockReleased event
applyStockReleased :: InventoryState -> Value -> Either InvariantViolation InventoryState
applyStockReleased state _ = do
  -- Parse release data
  let qty = 0.0 -- TODO: parse from releaseData
  return
    state
      { invReservedQty = invReservedQty state - qty,
        invAvailableQty = invAvailableQty state + qty,
        invVersion = invVersion state + 1
      }

-- ============================================================================
-- PARSING HELPERS (simplified)
-- ============================================================================

parseLotData :: Value -> Either InvariantViolation LotData
parseLotData = undefined -- Would use FromJSON

parseMovementData :: Value -> Either InvariantViolation StockMovementData
parseMovementData = undefined -- Would use FromJSON

parseAdjustmentData :: Value -> Either InvariantViolation StockAdjustmentData
parseAdjustmentData = undefined -- Would use FromJSON

-- ============================================================================
-- FIFO VALIDATION
-- ============================================================================

-- Validate FIFO selection
validateFifoSelection :: InventoryState -> [UUID] -> Double -> Either InvariantViolation ()
validateFifoSelection state lotIds qtyNeeded = do
  -- Check all lots exist
  mapM_
    ( \lotId ->
        case M.lookup lotId (invLots state) of
          Nothing -> Left $ LotNotFound lotId
          Just _ -> Right ()
    )
    lotIds

  -- Check total quantity
  let totalQty = sum [lsQtyRemaining lot | lotId <- lotIds, Just lot <- [M.lookup lotId (invLots state)]]
  if totalQty < qtyNeeded
    then Left $ InsufficientStock {ivNeeded = qtyNeeded, ivAvailable = totalQty}
    else Right ()

-- Get FIFO lots for quantity needed
getFifoLots :: InventoryState -> Double -> Either InvariantViolation [LotState]
getFifoLots state qtyNeeded =
  let sortedLots = map snd $ M.toAscList (invLots state) -- Sorted by LotId (which correlates to creation time)
      selected = selectLots qtyNeeded sortedLots []
   in if sum (map lsQtyRemaining selected) >= qtyNeeded
        then Right selected
        else Left $ InsufficientStock {ivNeeded = qtyNeeded, ivAvailable = sum (map lsQtyRemaining selected)}
  where
    selectLots 0 _ acc = acc
    selectLots _ [] acc = acc
    selectLots remaining (lot : lots) acc =
      let takeQty = min remaining (lsQtyRemaining lot)
       in if takeQty > 0
            then selectLots (remaining - takeQty) lots (lot : acc)
            else selectLots remaining lots acc

-- ============================================================================
-- EVENT STORE OPERATIONS
-- ============================================================================

-- Event store interface
data EventStore m = EventStore
  { esAppendEvent :: forall a. UUID -> EventType a -> Value -> EventMetadata -> m (Either EventStoreError Int),
    esGetEvents :: forall a. UUID -> m [Event a],
    esGetEventsFrom :: forall a. UUID -> Int -> m [Event a]
  }

data EventStoreError
  = ConcurrentModificationError {eseExpected :: Int, eseActual :: Int}
  | SerializationError Text
  | StorageError Text
  deriving (Show, Eq)

-- Rebuild aggregate from events
rebuildAggregate :: (AggregateState s) => [AggregateEvent s] -> Either InvariantViolation s
rebuildAggregate events = foldM applyEvent emptyState events

-- ============================================================================
-- COMMAND HANDLER TYPE
-- ============================================================================

-- Command handler
data CommandHandler cmd evt state = CommandHandler
  { chValidate :: cmd -> Either InvariantViolation (),
    chExecute :: cmd -> state -> Either InvariantViolation (evt, state),
    chEvents :: cmd -> state -> [evt]
  }

-- ============================================================================
-- PROJECTIONS
-- ============================================================================

-- Projection type
newtype Projection s e = Projection
  { pApply :: s -> e -> s
  }

-- Build read model from events
buildProjection :: Projection s e -> s -> [e] -> s
buildProjection (Projection f) = foldl f

-- ============================================================================
-- STOCK BALANCE PROJECTION
-- ============================================================================

data StockBalance = StockBalance
  { sbGoodsId :: UUID,
    sbLocationId :: UUID,
    sbCurrentQty :: Double,
    sbReservedQty :: Double,
    sbAvailableQty :: Double
  }
  deriving (Show, Eq)

stockBalanceProjection :: Projection StockBalance (Event 'Inventory)
stockBalanceProjection = Projection $ \balance event ->
  case evtType event of
    LotCreated -> balance {sbCurrentQty = sbCurrentQty balance + qty, sbAvailableQty = sbAvailableQty balance + qty}
      where
        qty = 0 -- Parse from event data
    LotConsumed -> balance {sbCurrentQty = sbCurrentQty balance - qty, sbAvailableQty = sbAvailableQty balance - qty}
      where
        qty = 0 -- Parse from event data
    StockReserved -> balance {sbReservedQty = sbReservedQty balance + qty, sbAvailableQty = sbAvailableQty balance - qty}
      where
        qty = 0 -- Parse from event data
    StockReleased -> balance {sbReservedQty = sbReservedQty balance - qty, sbAvailableQty = sbAvailableQty balance + qty}
      where
        qty = 0 -- Parse from event data
    StockAdjusted -> balance {sbCurrentQty = sbCurrentQty balance + adj, sbAvailableQty = sbAvailableQty balance + adj}
      where
        adj = 0 -- Parse from event data
    _ -> balance
