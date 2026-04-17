module Surypus.Api.Server where

import Network.Wai (Application)
import Network.Wai.Handler.Warp (defaultServConfig, runSettings, setPort)
import qualified Service.BillService as BS
import qualified Service.InventoryService as IS
import qualified Service.PayrollService as PS
import qualified Service.PersonService as PersS
import qualified Service.ProductionService as PrS
import qualified Service.ReportService as RS
import Surypus.Api.Routes (api)
import qualified System.CircuitBreakerBulkheadFullWithMetrics as BH
import qualified System.CircuitBreakerFullWithMetrics as CB

-- | Build and run the application
runAppOnPort ::
  Int ->
  BS.BillService ->
  PS.PayrollService ->
  PrS.ProductionService ->
  IS.InventoryService ->
  RS.ReportService ->
  PersS.PersonService ->
  CB.CircuitBreakerFullWithMetrics ->
  BH.CircuitBreakerBulkheadFullWithMetrics ->
  IO ()
runAppOnPort port bs payroll prs inv rep pers cb bh = do
  let cfg = setPort port defaultServConfig
  runSettings cfg $ api bs payroll prs inv rep pers cb bh
