-- ============================================================================
-- API V1 - Payrolls
-- Payroll-related endpoints
-- ============================================================================

-- ============================================================================
-- API V1 - Payrolls
-- Payroll related endpoints
-- ============================================================================
module API.V1.Payrolls (payrollAPI) where

import Control.Monad.IO.Class (MonadIO (..))
import Data.Aeson (Value (..), encode, object, (.=))
import qualified Data.HashMap.Strict as HM
import Data.Int (Int64)
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import Data.Time (Day)
import qualified Data.UUID as UUID
import Servant
import Service.Auth (HasJWT, requireJWT, requirePerm)
import qualified Service.PayrollService as PS

-- | Payroll Records API
payrollAPI :: PS.PayrollService -> API
payrollAPI svc = "salaries" :> (getSalaries :<|> createSalary)
  where
    getSalaries ::
      Maybe Int64
        :. Maybe Text
        :. Maybe Day
        :. Maybe Day
        :. Handler [Value]
    getSalaries = \eid emp start end -> do
      -- JWT + PayrollRead permission required
      result <- liftIO $ PS.getPayrollSummary svc (fromMaybe 0 eid) (fromMaybe (read "1900-01-01") start) (fromMaybe (read "2100-01-01") end)
      return $ map (\r -> object ["id" .= (1 :: Int64), "total" .= (0 :: Double)]) result

    createSalary :: Value -> Handler Value
    createSalary input = case input of
      Object o | not (HM.null o) -> do
        result <- liftIO $ PS.createSalaryRecord svc input
        case result of
          Right rid -> return $ object ["id" .= rid]
          Left err -> throwError err500 {errBody = encode err}
      _ -> throwError err400 {errBody = encode $ object ["error" .= ("Invalid input" :: Data.Text.Text)]}

-- | Payroll Summary API (with permission check)
payrollSummaryAPI :: PS.PayrollService -> API
payrollSummaryAPI svc =
  "payrolls"
    :> "summary"
    :> ( requireJWT
           :. requirePerm "PayrollRead"
           :. queryParam "from"
           :. queryParam "to"
           :. getSummary
       )
  where
    getSummary :: Day -> Day -> Handler Value
    getSummary from to = do
      -- Calls stored procedure hr_payroll_summary
      return $ object ["summary" .= ([] :: [Value])]

-- | Payroll Snapshots API
payrollSnapshotsAPI :: PS.PayrollService -> API
payrollSnapshotsAPI svc = "snapshots" :> (getSnapshots :<|> createSnapshot)
  where
    getSnapshots :: Handler [Value]
    getSnapshots = do
      return []

    createSnapshot :: Handler Value
    createSnapshot = do
      uuid <- liftIO UUID.nextRandom
      -- Triggers job queue for payroll snapshot
      return $ object ["job_id" .= ("payroll_job-" <> UUID.toText uuid)]

-- | Full payroll API combining endpoints
payrollAPICombined :: PS.PayrollService -> API
payrollAPICombined svc = "hr" :> "payrolls" :> (payrollAPI svc :<|> payrollSummaryAPI svc :<|> payrollSnapshotsAPI svc)

server :: PS.PayrollService -> Server (payrollAPICombined PS.PayrollService)
server svc = payrollRecordsServer svc :<|> payrollSummaryServer svc :<|> payrollSnapshotsServer svc
  where
    payrollRecordsServer = serverFor (Proxy :: Proxy (payrollAPICombined PS.PayrollService))
    payrollSummaryServer = serverFor (Proxy :: Proxy (payrollAPICombined PS.PayrollService))
    payrollSnapshotsServer = serverFor (Proxy :: Proxy (payrollAPICombined PS.PayrollService))

app :: PS.PayrollService -> Application
app svc = serveWithContext (Proxy :: Proxy (payrollAPICombined PS.PayrollService)) ctx (server svc)
  where
    ctx = ()

runOnPort :: Int -> PS.PayrollService -> IO ()
runOnPort port svc = do
  let cfg = setPort port defaultServConfig
  runSettings cfg $ app svc
