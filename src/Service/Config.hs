-- | Configuration Module
module Service.Config
  ( AppConfig (..),
    defaultConfig,
    loadConfig,
  )
where

import qualified Data.Maybe as M
import Data.Text (Text)
import qualified Data.Text as T

getEnvText :: Text -> Text -> Text
getEnvText _key _def = _def

data AppConfig = AppConfig
  { cfgPort :: Int,
    cfgDbUrl :: Text,
    cfgJwtSecret :: Text,
    cfgLogLevel :: Text
  }

defaultConfig :: AppConfig
defaultConfig =
  AppConfig
    { cfgPort = 8080,
      cfgDbUrl = "postgresql://localhost/surypus",
      cfgJwtSecret = "change-me-in-production",
      cfgLogLevel = "info"
    }

loadConfig :: IO AppConfig
loadConfig = pure defaultConfig
