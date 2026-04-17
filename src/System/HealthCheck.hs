module System.HealthCheck where

import Control.Concurrent.STM (TVar, readTVarIO)
import Data.Text (Text)
import Data.Time.Clock (UTCTime, getCurrentTime)
import System.Health
import qualified System.Health.Monad as HM

-- | Health check result
data HealthResult = HealthResult
  { isHealthy :: Bool,
    checks :: [(Text, Bool, Maybe Text)],
    timestamp :: UTCTime
  }

-- | Perform comprehensive health check
runHealthCheck :: (HM.HealthMonad m) => m HealthResult
runHealthCheck = do
  timestamp <- liftIO getCurrentTime
  checksList <-
    sequence
      [ ("database",) <$> HM.checkDatabase,
        ("cache",) <$> HM.checkCache,
        ("queue",) <$> HM.checkQueue,
        ("external",) <$> HM.checkExternal
      ]
  let isHealthy' = all snd checksList
  return
    HealthResult
      { isHealthy = isHealthy',
        checks = map (\(name, ok, msg) -> (name, ok, if ok then Nothing else msg)) checksList,
        timestamp
      }

-- | Initialize health monitoring system
initHealthCheck :: HM.HealthConfig -> IO (HM.HealthMonitor, IO HealthResult)
initHealthCheck config = do
  monitor <- HM.newHealthMonitor config
  let checkAction = HM.runHealthMonad monitor runHealthCheck
  return (monitor, checkAction)

-- | Health check configuration
defaultHealthConfig :: HM.HealthConfig
defaultHealthConfig =
  HM.HealthConfig
    { HM.checkInterval = 30,
      HM.retryAttempts = 3,
      HM.timeoutSeconds = 10,
      HM.parallelChecks = True,
      HM.alertOnFailure = True
    }

-- | Register health check
registerCheck :: Text -> (IO Bool) -> HM.HealthMonitor -> IO ()
registerCheck name checkAction monitor = do
  HM.registerMonitor monitor name checkAction
  return ()

-- | Get health status string
healthStatusText :: HealthResult -> String
healthStatusText result =
  if isHealthy result
    then "Healthy"
    else "Unhealthy: " ++ show (filter (not . snd) (checks result))
