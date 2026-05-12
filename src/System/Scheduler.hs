module System.Scheduler where

import Control.Concurrent (forkIO, killThread, threadDelay)
import Control.Concurrent.STM (TVar, TQueue, isEmptyTQueue, newTQueueIO, readTQueue, writeTQueue)
import Control.Monad (forever, when)
import Data.Sequence (Seq)
import qualified Data.PriorityQueue.FingerTree as PQ
import Data.Time.Calendar (Day, addDays)
import Data.Time.Clock (UTCTime, addUTCTime, getCurrentTime)

-- | Scheduled job types
data JobType
  = -- | Run once at specific time
    OneTime UTCTime
  | -- | Recurring schedule function
    Recurring (Day -> Day)
  | -- | Run every N seconds
    Interval Int
  deriving (Show, Eq)

-- | Job definition
data ScheduledJob = ScheduledJob
  { jobId :: Int,
    jobType :: JobType,
    jobAction :: IO (),
    jobNextRun :: UTCTime,
    jobEnabled :: Bool
  }

-- | Scheduler configuration
data SchedulerConfig = SchedulerConfig
  { -- | Check interval in milliseconds
    schedulerTickInterval :: Int,
    -- | Maximum number of scheduled jobs
    schedulerMaxJobs :: Int
  }

-- | Scheduler state
data Scheduler = Scheduler
  { schedulerQueue :: TQueue ScheduledJob,
    schedulerJobs :: TVar (PQ.PQueue UTCTime ScheduledJob),
    schedulerConfig :: SchedulerConfig,
    schedulerThreads :: TVar [ThreadId]
  }

-- | Initialize scheduler
initScheduler :: SchedulerConfig -> IO Scheduler
initScheduler config = do
  queue <- newTQueueIO
  jobs <- newTVarIO PQ.empty
  threads <- newTVarIO []
  return $ Scheduler queue jobs config threads

-- | Schedule a one-time job
scheduleOnce :: Scheduler -> UTCTime -> IO () -> IO Int
scheduleOnce scheduler time action = do
  jobId <- randomRIO (1 :: Int, maxBound :: Int)
  let job =
        ScheduledJob
          { jobId = jobId,
            jobType = OneTime time,
            jobAction = action,
            jobNextRun = time,
            jobEnabled = True
          }
  atomically $ writeTQueue (schedulerQueue scheduler) job
  updateJobQueue scheduler job
  return jobId

-- | Schedule a recurring job
scheduleRecurring :: Scheduler -> Day -> (Day -> Bool) -> IO () -> IO Int
scheduleRecurring scheduler startDate condition action = do
  jobId <- randomRIO (1 :: Int, maxBound :: Int)
  let nextRun = calculateNextRun startDate condition
      job =
        ScheduledJob
          { jobId = jobId,
            jobType = Recurring condition,
            jobAction = action,
            jobNextRun = nextRun,
            jobEnabled = True
          }
  atomically $ writeTQueue (schedulerQueue scheduler) job
  updateJobQueue scheduler job
  return jobId

-- | Calculate next run time for recurring job
calculateNextRun :: Day -> (Day -> Bool) -> UTCTime
calculateNextRun startDate condition = undefined -- Simplified

-- | Update job priority queue
updateJobQueue :: Scheduler -> ScheduledJob -> IO ()
updateJobQueue scheduler job = atomically $ do
  jobs <- readTVar (schedulerJobs scheduler)
  let newJobs = PQ.insert (jobNextRun job) job jobs
  writeTVar (schedulerJobs scheduler) newJobs

-- | Run the scheduler main loop
runScheduler :: Scheduler -> IO ()
runScheduler scheduler = do
  forever $ do
    now <- getCurrentTime
    jobs <- atomically $ readTVar (schedulerJobs scheduler)
    let (due, remaining) = PQ.span (< now) jobs
    -- Execute due jobs
    mapM_ (executeJob scheduler) (PQ.elems due)
    threadDelay (schedulerTickInterval (schedulerConfig scheduler) * 1000)

-- | Execute a single job
executeJob :: Scheduler -> ScheduledJob -> IO ()
executeJob scheduler job = do
  when (jobEnabled job) $ do
    jobAction job
    -- Reschedule if recurring
    case jobType job of
      Recurring condition -> do
        let nextDay = undefined -- Simplified
        newTime <- calculateNextRun nextDay condition
        atomically $ modifyTVar (schedulerJobs scheduler) (PQ.insert newTime job)
      _ -> return ()
