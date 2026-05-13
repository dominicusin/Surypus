module System.JobQueue where
 
import Control.Concurrent (forkIO, ThreadId, threadDelay)
import Control.Monad (forever, void)
import Control.Monad.IO.Class (MonadIO, liftIO)
import Data.Aeson (Value, encode, decode)
import Data.ByteString.Char8 (pack, unpack)
import Data.Text (Text)
import Data.Time.Clock (UTCTime, getCurrentTime)
import Database.Redis
import qualified Database.Redis as R
import Control.Exception (try, SomeException)
 
-- | Job queue system using Redis for background processing
data JobQueue = JobQueue
  { redisConfig :: ConnectInfo,
    queuePrefix :: Text,
    queueWorkerCount :: Int
  }
 
data Job = Job
  { jobId :: Text,
    jobType :: Text,
    jobPayload :: Value,
    jobCreatedAt :: UTCTime,
    jobAttempts :: Int
  }
 
-- | Create a new job queue with Redis configuration
initJobQueue :: ConnectInfo -> Text -> Int -> IO JobQueue
initJobQueue config prefix workers = do
  -- Test connection
  conn <- checkedConnect config
  void $ runRedis conn $ ping
  return $ JobQueue config prefix workers
 
-- | Enqueue a job to Redis queue
enqueueJob :: JobQueue -> Job -> IO ()
enqueueJob (JobQueue config prefix _) job = do
  conn <- checkedConnect config
  let queueName = prefix <> ":jobs"
      jobValue = encode job
  runRedis conn $ lpush queueName (toStrict $ encode job)
  return ()
 
-- | Dequeue a job from Redis queue (blocking with timeout)
dequeueJob :: JobQueue -> IO (Maybe Job)
dequeueJob (JobQueue config prefix _) = do
  conn <- checkedConnect config
  let queueName = prefix <> ":jobs"
      timeout = 0  -- 0 means block indefinitely
  result <- runRedis conn $ brpop [queueName] timeout
  case result of
    Nothing -> return Nothing
    Just (_, value) -> 
      case decode (fromStrict value) of
        Just job -> return (Just job)
        Nothing -> do
          -- Log error but continue
          putStrLn $ "Failed to decode job from Redis: " <> unpack value
          return Nothing
 
-- | Worker loop for processing jobs from Redis
workerLoop :: JobQueue -> (Job -> IO ()) -> IO ()
workerLoop queue processor = forever $ do
  mbJob <- dequeueJob queue
  case mbJob of
    Nothing -> threadDelay 1000000 -- Wait 1 second if error
    Just job -> do
      result <- try (processor job) :: IO (Either SomeException ())
      case result of
        Left exc -> do
          -- Job failed, retry with exponential backoff (max 3 attempts)
          if jobAttempts job < 3
            then do
              putStrLn $ "Job failed, retrying: " <> jobId job <> " error: " <> show exc
              let retryJob' = retryJob job
              threadDelay (2 ^ (jobAttempts job) * 1000000) -- Exponential backoff
              enqueueJob queue retryJob'
            else do
              putStrLn $ "Job failed permanently after 3 attempts: " <> jobId job
          Right _ -> return ()
 
-- | Start worker pool
startWorkers :: JobQueue -> Int -> (Job -> IO ()) -> IO [ThreadId]
startWorkers queue count processor = mapM (\_ -> forkIO $ workerLoop queue processor) [1 .. count]
 
-- | Default job processor (can be overridden)
defaultJobProcessor :: Job -> IO ()
defaultJobProcessor job = do
  putStrLn $ "Processing job: " <> jobId job <> " of type: " <> jobType job
  -- In a real implementation, this would process the job payload
  return ()
 
-- | Helper to get strict ByteString from Lazy ByteString
toStrict :: Data.ByteString.Lazy.ByteString -> Data.ByteString.ByteString
toStrict = Data.ByteString.Lazy.toStrict
 
-- | Helper to get Lazy ByteString from Strict ByteString
fromStrict :: Data.ByteString.ByteString -> Data.ByteString.Lazy.ByteString
fromStrict = Data.ByteString.Lazy.fromStrict
