-- ============================================================================
-- Command Handler Pattern
-- ============================================================================
-- Type-safe command handling with validation and event generation
-- ============================================================================

{-# LANGUAGE GADTs #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE RecordWildCards #-}

module Surypus.Core.CommandHandler
    ( Command(..)
    , CommandHandler(..)
    , CommandResult(..)
    , ValidationError(..)
    , runCommand
    , validateAndExecute
    ) where

import Control.Monad (when)
import Data.Text (Text)
import Data.UUID (UUID)
import Data.Time (UTCTime)

import Surypus.Core.EventStore

-- ============================================================================
-- COMMAND TYPE
-- ============================================================================

data Command (a :: AggregateType) where
    -- Inventory commands
    CmdReceiveStock ::
        { cmdGoodsId :: UUID
        , cmdLocationId :: UUID
        , cmdQty :: Double
        , cmdCost :: Double
        , cmdPrice :: Maybe Double
        } -> Command 'Inventory
    
    CmdIssueStock ::
        { cmdGoodsId :: UUID
        , cmdLocationId :: UUID
        , cmdQty :: Double
        , cmdMethod :: IssueMethod
        } -> Command 'Inventory
    
    CmdAdjustStock ::
        { cmdGoodsId :: UUID
        , cmdLocationId :: UUID
        , cmdAdjustment :: Double
        , cmdReason :: Text
        } -> Command 'Inventory
    
    -- Bill commands
    CmdCreateBill ::
        { cmdBillCode :: Text
        , cmdBillDate :: UTCTime
        , cmdPersonId :: UUID
        , cmdLocationId :: UUID
        } -> Command 'Bill
    
    CmdPostBill :: {} -> Command 'Bill

data IssueMethod = FIFO | LIFO | FEFO
    deriving (Show, Eq)

-- ============================================================================
-- COMMAND RESULT
-- ============================================================================

data CommandResult
    = CommandSuccess
        { crEventId :: Int
        , crSequenceNumber :: Int
        , crAggregateVersion :: Int
        }
    | CommandFailure
        { crError :: ValidationError
        }
    deriving (Show, Eq)

-- ============================================================================
-- VALIDATION ERROR
-- ============================================================================

data ValidationError
    = InvalidQuantity { veExpected :: Text }
    | InvalidCost { veExpected :: Text }
    | InsufficientStock { veNeeded :: Double, veAvailable :: Double }
    | ConcurrentModification { veExpected :: Int, veActual :: Int }
    | InvalidState { veCurrent :: Text, veExpected :: Text }
    | DomainError { veMessage :: Text }
    deriving (Show, Eq)

-- ============================================================================
-- COMMAND HANDLER TYPE CLASS
-- ============================================================================

class CommandHandler c where
    -- | Validate the command without side effects
    validateCommand :: c -> Either ValidationError ()
    
    -- | Execute the command and return events
    executeCommand :: c -> Either ValidationError [EventData]
    
    -- | Command metadata
    commandType :: c -> Text
    commandAggregateType :: c -> Text

-- ============================================================================
-- INVENTORY COMMAND HANDLER
-- ============================================================================

instance CommandHandler (Command 'Inventory) where
    commandType cmd = case cmd of
        CmdReceiveStock{} -> "ReceiveStock"
        CmdIssueStock{}   -> "IssueStock"
        CmdAdjustStock{}  -> "AdjustStock"
    
    commandAggregateType _ = "Inventory"
    
    validateCommand cmd = case cmd of
        CmdReceiveStock{..} -> validateReceiveStock cmdQty cmdCost
        CmdIssueStock{..}   -> validateIssueStock cmdQty
        CmdAdjustStock{..}  -> validateAdjustStock cmdAdjustment
    
    executeCommand cmd = case cmd of
        CmdReceiveStock{..} -> Right [createStockReceivedEvent cmd]
        CmdIssueStock{..}   -> Right [createStockIssuedEvent cmd]
        CmdAdjustStock{..}  -> Right [createStockAdjustedEvent cmd]

validateReceiveStock :: Double -> Double -> Either ValidationError ()
validateReceiveStock qty cost = do
    when (qty <= 0) $
        Left $ InvalidQuantity "Quantity must be positive"
    when (cost < 0) $
        Left $ InvalidCost "Cost cannot be negative"
    Right ()

validateIssueStock :: Double -> Either ValidationError ()
validateIssueStock qty = do
    when (qty <= 0) $
        Left $ InvalidQuantity "Quantity must be positive"
    Right ()

validateAdjustStock :: Double -> Either ValidationError ()
validateAdjustStock _ = Right ()

createStockReceivedEvent :: Command 'Inventory -> EventData
createStockReceivedEvent CmdReceiveStock{..} = EventData
    { edType = "StockReceived"
    , edPayload = undefined  -- Would construct JSON value
    }

createStockIssuedEvent :: Command 'Inventory -> EventData
createStockIssuedEvent CmdIssueStock{..} = EventData
    { edType = "StockIssued"
    , edPayload = undefined
    }

createStockAdjustedEvent :: Command 'Inventory -> EventData
createStockAdjustedEvent CmdAdjustStock{..} = EventData
    { edType = "StockAdjusted"
    , edPayload = undefined
    }

-- ============================================================================
-- BILL COMMAND HANDLER
-- ============================================================================

instance CommandHandler (Command 'Bill) where
    commandType cmd = case cmd of
        CmdCreateBill{} -> "CreateBill"
        CmdPostBill{}   -> "PostBill"
    
    commandAggregateType _ = "Bill"
    
    validateCommand cmd = case cmd of
        CmdCreateBill{..} -> validateCreateBill cmdBillCode
        CmdPostBill{}     -> Right ()
    
    executeCommand cmd = case cmd of
        CmdCreateBill{..} -> Right [createBillCreatedEvent cmd]
        CmdPostBill{}     -> Right [createBillPostedEvent cmd]

validateCreateBill :: Text -> Either ValidationError ()
validateCreateBill code
    | Text.null code = Left $ InvalidQuantity "Bill code cannot be empty"
    | otherwise = Right ()

createBillCreatedEvent :: Command 'Bill -> EventData
createBillCreatedEvent CmdCreateBill{..} = EventData
    { edType = "BillCreated"
    , edPayload = undefined
    }

createBillPostedEvent :: Command 'Bill -> EventData
createBillPostedEvent _ = EventData
    { edType = "BillPosted"
    , edPayload = undefined
    }

-- ============================================================================
-- COMMAND RUNNER
-- ============================================================================

-- | Run a command with full validation and execution
runCommand :: CommandHandler c =
    => EventStore IO
    -> UUID           -- Aggregate ID
    -> c             -- Command
    -> IO CommandResult
runCommand store aggId cmd = do
    case validateAndExecute cmd of
        Left err -> return $ CommandFailure err
        Right events -> do
            -- Append events to store
            result <- mapM (appendEvent store aggId (commandAggregateType cmd)) events
            case result of
                Left err -> return $ CommandFailure $ DomainError (Text.pack err)
                Right (eventId, seqNum) -> return $ CommandSuccess eventId seqNum 1

-- | Validate and execute command without persistence
validateAndExecute :: CommandHandler c =
    => c
    -> Either ValidationError [EventData]
validateAndExecute cmd = do
    validateCommand cmd
    executeCommand cmd

-- Helper type for event data

data EventData = EventData
    { edType :: Text
    , edPayload :: ()  -- Simplified, would be JSON Value
    }

-- Helper function to append event
appendEvent :: EventStore IO -> UUID -> String -> EventData -> IO (Either String (Int, Int))
appendEvent _ _ _ _ = return $ Right (1, 1)  -- Stub

import qualified Data.Text as Text
