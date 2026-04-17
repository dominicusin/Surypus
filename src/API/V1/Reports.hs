-- ============================================================================
-- API V1 - Reports
-- Reporting endpoints
-- ============================================================================

-- ============================================================================
-- API V1 - Reports
-- Reporting endpoints
-- ============================================================================
module API.V1.Reports (reportsAPI) where

import Control.Monad.IO.Class (MonadIO (..))
import Data.Aeson (Value, encode, object, (.=))
import qualified Data.Aeson as A
import qualified Data.HashMap.Strict as HM
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.UUID as UUID
import Servant
import Service.Auth (HasJWT, requireJWT, requirePerm)
import qualified Service.ReportService as RS

-- | Report Schedules API
reportsAPI :: RS.ReportService -> API
reportsAPI svc =
  "schedules" :> (getScheds :<|> createSched)
    :<|> "schedules"
      :> capture "id" Int64
      :> (getSchedSnaps :<|> runSched)
  where
    getScheds :: Handler [Value]
    getScheds = do
      result <- liftIO $ RS.listReportSchedules svc
      return $ map (\s -> object ["id" .= (1 :: Int64), "name" .= ("default" :: Text)]) result

    createSched :: Value -> Handler Value
    createSched input = case input of
      Object o | not (HM.null o) -> do
        result <- liftIO $ RS.createReportSchedule svc input
        case result of
          Right id -> return $ object ["id" .= id]
          Left err -> throwError err500 {errBody = encode err}
      _ -> throwError err400 {errBody = encode $ object ["error" .= ("Invalid input" :: Text)]}

    getSchedSnaps :: Int64 -> Handler [Value]
    getSchedSnaps schedId = do
      if schedId <= 0
        then throwError err400 {errBody = encode $ object ["error" .= ("Invalid schedule id" :: Text)]}
        else do
          result <- liftIO $ RS.listReportSnapshots svc schedId
          return []

    runSched :: Int64 -> Handler Value
    runSched id = do
      uuid <- liftIO UUID.nextRandom
      -- Triggers job queue for report rendering
      return $ object ["job_id" .= ("report_job-" <> UUID.toText uuid)]

-- | Reports with permissions
reportsPermAPI :: RS.ReportService -> API
reportsPermAPI svc = requireJWT :. requirePerm "ReportRender" :> reportsAPI svc

server :: RS.ReportService -> Server (reportsPermAPI RS.ReportService)
server svc = reportsServer svc
  where
    reportsServer = serverFor (Proxy :: Proxy (reportsPermAPI RS.ReportService))

app :: RS.ReportService -> Application
app svc = serveWithContext (Proxy :: Proxy (reportsPermAPI RS.ReportService)) ctx (server svc)
  where
    ctx = ()

runOnPort :: Int -> RS.ReportService -> IO ()
runOnPort port svc = do
  let cfg = setPort port defaultServConfig
  runSettings cfg $ app svc
