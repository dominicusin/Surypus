-- | Application Settings Module
module Service.App
  ( AppSettings (..),
    AppDependencies (..),
    appSettings,
    runApp,
  )
where

import Data.Text (Text)
import qualified Data.Text as T
import Network.Wai (Application, responseLBS)
import Network.Wai.Handler.Warp (run)
import Service.BillService (BillService)
import Service.InventoryService (InventoryService)
import Service.PayrollService (PayrollService)
import Service.ReportService (ReportService)
import Surypus.EventBus (EventBus, EventBusSettings, newEventBus)

data AppSettings = AppSettings
  { settingsPort :: Int,
    settingsDbUrl :: Text,
    settingsJwtSecret :: Text,
    settingsLogLevel :: Text
  }

data AppDependencies = AppDependencies
  { appPool :: (),
    appEventBus :: EventBus
  }

appSettings :: AppSettings
appSettings =
  AppSettings
    { settingsPort = 8080,
      settingsDbUrl = "postgresql://localhost/surypus",
      settingsJwtSecret = "change-me-in-production",
      settingsLogLevel = "info"
    }

runApp :: AppSettings -> IO ()
runApp settings = do
  eventBus <- newEventBus (EventBusSettings 100 10)
  let deps = AppDependencies () eventBus
  putStrLn $ "Server running on port " <> T.pack (show $ settingsPort settings)
  void $ run (settingsPort settings) (app settings deps)
  where
    app _ _ _ respond = respond $ responseLBS status200 [("Content-Type", "text/plain")] "API v1"
