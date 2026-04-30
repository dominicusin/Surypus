module System.Configuration where

import qualified Data.Map.Strict as Map
import Data.Text (Text)
-- import qualified Data.YAML as Yaml
import System.Directory (doesFileExist)
import System.IO (IOMode (..), hGetContents, withFile)

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
      appDbUrl = "postgresql://localhost/surypus",
      appLogLevel = "INFO",
      appEnv = "development",
      appFeatures = Map.empty,
      appSecrets = Map.empty
    }

-- | Load configuration from YAML file
loadConfig :: FilePath -> IO AppConfig
loadConfig path = do
  exists <- doesFileExist path
  if exists
    then do
      content <- withFile path ReadMode hGetContents
      case Yaml.decodeEither content of
        Right config -> return $ mergeConfig defaultConfig config
        Left err -> error $ "Failed to parse config: " ++ err
    else return defaultConfig

-- | Merge configurations
mergeConfig :: AppConfig -> AppConfig -> AppConfig
mergeConfig base override =
  base
    { appPort = appPort override `ifSet` appPort base,
      appDbUrl = appDbUrl override `ifSet` appDbUrl base,
      appLogLevel = appLogLevel override `ifSet` appLogLevel base,
      appEnv = appEnv override `ifSet` appEnv base,
      appFeatures = Map.union (appFeatures override) (appFeatures base),
      appSecrets = Map.union (appSecrets override) (appSecrets base)
    }
  where
    x `ifSet` y = if x == y then y else x

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
        appDbUrl = fromMaybe "postgresql://localhost/surypus" dbUrl,
        appLogLevel = fromMaybe "INFO" logLevel,
        appEnv = fromMaybe "development" env,
        appFeatures = Map.empty,
        appSecrets = Map.empty
      }

-- | Lookup environment variable
lookupEnv :: String -> IO (Maybe Text)
lookupEnv _ = return Nothing -- Simplified for this example
