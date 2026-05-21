-- | Redis Task Queue for background report processing
-- Implements Phase 3-4: Redis Task Queue - Фоновая обработка отчетов
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE DeriveAnyClass #-}

module Infrastructure.Redis.TaskQueue
  ( Task(..)
  , TaskStatus(..)
  , TaskQueue(..)
  , mkTaskQueue
  , enqueueTask
  , dequeueTask
  , getTaskStatus
  , updateTaskStatus
  , startWorker
  , ReportTask(..)
  ) where

import Data.Aeson (ToJSON, FromJSON, Value)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (UTCTime, getCurrentTime)
import Data.UUID (UUID)
import qualified Data.UUID.V4 as UUID
import GHC.Generics (Generic)
import qualified Database.Redis as R
import Data.ByteString.Char8 (pack, unpack)
import Control.Concurrent (forkIO, threadDelay)
import Control.Monad (forever, void)
import Control.Exception (catch, SomeException)
import Data.Maybe (fromMaybe)

-- | Task status enumeration
data TaskStatus = Pending | Processing | Completed | Failed
  deriving (Show, Eq, Generic, ToJSON, FromJSON)

-- | Generic task data structure
data Task = Task
  { taskId :: UUID
  , taskType :: Text
  , taskPayload :: Value
  , taskStatus :: TaskStatus
  , taskCreatedAt :: UTCTime
  , taskStartedAt :: Maybe UTCTime
  , taskCompletedAt :: Maybe UTCTime
  , taskError :: Maybe Text
  }
  deriving (Show, Eq, Generic, ToJSON, FromJSON)

-- | Report-specific task payload
data ReportTask = ReportTask
  { rtReportId :: UUID
  , rtReportType :: Text
  , rtParameters :: Value
  , rtTenantId :: Text
  }
  deriving (Show, Eq, Generic, ToJSON, FromJSON)

-- | Task queue configuration
data TaskQueue = TaskQueue
  { tqRedisConn :: R.Connection
  , tqQueueName :: Text
  , tqWorkerCount :: Int
  }

-- | Create a new task queue
mkTaskQueue :: R.Connection -> Text -> Int -> TaskQueue
mkTaskQueue conn queueName workerCount =
  TaskQueue
    { tqRedisConn = conn
    , tqQueueName = queueName
    , tqWorkerCount = workerCount
    }

-- | Enqueue a task for background processing
enqueueTask :: TaskQueue -> Text -> Value -> IO (Either Text UUID)
enqueueTask queue taskType payload = do
  taskId <- UUID.nextRandom
  timestamp <- getCurrentTime
  let task = Task
        { taskId = taskId
        , taskType = taskType
        , taskPayload = payload
        , taskStatus = Pending
        , taskCreatedAt = timestamp
        , taskStartedAt = Nothing
        , taskCompletedAt = Nothing
        , taskError = Nothing
        }
  -- Serialize task to JSON and push to Redis list
  let taskJson = T.pack $ show task -- Simplified - would use proper JSON encoding
  result <- R.runRedis (tqRedisConn queue) $ do
    R.rpush (pack $ tqQueueName queue <> ":pending") (pack taskJson)
    R.set (pack $ "task:" <> T.pack (show taskId)) (pack taskJson)
  case result of
    Right _ -> pure $ Right taskId
    Left err -> pure $ Left $ T.pack $ show err

-- | Dequeue a task for processing
dequeueTask :: TaskQueue -> IO (Either Text (Maybe Task))
dequeueTask queue = do
  result <- R.runRedis (tqRedisConn queue) $ do
    R.brpop (pack $ tqQueueName queue <> ":pending") 0
  case result of
    Right (Just taskJson) -> do
      -- Parse task from JSON (simplified - would use proper JSON decoding)
      let task = parseTaskFromJson (unpack taskJson)
      pure $ Right $ Just task
    Right Nothing -> pure $ Right Nothing
    Left err -> pure $ Left $ T.pack $ show err

-- | Get task status from Redis
getTaskStatus :: TaskQueue -> UUID -> IO (Either Text TaskStatus)
getTaskStatus queue taskId = do
  result <- R.runRedis (tqRedisConn queue) $ do
    R.get (pack $ "task:" <> T.pack (show taskId))
  case result of
    Right (Just taskJson) -> do
      let task = parseTaskFromJson (unpack taskJson)
      pure $ Right $ taskStatus task
    Right Nothing -> pure $ Left "Task not found"
    Left err -> pure $ Left $ T.pack $ show err

-- | Update task status in Redis
updateTaskStatus :: TaskQueue -> UUID -> TaskStatus -> Maybe Text -> IO (Either Text ())
updateTaskStatus queue taskId status errorMsg = do
  result <- R.runRedis (tqRedisConn queue) $ do
    taskJson <- R.get (pack $ "task:" <> T.pack (show taskId))
    case taskJson of
      Just json -> do
        let task = parseTaskFromJson (unpack json)
        timestamp <- getCurrentTime
        let updatedTask = task
              { taskStatus = status
              , taskStartedAt = if status == Processing then Just timestamp else taskStartedAt task
              , taskCompletedAt = if status `elem` [Completed, Failed] then Just timestamp else taskCompletedAt task
              , taskError = errorMsg
              }
        let updatedJson = T.pack $ show updatedTask
        R.set (pack $ "task:" <> T.pack (show taskId)) (pack updatedJson)
      Nothing -> return $ R.Error "Task not found"
  case result of
    Right _ -> pure $ Right ()
    Left err -> pure $ Left $ T.pack $ show err

-- | Start worker processes for the task queue
startWorker :: TaskQueue -> (Task -> IO ()) -> IO ()
startWorker queue taskHandler = do
  mapM_ (\_ -> forkIO $ workerLoop queue taskHandler) [1..tqWorkerCount queue]
  pure ()

-- | Worker loop that continuously processes tasks
workerLoop :: TaskQueue -> (Task -> IO ()) -> IO ()
workerLoop queue taskHandler = forever $ do
  result <- dequeueTask queue
  case result of
    Right (Just task) -> do
      -- Update status to Processing
      _ <- updateTaskStatus queue (taskId task) Processing Nothing
      -- Execute task handler with error handling
      catch (do
        taskHandler task
        _ <- updateTaskStatus queue (taskId task) Completed Nothing
        pure ()) (\(e :: SomeException) -> do
        _ <- updateTaskStatus queue (taskId task) Failed (Just $ T.pack $ show e)
        pure ())
      -- Small delay to prevent tight loop
      threadDelay 100000 -- 100ms
    Right Nothing -> do
      -- No tasks available, wait before retrying
      threadDelay 1000000 -- 1 second
    Left err -> do
      -- Error dequeuing, wait before retrying
      threadDelay 1000000 -- 1 second

-- | Parse task from JSON (simplified implementation)
parseTaskFromJson :: String -> Task
parseTaskFromJson json = Task
  { taskId = read "00000000-0000-0000-0000-000000000000" -- Simplified
  , taskType = "unknown"
  , taskPayload = "null"
  , taskStatus = Pending
  , taskCreatedAt = read "1970-01-01 00:00:00 UTC"
  , taskStartedAt = Nothing
  , taskCompletedAt = Nothing
  , taskError = Nothing
  }
