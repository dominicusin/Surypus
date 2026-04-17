{-# LANGUAGE OverloadedStrings #-}
module Surypus.Api.Routes where

import Servant
import qualified Service.BillService as BS
import qualified Service.PayrollService as PS
import qualified Service.ProductionService as PrS
import qualified Service.InventoryService as IS
import qualified Service.ReportService as RS
import qualified Service.PersonService as PersS
import qualified System.CircuitBreakerFullWithMetrics as CB
import qualified System.CircuitBreakerBulkheadFullWithMetrics as BH

-- | API type combining all versioned endpoints
type API = "v1" :> (
      BillsAPI
  :<|> PayrollAPI
  :<|> InventoryAPI
  :<|> ReportsAPI
  :<|> PersonsAPI
  :<|> ProductionAPI
  :<|> CircuitBreakerAPI
  :<|> BulkheadAPI
  )

-- | Bills API
billsAPI :: BS.BillService -> API
billsAPI svc = "bills" :> capture "id" Int64
  :> ( ( requireJWT :. requirePerm "BillRead" :. getBillLines svc
      :<|> requireJWT :. requirePerm "BillWrite" :. postBill svc)
      :<|> requireJWT :. requirePerm "BillPost" :. postBillEndpoint svc)

getBillLines :: BS.BillService -> Int64 -> Handler [Text]
getBillLines = undefined  -- From BillService

postBill :: BS.BillService -> Int64 -> Value -> Handler Value
postBill = undefined

postBillEndpoint :: BS.BillService -> Int64 -> Handler Value
postBillEndpoint = undefined

-- | Payroll API
payrollAPI :: PS.PayrollService -> API
payrollAPI svc = "payrolls" :> "records" :> (
      ( requireJWT :. requirePerm "PayrollRead" :. getSalaries svc
      :<|> requireJWT :. requirePerm "PayrollWrite" :. createSalary svc)
      :<|> requireJWT :. requirePerm "PayrollRead" :. getSummary svc
      :<|> requireJWT :. requirePerm "PayrollRender" :. createSnapshot svc)

getSalaries :: PS.PayrollService -> Maybe Int64 -> Maybe Day -> Maybe Day -> Handler [Value]
getSalaries = undefined

createSalary :: PS.PayrollService -> Value -> Handler Value
createSalary = undefined

getSummary :: PS.PayrollService -> Day -> Day -> Handler Value
getSummary = undefined

createSnapshot :: PS.PayrollService -> Handler Value
createSnapshot = undefined

-- | Inventory API
inventoryAPI :: IS.InventoryService -> API
inventoryAPI svc = "inventory" :> (
      (requireJWT :. requirePerm "InventoryRead" :. getAllInv svc :<|> createInv svc)
      :<|> "item" :> capture "id" Int64
      :> ( requireJWT :. requirePerm "InventoryRead" :. getInvById svc
         :<|> requireJWT :. requirePerm "InventoryWrite" :. postInvDocument svc))

getAllInv :: IS.InventoryService -> Handler [Value]
getAllInv = undefined

createInv :: Value -> Handler Value
createInv = undefined

getInvById :: Int64 -> Handler Value
getInvById = undefined

postInvDocument :: Int64 -> Handler Value
postInvDocument = undefined

-- | Reports API
reportsAPI :: RS.ReportService -> API
reportsAPI svc = "reports" :> "schedules" :> (
      (requireJWT :. requirePerm "ReportRead" :. listScheds svc :<|> requireJWT :. requirePerm "ReportWrite" :. createSched svc)
      :<|> "run" :> capture "id" Int64 :. requireJWT :. requirePerm "ReportRender" :. runSched svc
      :<|> "snapshots" :> capture "id" Int64 :. requireJWT :. requirePerm "ReportRead" :. listSnapshots svc)

listScheds :: RS.ReportService -> Handler [Value]
listScheds = undefined

createSched :: Value -> Handler Value
createSched = undefined

runSched :: Int64 -> Handler Value
runSched = undefined

listSnapshots :: Int64 -> Handler [Value]
listSnapshots = undefined

-- | Persons API
personsAPI :: PersS.PersonService -> API
personsAPI svc = "persons" :> "summary" :> (
      getSummary svc :<|> getSnapshots svc)

getSummary :: PersS.PersonService -> Handler Value
getSummary = undefined

getSnapshots :: PersS.PersonService -> Handler [Value]
getSnapshots = undefined

-- | Production API
productionAPI :: PrS.ProductionService -> API
productionAPI svc = "production" :> (
      "tech" :> (requireJWT :. requirePerm "TechRead" :. getTechCards svc :<|> requireJWT :. requirePerm "TechWrite" :. createTechCard svc)
      :<|> "work-orders" :> (
            (requireJWT :. requirePerm "WorkOrderRead" :. listWorkOrders svc
            :<|> requireJWT :. requirePerm "WorkOrderWrite" :. createWorkOrder svc)
            :<|> "release" :> capture "id" Int64 :. requireJWT :. requirePerm "WorkOrderRelease" :. releaseWorkOrder svc
            :<|> "complete" :> capture "id" Int64 :. requireJWT :. requirePerm "WorkOrderComplete" :. completeWorkOrder svc)

getTechCards :: PrS.ProductionService -> Handler [Value]
getTechCards = undefined

createTechCard :: Value -> Handler Value
createTechCard = undefined

listWorkOrders :: PrS.ProductionService -> Maybe Text -> Maybe Int64 -> Handler [Value]
listWorkOrders = undefined

createWorkOrder :: Value -> Handler Value
createWorkOrder = undefined

releaseWorkOrder :: Int64 -> Handler Value
releaseWorkOrder = undefined

completeWorkOrder :: Int64 -> Handler Value
completeWorkOrder = undefined

-- | Circuit Breaker APIs
circuitBreakerAPI :: CB.CircuitBreakerFullWithMetrics -> API
circuitBreakerAPI cb = "circuit" :> (
      "status" :> getStatus cb
      :<|> "metrics" :> getMetrics cb)

getStatus :: CB.CircuitBreakerFullWithMetrics -> Handler Value
getStatus = undefined

getMetrics :: CB.CircuitBreakerFullWithMetrics -> Handler Value
getMetrics = undefined

-- | Bulkhead APIs
bulkheadAPI :: BH.CircuitBreakerBulkheadFullWithMetrics -> API
bulkheadAPI bh = "bulkhead" :> (
      "acquire" :> capture "partition" Text :. requireJWT :. requirePerm "BulkheadAcquire" :. acquireResource bh
      :<|> "release" :> capture "id" Int64 :. requireJWT :. requirePerm "BulkheadRelease" :. releaseResource bh
      :<|> "metrics" :> getMetrics bh)

acquireResource :: BH.CircuitBreakerBulkheadFullWithMetrics -> Text -> Handler Value
acquireResource = undefined

releaseResource :: Int64 -> Handler Value
releaseResource = undefined

getMetrics :: BH.CircuitBreakerBulkheadFullWithMetrics -> Handler Value
getMetrics = undefined

-- | Combined root API
api :: BS.BillService -> PS.PayrollService -> PrS.ProductionService -> IS.InventoryService -> RS.ReportService -> PersS.PersonService -> CB.CircuitBreakerFullWithMetrics -> BH.CircuitBreakerBulkheadFullWithMetrics -> Server API
api bs ps prs inv rep pers cb bh = 
      billsAPI bs
  :<|> payrollAPI ps
  :<|> inventoryAPI inv
  :<|> reportsAPI rep
  :<|> personsAPI pers
  :<|> productionAPI prs
  :<|> circuitBreakerAPI cb
  :<|> bulkheadAPI bh
