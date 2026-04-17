module Surypus.API where

import Servant
import Surypus.API.Auth (AuthAPI, loginHandler)
import Surypus.API.Bills (BillsAPI)
import Surypus.API.Bulkhead (BulkheadAPI)
import Surypus.API.CircuitBreaker (CircuitBreakerAPI)
import Surypus.API.Core (CoreAPI)
import Surypus.API.Health (HealthAPI, healthCheck, liveCheck, readyCheck)
import Surypus.API.Inventory (InventoryAPI)
import Surypus.API.Payrolls (PayrollsAPI)
import Surypus.API.Persons (PersonsAPI)
import Surypus.API.Production (ProductionAPI)
import Surypus.API.RPC (RPCAPI)
import Surypus.API.Reports (ReportsAPI)

-- | Root API combining all subsystems
type API =
  HealthAPI
    :<|> AuthAPI
    :<|> CoreAPI
    :<|> BillsAPI
    :<|> PayrollsAPI
    :<|> InventoryAPI
    :<|> ReportsAPI
    :<|> PersonsAPI
    :<|> ProductionAPI
    :<|> CircuitBreakerAPI
    :<|> BulkheadAPI
    :<|> RPCAPI

-- | Combined server implementation
server ::
  (MonadIO m) =>
  ( forall a. HealthAPI m a,
    forall a. AuthAPI m a,
    forall a. CoreAPI m a,
    forall a. BillsAPI m a,
    forall a. PayrollsAPI m a,
    forall a. InventoryAPI m a,
    forall a. ReportsAPI m a,
    forall a. PersonsAPI m a,
    forall a. ProductionAPI m a,
    forall a. CircuitBreakerAPI m a,
    forall a. BulkheadAPI m a,
    forall a. RPCAPI m a
  ) =>
  Server API
server =
  healthCheck
    :<|> loginHandler
    :<|> coreServer
    :<|> billsServer
    :<|> payrollsServer
    :<|> inventoryServer
    :<|> reportsServer
    :<|> personsServer
    :<|> productionServer
    :<|> circuitBreakerServer
    :<|> bulkheadServer
    :<|> rpcServer
  where
    coreServer = undefined
    billsServer = undefined
    payrollsServer = undefined
    inventoryServer = undefined
    reportsServer = undefined
    personsServer = undefined
    productionServer = undefined
    circuitBreakerServer = undefined
    bulkheadServer = undefined
    rpcServer = undefined

-- | Application entry point
app :: Application
app = serve (Proxy :: Proxy API) server
