module System.JobQueue where

import Control.Concurrent (forkIO, threadDelay)
import Control.Concurrent.STM (TQueue, isEmptyTQueue, newTQueueIO, readTQueue, writeTQueue)
import Control.Monad (forever, when)
import Data.Aeson (Value, encode)
import qualified Data.ByteString.Lazy as BL
import Data.Text (Text)
import Data.Time.Clock (UTCTime, getCurrentTime)
import qualified Database.PostgreSQL.Simple as PG

-- | Job queue system for background processing
data JobQueue = JobQueue
  { queueChannel :: TQueue Job,
    queueWorkerCount :: Int
  }

data Job = Job
  { jobId :: Text,
    jobType :: Text,
    jobPayload :: Value,
    jobCreatedAt :: UTCTime,
    jobAttempts :: Int
  }

-- | Create a new job queue
initJobQueue :: Int -> IO JobQueue
initJobQueue workers = do
  chan <- newTQueueIO
  return $ JobQueue chan workers

-- | Enqueue a job
enqueueJob :: JobQueue -> Job -> IO ()
enqueueJob (JobQueue chan _) job = writeTQueue chan job

-- | Dequeue a job
dequeueJob :: JobQueue -> IO (Maybe Job)
dequeueJob (JobQueue chan _) = do
  isEmpty <- isEmptyTQueue chan
  if isEmpty
    then return Nothing
    else Just <$> readTQueue chan

-- | Worker loop for processing jobs
workerLoop :: JobQueue -> (Job -> IO ()) -> IO ()
workerLoop queue processor = forever $ do
  mbJob <- dequeueJob queue
  case mbJob of
    Nothing -> threadDelay 1000000 -- Wait 1 second if empty
    Just job -> processor job

-- | Start worker pool
startWorkers :: JobQueue -> Int -> (Job -> IO ()) -> IO [IO ()]
startWorkers queue count processor = mapM (\_ -> forkIO $ workerLoop queue processor) [1 .. count]

-- | Default job processor that persists to database
defaultJobProcessor :: PG.Connection -> Job -> IO ()
defaultJobProcessor conn job = do
  now <- getCurrentTime
  PG.execute
    conn
    "INSERT INTO background_jobs (job_id, type, payload, created_at, attempts) VALUES ($1, $2, $3, $4, $5)"
    (jobId job, jobType job, jobPayload job, jobCreatedAt job, jobAttempts job :: Int)

-- | Retry failed job with exponential backoff
retryJob :: Job -> Job
retryJob job = job {jobAttempts = jobAttempts job + 1}

-- | Schedule a delayed job
scheduleDelayedJob :: JobQueue -> Int -> Job -> IO ()
scheduleDelayedJob queue delaySecs job = do
  threadDelay (delaySecs * 1000000)
  enqueueJob queue job
