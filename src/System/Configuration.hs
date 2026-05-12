module System.Configuration where

import qualified Data.Map.Strict as Map
import Data.Text (Text, pack)
import System.Directory (doesFileExist)
import System.IO ()
import System.Environment (lookupEnv)
import Data.Maybe (fromMaybe)

-- | Application configuration
data AppConfig = AppConfig
  { appPort :: Int,
    appDbUrl :: Text,
    appLogLevel :: Text,
    appEnv :: Text,
    appFeatures :: Map.Map Text Bool,
    appSecrets :: Map.Map Text Text
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
      appSecrets = Map.empty
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
  return $
    AppConfig
      { appPort = maybe 8080 read portStr,
        appDbUrl = pack (fromMaybe "postgresql://localhost/surypus" dbUrl),
        appLogLevel = pack (fromMaybe "INFO" logLevel),
        appEnv = pack (fromMaybe "development" env),
        appFeatures = Map.empty,
        appSecrets = Map.empty
      }
