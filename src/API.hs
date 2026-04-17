module API.V1 where

import API.V1.AccPlan (accPlanAPI)
import API.V1.AccTurn (accTurnAPI)
import API.V1.Bills
import API.V1.Currency (currencyAPI)
import API.V1.Inventory
import API.V1.Location (locationAPI)
import API.V1.Orders (ordersAPI)
import API.V1.Payrolls
import API.V1.Persons
import API.V1.Reports
import API.V1.Tax (taxAPI)
import Servant
import qualified Service.BillService as BS
import qualified Service.InventoryService as IS
import qualified Service.PayrollService as PS
import qualified Service.ProductionService as ProdS
import qualified Service.ReportService as RS

-- | Full API combining all versioned endpoints
api ::
  BS.BillService ->
  PS.PayrollService ->
  ProdS.ProductionService ->
  IS.InventoryService ->
  RS.ReportService ->
  () -> -- currency service (placeholder)
  () -> -- tax service (placeholder)
  () -> -- accPlan service (placeholder)
  () -> -- accTurn service (placeholder)
  () -> -- location service (placeholder)
  () -> -- order service (placeholder)
  API
api bs payroll prod inv report _ _ _ _ _ _ =
  "v1"
    :> ( billsAPI bs
           :<|> payrollAPI payroll
           :<|> inventoryAPI inv
           :<|> reportsAPI report
           :<|> personsAPI
           :<|> currencyAPI ()
           :<|> taxAPI ()
           :<|> accPlanAPI ()
           :<|> accTurnAPI ()
           :<|> locationAPI ()
           :<|> ordersAPI ()
       )

-- | Server for the full API
server ::
  BS.BillService ->
  PS.PayrollService ->
  ProdS.ProductionService ->
  IS.InventoryService ->
  RS.ReportService ->
  () -> -- currency service
  () -> -- tax service
  () -> -- accPlan service
  () -> -- accTurn service
  () -> -- location service
  () -> -- order service
  Server (api BS PS ProdS.InventoryService RS.ReportService () () () () () ())
server bs payroll prod inv report _ _ _ _ _ _ =
  billServer bs
    :<|> payrollServer payroll
    :<|> inventoryServer inv
    :<|> reportsServer report
    :<|> personsServer
    :<|> currencyServer
    :<|> taxServer
    :<|> accPlanServer
    :<|> accTurnServer
    :<|> locationServer
    :<|> orderServer
  where
    billServer = serverFor (Proxy :: Proxy (api BS PS ProdS.InventoryService RS.ReportService () () () () () ()))
    payrollServer = serverFor (Proxy :: Proxy (api BS PS ProdS.InventoryService RS.ReportService () () () () () ()))
    inventoryServer = serverFor (Proxy :: Proxy (api BS PS ProdS.InventoryService RS.ReportService () () () () () ()))
    reportsServer = serverFor (Proxy :: Proxy (api BS PS ProdS.InventoryService RS.ReportService () () () () () ()))
    personsServer = serverFor (Proxy :: Proxy (personsPermAPI PS.PersonService))
    currencyServer = serverFor (Proxy :: Proxy (currencyAPI ()))
    taxServer = serverFor (Proxy :: Proxy (taxAPI ()))
    accPlanServer = serverFor (Proxy :: Proxy (accPlanAPI ()))
    accTurnServer = serverFor (Proxy :: Proxy (accTurnAPI ()))
    locationServer = serverFor (Proxy :: Proxy (locationAPI ()))
    orderServer = serverFor (Proxy :: Proxy (ordersAPI ()))

-- | Application with authentication middleware
app ::
  BS.BillService ->
  PS.PayrollService ->
  ProdS.ProductionService ->
  IS.InventoryService ->
  RS.ReportService ->
  () -> -- currency service
  () -> -- tax service
  () -> -- accPlan service
  () -> -- accTurn service
  () -> -- location service
  () -> -- order service
  Application
app bs payroll prod inv report _ _ _ _ _ _ =
  serveWithContext (Proxy :: Proxy (api BS PS ProdS.InventoryService RS.ReportService () () () () () ())) ctx $ server bs payroll prod inv report _ _ _ _ _ _
  where
    ctx = ()

-- | Run the application on a given port
runAppOnPort ::
  Int ->
  BS.BillService ->
  PS.PayrollService ->
  ProdS.ProductionService ->
  IS.InventoryService ->
  RS.ReportService ->
  () -> -- currency service
  () -> -- tax service
  () -> -- accPlan service
  () -> -- accTurn service
  () -> -- location service
  () -> -- order service
  IO ()
runAppOnPort port bs payroll prod inv report _ _ _ _ _ _ = do
  let cfg = setPort port defaultServConfig
  runSettings cfg $ app bs payroll prod inv report _ _ _ _ _ _
