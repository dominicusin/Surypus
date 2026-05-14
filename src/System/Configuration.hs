module System.Configuration where

import qualified Data.Map.Strict as Map
import Data.Text (Text, pack)
import System.Directory (doesFileExist)
import System.IO ()
import System.Environment (lookupEnv)
import Data.Maybe (fromMaybe, fromMaybe)

-- | Application configuration
data AppConfig = AppConfig
  { appPort :: Int,
    appDbUrl :: Text,
    appLogLevel :: Text,
    appEnv :: Text,
    appFeatures :: Map.Map Text Bool,
    appSecrets :: Map.Map Text Text,
    -- Security
    appJwtSecret :: Text,
    appSessionSecret :: Text,
    appJwtExpirationHours :: Int,
    -- External services
    appOpaUrl :: Text,
    appOpaToken :: Text,
    appKafkaBrokers :: Text,
    appRedisUrl :: Text,
    -- Pool settings
    appDbPoolSize :: Int,
    appDbPoolTimeout :: Int
  }

-- | Default configuration
defaultConfig :: AppConfig
defaultConfig =
  AppConfig
    { appPort = 8080,
      appDbUrl = pack "postgresql://localhost/surypus",
      appLogLevel = pack "INFO",
      appEnv = pack "development",
      appFeatures = Map.empty,
      appSecrets = Map.empty,
      -- Security
      appJwtSecret = pack "",
      appSessionSecret = pack "",
      appJwtExpirationHours = 24,
      -- External services
      appOpaUrl = pack "http://localhost:8181",
      appOpaToken = pack "",
      appKafkaBrokers = pack "localhost:9092",
      appRedisUrl = pack "redis://localhost:6379",
      -- Pool settings
      appDbPoolSize = 10,
      appDbPoolTimeout = 30
    }

-- | Load configuration from YAML file (simplified - just returns default)
loadConfig :: FilePath -> IO AppConfig
loadConfig path = do
  exists <- doesFileExist path
  if exists
    then do
      -- Note: YAML parsing disabled due to missing dependency
      -- In production, use yaml or aeson-yaml library
      return defaultConfig
    else return defaultConfig

-- | Merge configurations
mergeConfig :: AppConfig -> AppConfig -> AppConfig
mergeConfig base override =
  base
    { appPort = if appPort override /= appPort defaultConfig then appPort override else appPort base,
      appDbUrl = if appDbUrl override /= appDbUrl defaultConfig then appDbUrl override else appDbUrl base,
      appLogLevel = if appLogLevel override /= appLogLevel defaultConfig then appLogLevel override else appLogLevel base,
      appEnv = if appEnv override /= appEnv defaultConfig then appEnv override else appEnv base,
      appFeatures = Map.union (appFeatures override) (appFeatures base),
      appSecrets = Map.union (appSecrets override) (appSecrets base)
    }

-- | Get configuration value with fallback
getConfigValue :: Map.Map Text Text -> Text -> Text -> Text
getConfigValue config key fallback = Map.findWithDefault fallback key config

-- | Environment variable loading
loadEnv :: IO AppConfig
loadEnv = do
  portStr <- lookupEnv "APP_PORT"
  dbUrl <- lookupEnv "DATABASE_URL"
  logLevel <- lookupEnv "LOG_LEVEL"
  env <- lookupEnv "APP_ENV"
  jwtSecret <- lookupEnv "JWT_SECRET"
  sessionSecret <- lookupEnv "SESSION_SECRET"
  jwtExpStr <- lookupEnv "JWT_EXPIRATION_HOURS"
  opaUrl <- lookupEnv "OPA_URL"
  opaToken <- lookupEnv "OPA_TOKEN"
  kafkaBrokers <- lookupEnv "KAFKA_BROKERS"
  redisUrl <- lookupEnv "REDIS_URL"
  poolSizeStr <- lookupEnv "DB_POOL_SIZE"
  poolTimeoutStr <- lookupEnv "DB_POOL_TIMEOUT"
  
  let jwtExp = maybe 24 read jwtExpStr
      poolSize = maybe 10 read poolSizeStr
      poolTimeout = maybe 30 read poolTimeoutStr
  
  return $
    AppConfig
      { appPort = maybe 8080 read portStr,
        appDbUrl = pack (fromMaybe "postgresql://localhost/surypus" dbUrl),
        appLogLevel = pack (fromMaybe "INFO" logLevel),
        appEnv = pack (fromMaybe "development" env),
        appFeatures = Map.empty,
        appSecrets = Map.empty,
        appJwtSecret = pack (fromMaybe "" jwtSecret),
        appSessionSecret = pack (fromMaybe "" sessionSecret),
        appJwtExpirationHours = jwtExp,
        appOpaUrl = pack (fromMaybe "http://localhost:8181" opaUrl),
        appOpaToken = pack (fromMaybe "" opaToken),
        appKafkaBrokers = pack (fromMaybe "localhost:9092" kafkaBrokers),
        appRedisUrl = pack (fromMaybe "redis://localhost:6379" redisUrl),
        appDbPoolSize = poolSize,
        appDbPoolTimeout = poolTimeout
      }
