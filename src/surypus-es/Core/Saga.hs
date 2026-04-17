{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
-- ============================================================================
-- Saga Pattern Implementation
-- ============================================================================
-- Distributed transaction orchestration with compensation support
-- ============================================================================
{-# LANGUAGE GADTs #-}
{-# LANGUAGE RecordWildCards #-}

module Surypus.Core.Saga
  ( Saga (..),
    SagaStep (..),
    SagaStatus (..),
    SagaResult (..),
    runSaga,
    compensateSaga,
  )
where

import Control.Exception (Exception, throwIO, try)
import Control.Monad (foldM, when)
import Data.Text (Text)
import Data.Time (UTCTime, getCurrentTime)
import Data.UUID (UUID)
import GHC.Generics (Generic)
import Surypus.Core.EventStore

-- ============================================================================
-- SAGA TYPES
-- ============================================================================

-- | Saga definition
data Saga m = Saga
  { sagaType :: Text,
    sagaSteps :: [SagaStep m],
    sagaTimeoutSeconds :: Int
  }

-- | Saga step definition
data SagaStep m = forall a.
  SagaStep
  { stepName :: Text,
    stepAction :: m (Either SagaError a),
    stepCompensation :: Maybe (a -> m ())
  }

-- | Saga execution status
data SagaStatus
  = SagaStarted
  | SagaRunning
  | SagaCompleted
  | SagaCompensating
  | SagaCompensated
  | SagaFailed
  deriving (Show, Eq, Generic)

-- | Saga execution result
data SagaResult
  = SagaResultSuccess
  | SagaResultFailed SagaError
  | SagaResultCompensated [Text] -- List of compensated steps
  deriving (Show, Eq)

-- | Saga error
data SagaError = SagaError
  { seStepName :: Text,
    seMessage :: Text,
    seRetryable :: Bool
  }
  deriving (Show, Eq, Generic, Exception)

-- | Saga state during execution
data SagaState = SagaState
  { ssStatus :: SagaStatus,
    ssCurrentStep :: Int,
    ssCompletedSteps :: [Text],
    ssStartTime :: UTCTime
  }

-- ============================================================================
-- SAGA EXECUTION
-- ============================================================================

-- | Run a saga with compensation on failure
runSaga :: (Monad m) => Saga m -> m SagaResult
runSaga saga = do
  startTime <- getCurrentTime
  let initialState =
        SagaState
          { ssStatus = SagaStarted,
            ssCurrentStep = 0,
            ssCompletedSteps = [],
            ssStartTime = startTime
          }

  -- Execute steps sequentially
  result <- executeSteps saga initialState

  case result of
    Left (err, state) -> do
      -- Execute compensation
      compensateSaga saga state
      return $ SagaResultCompensated (ssCompletedSteps state)
    Right _ -> return SagaResultSuccess

-- | Execute saga steps
executeSteps :: (Monad m) => Saga m -> SagaState -> m (Either (SagaError, SagaState) ())
executeSteps Saga {..} state =
  if ssCurrentStep state >= length sagaSteps
    then return $ Right ()
    else do
      let step = sagaSteps !! ssCurrentStep state
      result <- executeStep step

      case result of
        Left err -> return $ Left (err, state)
        Right _ -> do
          let newState =
                state
                  { ssCurrentStep = ssCurrentStep state + 1,
                    ssStatus = SagaRunning,
                    ssCompletedSteps = stepName step : ssCompletedSteps state
                  }
          executeSteps Saga {..} newState

-- | Execute a single step
executeStep :: (Monad m) => SagaStep m -> m (Either SagaError ())
executeStep SagaStep {..} = do
  result <- stepAction
  return $ case result of
    Left err -> Left err
    Right _ -> Right ()

-- ============================================================================
-- COMPENSATION
-- ============================================================================

-- | Compensate executed steps in reverse order
compensateSaga :: (Monad m) => Saga m -> SagaState -> m ()
compensateSaga Saga {..} state = do
  -- Get completed steps in reverse order
  let stepsToCompensate = reverse $ take (ssCurrentStep state) sagaSteps

  -- Execute compensation for each step
  foldM (compensateStep state) () stepsToCompensate
  return ()

-- | Compensate a single step
compensateStep :: (Monad m) => SagaState -> () -> SagaStep m -> m ()
compensateStep _ _ SagaStep {..} =
  case stepCompensation of
    Nothing -> return () -- No compensation needed
    Just comp -> do
      -- Execute compensation
      comp ()
      return ()

-- ============================================================================
-- SAGA EXAMPLES
-- ============================================================================

{- Example: Sales Order Saga

salesOrderSaga :: Monad m => UUID -> UUID -> Double -> Saga m
salesOrderSaga goodsId locationId qty = Saga
    { sagaType = "sales_order"
    , sagaSteps =
        [ SagaStep
            { stepName = "reserve_stock"
            , stepAction = reserveStock goodsId locationId qty
            , stepCompensation = Just $ \_ -> releaseStock goodsId locationId
            }
        , SagaStep
            { stepName = "create_bill"
            , stepAction = createBill goodsId qty
            , stepCompensation = Just $ \_ -> cancelBill goodsId
            }
        , SagaStep
            { stepName = "post_bill"
            , stepAction = postBill goodsId
            , stepCompensation = Just $ \_ -> unpostBill goodsId
            }
        , SagaStep
            { stepName = "issue_stock"
            , stepAction = issueStock goodsId locationId qty
            , stepCompensation = Nothing  -- Already compensated by release_stock
            }
        ]
    , sagaTimeoutSeconds = 300
    }
-}

{- Example: Purchase Order Saga

purchaseOrderSaga :: Monad m => UUID -> UUID -> Double -> Saga m
purchaseOrderSaga goodsId locationId qty = Saga
    { sagaType = "purchase_order"
    , sagaSteps =
        [ SagaStep
            { stepName = "receive_stock"
            , stepAction = receiveStock goodsId locationId qty
            , stepCompensation = Just $ \_ -> adjustStock goodsId locationId (-qty)
            }
        , SagaStep
            { stepName = "create_bill"
            , stepAction = createBill goodsId qty
            , stepCompensation = Just $ \_ -> cancelBill goodsId
            }
        , SagaStep
            { stepName = "post_bill"
            , stepAction = postBill goodsId
            , stepCompensation = Just $ \_ -> unpostBill goodsId
            }
        ]
    , sagaTimeoutSeconds = 300
    }
-}
