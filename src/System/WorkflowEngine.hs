module System.WorkflowEngine where

import Control.Concurrent.STM (TVar, newTVarIO, readTVar, writeTVar, atomically)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import Data.Time.Clock (UTCTime, getCurrentTime)
import System.Workflow (Workflow)

-- | Workflow engine with full orchestration
data WorkflowEngine = WorkflowEngine
  { engineWorkflows :: TVar (Map.Map Text Workflow),
    engineInstances :: TVar (Map.Map Text WorkflowInstance),
    engineConfig :: WorkflowConfig
  }

-- | Workflow instance with execution state
data WorkflowInstance = WorkflowInstance
  { instanceId :: Text,
    instanceWorkflow :: Text,
    instanceState :: TVar InstanceState,
    instanceCreated :: UTCTime,
    instanceSteps :: [Text],
    instanceCurrentStep :: TVar Int
  }

-- | Instance execution states
data InstanceState
  = InstanceDraft
  | InstanceScheduled UTCTime
  | InstanceRunning { stepStartTime :: UTCTime }
  | InstanceCompleted UTCTime
  | InstanceFailed Text UTCTime
  | InstanceCancelled
  deriving (Show, Eq)

-- | Workflow configuration
data WorkflowConfig = WorkflowConfig
  { maxConcurrentInstances :: Int,
    defaultTimeoutSeconds :: Int,
    retryLimit :: Int
  }

-- | Initialize workflow engine
initWorkflowEngine :: WorkflowConfig -> IO WorkflowEngine
initWorkflowEngine config = do
  workflowsVar <- newTVarIO Map.empty
  instancesVar <- newTVarIO Map.empty
  return $ WorkflowEngine workflowsVar instancesVar config

-- | Create new workflow instance
createWorkflowInstance :: WorkflowEngine -> Text -> Text -> IO Text
createWorkflowInstance engine workflowId desc = do
  now <- getCurrentTime
  let instanceId = "instance-" <> desc <> "-" <> show (hash now)
  stepVar <- newTVarIO 0
  instance <- newTVarIO $ WorkflowInstance
    { instanceId = instanceId,
      instanceWorkflow = workflowId,
      instanceState = newTVarIO InstanceDraft,
      instanceCreated = now,
      instanceSteps = [],
      instanceCurrentStep = stepVar
    }
  atomically $ do
    insts <- readTVar (engineInstances engine)
    writeTVar (engineInstances engine) (Map.insert instanceId instance insts)
  return instanceId
  where
    hash = show . fromEnum

-- | Execute workflow step
executeWorkflowStep :: WorkflowEngine -> Text -> IO (Either Text ())
executeWorkflowStep engine instanceId = do
  mInstance <- atomically $ do
    insts <- readTVar (engineInstances engine)
    return $ Map.lookup instanceId insts
  
  case mInstance of
    Nothing -> return $ Left "Instance not found"
    Just instance -> do
      state <- readTVarIO (instanceState instance)
      case state of
        InstanceDraft -> advanceStep engine instance
        InstanceScheduled _ -> advanceStep engine instance
        InstanceRunning _ -> return $ Left "Already running"
        InstanceCompleted _ -> return $ Left "Already completed"
        InstanceFailed _ _ -> return $ Left "Failed, cannot advance"
        InstanceCancelled -> return $ Left "Cancelled"

-- | Advance to next step
advanceStep :: WorkflowEngine -> WorkflowInstance -> IO (Either Text ())
advanceStep engine instance = do
  steps <- readTVarIO (instanceSteps instance)
  current <- readTVarIO (instanceCurrentStep instance)
  let totalSteps = length steps
  if current >= totalSteps
    then do
      now <- getCurrentTime
      atomically $ writeTVar (instanceState instance) (InstanceCompleted now)
      return $ Right ()
    else do
      atomically $ writeTVar (instanceCurrentStep instance) (current + 1)
      return $ Right ()

-- | Cancel workflow instance
cancelWorkflowInstance :: WorkflowEngine -> Text -> IO ()
cancelWorkflowInstance engine instanceId = atomically $ do
  insts <- readTVar (engineInstances engine)
  case Map.lookup instanceId insts of
    Just instance -> do
      writeTVar (instanceState instance) InstanceCancelled
      let insts' = Map.delete instanceId insts
      writeTVar (engineInstances engine) insts'
    Nothing -> return ()

-- | Get instance status
getInstanceStatus :: WorkflowEngine -> Text -> IO (Maybe InstanceState)
getInstanceStatus engine instanceId = atomically $ do
  insts <- readTVar (engineInstances engine)
  mInstance <- return $ Map.lookup instanceId insts
  case mInstance of
    Just instance -> Just <$> readTVar (instanceState instance)
    Nothing -> return Nothing

-- | List workflow instances
listWorkflowInstances :: WorkflowEngine -> IO [(Text, InstanceState)]
listWorkflowInstances engine = do
  insts <- readTVarIO (engineInstances engine)
  return $ map (\(k, v) -> (k, =<< readTVarIO (instanceState v))) (Map.toList insts)
