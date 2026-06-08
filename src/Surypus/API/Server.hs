{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeOperators #-}

module Surypus.API.Server (apiServer) where

import Control.Monad.IO.Class (liftIO)
import qualified DAL.Mutations
import qualified DAL.Types as DAL
import DAL.Hasql.Database (ConnectionPool)
import Data.Aeson (FromJSON, ToJSON)
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as DT
import qualified Data.Text.Encoding as TE
import qualified Data.Text.Lazy as TL
import qualified Data.Text.Lazy.Encoding as LBS
import Data.Time.Calendar (fromGregorian)
import qualified Data.UUID as UUID
import qualified Data.UUID.V4 as UUIDv4
import GHC.Generics (Generic)
import Network.HTTP.Types (status200, status401, status429)
import Network.Wai as W
import qualified System.RateLimiter as RL (SlidingWindow, initSlidingWindow, swCheck)
import Servant
import Surypus (
     Bill (..),
     BillInput (..),
     Goods (..),
     MutationResult (..),
     Payment (..),
     Person (..),
     QueryResult (..),
     User (..),
     UserInput (..)
    )
import qualified Surypus.API.Bills as Bills
import qualified Surypus.API.CRM as CRM
import qualified Surypus.API.Classifiers as Classifiers
import qualified Surypus.API.Dashboard as Dashboard
import qualified Surypus.API.Goods as Goods
import qualified Surypus.API.Integrations as Integrations
import qualified Surypus.API.Logger as Log
import qualified Surypus.API.Notifications as Notifications
import qualified Surypus.API.Orders as Orders
import qualified Surypus.API.Payment as Payments
import qualified Surypus.API.Persons as Persons
import qualified Surypus.API.Reports as Reports
import qualified Surypus.API.Workflow as Workflow
import qualified Surypus.JWT.Token as JWT
import qualified Surypus.WebSocket as WS
import Surypus.API.AuthMiddleware (withAuthzResolverAdvanced)

-- Local type definitions for API
data LoginRequest = LoginRequest
    { lrUsername :: Text
    , lrPassword :: Text
    }
    deriving (Generic, Show, Eq)
instance FromJSON LoginRequest

data LoginResponse = LoginResponse
    { lAccessToken :: Text
    , lRefreshToken :: Maybe Text
    , lUserId :: Int64
    , lExpiresIn :: Int
    }
    deriving (Generic, Show, Eq)
instance ToJSON LoginResponse

data Env = Env
     { envConnectionPool :: ConnectionPool
     , envLogger :: Log.Logger
     , envWSHandler :: Maybe WS.WebSocketHandler
     }

correlationMiddleware :: Log.Logger -> Application -> Application
correlationMiddleware logger app req respond = do
    let corrIdHeader = lookup "x-correlation-id" (W.requestHeaders req)
    corrId <- case corrIdHeader of
        Just cid -> return (TE.decodeUtf8 cid)
        Nothing -> UUID.toText <$> UUIDv4.nextRandom
    Log.withCorrelationId logger (DT.unpack corrId) $ app req respond

authMiddleware :: Application -> Application
authMiddleware app req respond = do
    let path = W.rawPathInfo req
    if path == "/api/v1/login"
        then app req respond
        else case lookup "Authorization" (W.requestHeaders req) of
            Nothing -> respond $ W.responseLBS status401 [("Content-Type", "text/plain")] "Unauthorized"
            Just hdr -> do
                let hdrStr = TE.decodeUtf8 hdr
                case DT.stripPrefix "Bearer " hdrStr of
                    Nothing -> respond $ W.responseLBS status401 [("Content-Type", "text/plain")] "Invalid authorization header format"
                    Just tok ->
                        JWT.verifyToken tok >>= \case
                            Left _ -> respond $ W.responseLBS status401 [("Content-Type", "text/plain")] "Invalid token"
                            Right _ -> app req respond

apiServer :: ConnectionPool -> Log.Logger -> [Text] -> (Int64 -> Text -> IO Bool) -> IO Application
apiServer connPool logger publicPaths checkPermission = do
    rateLimiter <- RL.initSlidingWindow 100 60
    let env = Env connPool logger Nothing
        app = metricsEndpoint
            $ rateLimiting rateLimiter
            $ correlationMiddleware logger
            $ authMiddleware
            $ withAuthzResolverAdvanced publicPaths checkPermission
            $ serve (Proxy @SurypusApi) (server env)
    return app

rateLimiting :: RL.SlidingWindow -> Application -> Application
rateLimiting limiter app req respond = do
    allowed <- RL.swCheck limiter
    if allowed
        then app req respond
        else respond $ W.responseLBS status429 [("Content-Type", "application/json")] "{\"error\":\"Rate limit exceeded\"}"

metricsEndpoint :: Application -> Application
metricsEndpoint app req respond =
    if W.rawPathInfo req == "/api/v1/metrics"
        then respond $ W.responseLBS status200
            [("Content-Type", "text/plain; charset=utf-8")]
            "# HELP surypus_requests_total Total requests\n# TYPE surypus_requests_total counter\nsurypus_requests_total 0\n"
        else app req respond

-- ── API type ────────────────────────────────────────────────────────────────

type SurypusApi =
    "api"
        :> "v1"
        :> ( "login" :> ReqBody '[JSON] LoginRequest :> Post '[JSON] LoginResponse
                -- Bills
                :<|> "bills" :> Get '[JSON] [Bill]
                :<|> "bills" :> ReqBody '[JSON] BillInput :> Post '[JSON] Bill
                :<|> "bills" :> Capture "id" Int64 :> Get '[JSON] Bill
                :<|> "bills" :> Capture "id" Int64 :> "post" :> Post '[JSON] ()
                -- Goods / Persons / Payments
                :<|> "goods" :> Get '[JSON] [Goods]
                :<|> "persons" :> Get '[JSON] [Person]
                :<|> "payments" :> Get '[JSON] [Payment]
                -- Dashboard
                :<|> "dashboard" :> Get '[JSON] Dashboard.DashboardKPI
                :<|> "dashboard" :> "revenue" :> Get '[JSON] [Dashboard.RevenuePoint]
                :<|> "dashboard" :> "orders" :> Get '[JSON] [Dashboard.OrderStatus]
                :<|> "dashboard" :> "stock" :> Get '[JSON] [Dashboard.StockSummary]
                -- CRM
                :<|> "crm" :> "deals" :> Get '[JSON] [CRM.Deal]
                :<|> "crm" :> "deals" :> ReqBody '[JSON] CRM.DealInput :> Post '[JSON] CRM.Deal
                :<|> "crm" :> "deals" :> Capture "id" Text :> Get '[JSON] CRM.Deal
                :<|> "crm" :> "deals" :> Capture "id" Text :> "stage" :> Capture "stageId" Text :> Post '[JSON] CRM.Deal
                :<|> "crm" :> "pipeline" :> Get '[JSON] [CRM.PipelineForecast]
                :<|> "crm" :> "deals" :> Capture "id" Text :> "activities" :> Get '[JSON] [CRM.Activity]
                :<|> "crm" :> "contacts" :> Get '[JSON] [CRM.Contact]
                :<|> "crm" :> "contacts" :> ReqBody '[JSON] CRM.ContactInput :> Post '[JSON] CRM.Contact
                :<|> "crm" :> "contacts" :> Capture "id" Text :> Get '[JSON] CRM.Contact
                :<|> "crm" :> "contacts" :> Capture "id" Text :> ReqBody '[JSON] CRM.ContactInput :> Put '[JSON] CRM.Contact
                :<|> "crm" :> "contacts" :> Capture "id" Text :> "delete" :> Post '[JSON] ()
                :<|> "crm" :> "contacts" :> "search" :> Capture "q" Text :> Get '[JSON] [CRM.Contact]
                :<|> "crm" :> "companies" :> Get '[JSON] [CRM.Company]
                :<|> "crm" :> "companies" :> ReqBody '[JSON] CRM.CompanyInput :> Post '[JSON] CRM.Company
                :<|> "crm" :> "companies" :> Capture "id" Text :> Get '[JSON] CRM.Company
                :<|> "crm" :> "companies" :> Capture "id" Text :> ReqBody '[JSON] CRM.CompanyInput :> Put '[JSON] CRM.Company
                :<|> "crm" :> "companies" :> Capture "id" Text :> "delete" :> Post '[JSON] ()
                :<|> "crm" :> "companies" :> "search" :> Capture "q" Text :> Get '[JSON] [CRM.Company]
                :<|> "crm" :> "pipeline" :> "stages" :> Get '[JSON] [CRM.PipelineStage]
                :<|> "crm" :> "pipeline" :> "stages" :> Capture "id" Text :> "rules" :> Get '[JSON] [CRM.StageRule]
                :<|> "crm" :> "pipeline" :> "forecast" :> "refresh" :> Post '[JSON] ()
                :<|> "crm" :> "deals" :> Capture "id" Text :> "history" :> Get '[JSON] [CRM.StageTransition]
                -- Notifications
                :<|> "notifications" :> Get '[JSON] [Notifications.Notification]
                :<|> "notifications" :> ReqBody '[JSON] Notifications.NotificationInput :> Post '[JSON] Notifications.Notification
                :<|> "notifications" :> Capture "id" Text :> "read" :> Post '[JSON] ()
                :<|> "notifications" :> "prefs" :> Get '[JSON] Notifications.NotificationPref
                :<|> "notifications" :> "prefs" :> ReqBody '[JSON] Notifications.NotificationPrefInput :> Put '[JSON] Notifications.NotificationPref
                :<|> "notifications" :> "test" :> Post '[JSON] ()
                :<|> "notifications" :> "digest" :> Capture "frequency" Text :> Post '[JSON] ()
                -- Reports
                :<|> "reports" :> "pnl" :> Get '[JSON] Reports.Report
                :<|> "reports" :> "inventory" :> Get '[JSON] Reports.Report
                -- Orders
                :<|> "orders" :> Get '[JSON] [Orders.Order]
                :<|> "orders" :> ReqBody '[JSON] Orders.OrderInput :> Post '[JSON] Orders.Order
                :<|> "orders" :> Capture "id" Text :> Get '[JSON] Orders.Order
                :<|> "orders" :> Capture "id" Text :> ReqBody '[JSON] Orders.OrderInput :> Put '[JSON] Orders.Order
                :<|> "orders" :> Capture "id" Text :> "delete" :> Post '[JSON] ()
                -- Users
                :<|> "users" :> Get '[JSON] [User]
                :<|> "users" :> ReqBody '[JSON] UserInput :> Post '[JSON] DAL.MutationResult
                :<|> "users" :> Capture "id" Int64 :> Get '[JSON] User
                :<|> "users" :> Capture "id" Int64 :> ReqBody '[JSON] UserInput :> Put '[JSON] DAL.MutationResult
                -- Integrations
                :<|> "integrations" :> Get '[JSON] [Integrations.Integration]
                :<|> "integrations" :> Capture "id" Int64 :> Get '[JSON] Integrations.Integration
                :<|> "integrations" :> Capture "id" Int64 :> "status" :> ReqBody '[JSON] Integrations.IntegrationStatus :> Put '[JSON] ()
                -- Workflows
                :<|> "workflows" :> Get '[JSON] [Workflow.Workflow]
                :<|> "workflows" :> ReqBody '[JSON] Workflow.WorkflowInput :> Post '[JSON] Workflow.Workflow
                :<|> "workflows" :> "instances" :> Get '[JSON] [Workflow.WorkflowInstance]
                :<|> "workflows" :> "instances" :> Capture "id" Text :> Get '[JSON] Workflow.WorkflowInstance
                :<|> "workflows" :> "instances" :> Capture "id" Text :> "complete" :> Post '[JSON] ()
                -- Classifiers
                :<|> "classifiers" :> "oksm" :> Get '[JSON] [DAL.OksmRecord]
                :<|> "classifiers" :> "okv" :> Get '[JSON] [DAL.OkvRecord]
                :<|> "classifiers" :> "okei" :> Get '[JSON] [DAL.OkeiRecord]
                :<|> "classifiers" :> "okpd2" :> Get '[JSON] [DAL.Okpd2Record]
                :<|> "classifiers" :> "okved2" :> Get '[JSON] [DAL.Okved2Record]
                :<|> "classifiers" :> "tnved" :> Get '[JSON] [DAL.TnvedRecord]
                :<|> "classifiers" :> "okato" :> Get '[JSON] [DAL.OkatoRecord]
                :<|> "classifiers" :> "oktmo" :> Get '[JSON] [DAL.OktmoRecord]
                :<|> "classifiers" :> "okof" :> Get '[JSON] [DAL.OkofRecord]
                :<|> "classifiers" :> "okp" :> Get '[JSON] [DAL.OkpRecord]
                :<|> "classifiers" :> "okdp" :> Get '[JSON] [DAL.OkdpRecord]
                :<|> "classifiers" :> "okso" :> Get '[JSON] [DAL.OksoRecord]
                :<|> "classifiers" :> "okun" :> Get '[JSON] [DAL.OkunRecord]
                :<|> "classifiers" :> "okud" :> Get '[JSON] [DAL.OkudRecord]
                :<|> "classifiers" :> "okfs" :> Get '[JSON] [DAL.OkfsRecord]
                :<|> "classifiers" :> "oknpo" :> Get '[JSON] [DAL.OknpoRecord]
           )

-- ── Server ───────────────────────────────────────────────────────────────────

server :: Env -> Server SurypusApi
server env =
    handleLogin env
        :<|> billsList env
        :<|> billsCreate env
        :<|> billGet env
        :<|> billPost env
        :<|> goodsList env
        :<|> personsList env
        :<|> paymentsList env
        :<|> dashboardKPI env
        :<|> dashboardRevenue env
        :<|> dashboardOrders env
        :<|> dashboardStock env
        :<|> crmDealsList env
        :<|> crmDealCreate env
        :<|> crmDealGet env
        :<|> crmDealStageUpdate env
        :<|> crmPipelineForecast env
        :<|> crmDealActivities env
        :<|> crmContactsList env
        :<|> crmContactCreate env
        :<|> crmContactGet env
        :<|> crmContactUpdate env
        :<|> crmContactDelete env
        :<|> crmContactSearch env
        :<|> crmCompaniesList env
        :<|> crmCompanyCreate env
        :<|> crmCompanyGet env
        :<|> crmCompanyUpdate env
        :<|> crmCompanyDelete env
        :<|> crmCompanySearch env
        :<|> crmPipelineStagesList env
        :<|> crmPipelineStageRules env
        :<|> crmPipelineForecastRefresh env
        :<|> crmDealStageHistory env
        :<|> notificationsList env
        :<|> notificationsCreate env
        :<|> notificationsMarkRead env
        :<|> notificationsGetPrefs env
        :<|> notificationsUpdatePrefs env
        :<|> notificationsSendTest env
        :<|> notificationsSendDigest env
        :<|> reportsPnL env
        :<|> reportsInventory env
        :<|> ordersList env
        :<|> ordersCreate env
        :<|> ordersGet env
        :<|> ordersUpdate env
        :<|> ordersDelete env
        :<|> usersList env
        :<|> usersCreate env
        :<|> usersGet env
        :<|> usersUpdate env
        :<|> integrationsList env
        :<|> integrationGet env
        :<|> integrationUpdateStatus env
        :<|> workflowsList env
        :<|> workflowsCreate env
        :<|> workflowsInstancesList env
        :<|> workflowsGetInstance env
        :<|> workflowsCompleteInstance env
        :<|> classifiersOksmList env
        :<|> classifiersOkvList env
        :<|> classifiersOkeiList env
        :<|> classifiersOkpd2List env
        :<|> classifiersOkved2List env
        :<|> classifiersTnvedList env
        :<|> classifiersOkatoList env
        :<|> classifiersOktmoList env
        :<|> classifiersOkofList env
        :<|> classifiersOkpList env
        :<|> classifiersOkdpList env
        :<|> classifiersOksoList env
        :<|> classifiersOkunList env
        :<|> classifiersOkudList env
        :<|> classifiersOkfsList env
        :<|> classifiersOknpoList env

-- ── Helpers ──────────────────────────────────────────────────────────────────

ok :: QueryResult a -> (a -> Handler b) -> Handler b
ok (QuerySuccess a) f = f a
ok (QueryError "Not Found") _ = throwError err404
ok (QueryError e) _ = throwError $ err500{errBody = LBS.encodeUtf8 (TL.fromStrict e)}

liftQ :: IO (QueryResult a) -> Handler a
liftQ action = liftIO action >>= \r -> ok r pure

-- ── Handlers ─────────────────────────────────────────────────────────────────

handleLogin :: Env -> LoginRequest -> Handler LoginResponse
handleLogin env req = do
    result <- liftIO $ DAL.Mutations.authenticateUser (envConnectionPool env) (lrUsername req) (lrPassword req)
    case result of
        QueryError e -> throwError $ err500{errBody = LBS.encodeUtf8 (TL.fromStrict e)}
        QuerySuccess Nothing -> throwError err401
        QuerySuccess (Just user) -> do
            token <- liftIO $ JWT.generateToken (envConnectionPool env) user
            pure $ LoginResponse token Nothing (DAL.userId user) 3600

billsList env = liftQ $ Bills.listBills (envConnectionPool env)
billsCreate env i = liftQ $ fmap (const (Bill 0 Nothing 0 0 (fromGregorian 2000 1 1) Nothing Nothing 0 0 0)) <$> Bills.createBill (envConnectionPool env) i
billGet env bid = liftQ $ Bills.getBill (envConnectionPool env) bid
billPost env bid = liftQ $ Bills.postBill (envConnectionPool env) bid

goodsList env = liftQ $ Goods.listGoods (envConnectionPool env)
personsList env = liftQ $ Persons.listPersons (envConnectionPool env) Nothing Nothing Nothing Nothing Nothing
paymentsList env = liftQ $ Payments.listPayments (envConnectionPool env)

dashboardKPI env = liftQ $ Dashboard.getDashboardKPI (envConnectionPool env)
dashboardRevenue env = liftQ $ Dashboard.getRevenueTrend (envConnectionPool env)
dashboardOrders env = liftQ $ Dashboard.getOrderStatuses (envConnectionPool env)
dashboardStock env = liftQ $ fmap (\s -> [s]) <$> Dashboard.getStockSummary (envConnectionPool env)

crmDealsList env = liftQ $ CRM.listDeals (envConnectionPool env)
crmDealCreate env i = liftQ $ CRM.createDeal (envConnectionPool env) i
crmDealGet env did = liftQ $ CRM.getDeal (envConnectionPool env) did
crmDealStageUpdate env d s = liftQ $ CRM.updateDealStage (envConnectionPool env) d s
crmPipelineForecast env = liftQ $ CRM.getPipelineForecast (envConnectionPool env)
crmDealActivities env did = liftQ $ CRM.listActivities (envConnectionPool env) did
crmContactsList env = liftQ $ CRM.listContacts (envConnectionPool env)
crmContactCreate env i = liftQ $ CRM.createContact (envConnectionPool env) i
crmContactGet env cid = liftQ $ CRM.getContact (envConnectionPool env) cid
crmContactUpdate env cid i = liftQ $ CRM.updateContact (envConnectionPool env) cid i
crmContactDelete env cid = liftQ $ CRM.deleteContact (envConnectionPool env) cid
crmContactSearch env q = liftQ $ CRM.searchContacts (envConnectionPool env) q
crmCompaniesList env = liftQ $ CRM.listCompanies (envConnectionPool env)
crmCompanyCreate env i = liftQ $ CRM.createCompany (envConnectionPool env) i
crmCompanyGet env coid = liftQ $ CRM.getCompany (envConnectionPool env) coid
crmCompanyUpdate env coid i = liftQ $ CRM.updateCompany (envConnectionPool env) coid i
crmCompanyDelete env coid = liftQ $ CRM.deleteCompany (envConnectionPool env) coid
crmCompanySearch env q = liftQ $ CRM.searchCompanies (envConnectionPool env) q
crmPipelineStagesList env = liftQ $ CRM.listPipelineStages (envConnectionPool env)
crmPipelineStageRules env s = liftQ $ CRM.getStageRules (envConnectionPool env) s
crmPipelineForecastRefresh env = liftQ $ CRM.refreshPipelineForecast (envConnectionPool env)
crmDealStageHistory env did = liftQ $ CRM.getStageHistory (envConnectionPool env) did

notificationsList env = liftQ $ Notifications.listNotifications (envConnectionPool env) 1
notificationsCreate env i = liftQ $ Notifications.createNotification (envConnectionPool env) i
notificationsMarkRead env nid = liftQ $ Notifications.markNotificationRead (envConnectionPool env) nid
notificationsGetPrefs env = liftQ $ Notifications.getNotificationPrefs (envConnectionPool env) 1
notificationsUpdatePrefs env i = liftQ $ Notifications.updateNotificationPrefs (envConnectionPool env) 1 i
notificationsSendTest env = liftQ $ Notifications.sendTestNotification (envConnectionPool env)
notificationsSendDigest env f = liftQ $ Notifications.sendDigestNotification (envConnectionPool env) 1 f

reportsPnL env = liftQ $ Reports.getPnLReport (envConnectionPool env)
reportsInventory env = liftQ $ Reports.getInventoryReport (envConnectionPool env)

ordersList env = liftQ $ Orders.listOrders (envConnectionPool env)
ordersCreate env i = liftQ $ Orders.createOrder (envConnectionPool env) i
ordersGet env oid = liftQ $ Orders.getOrder (envConnectionPool env) oid
ordersUpdate env oid i = liftQ $ Orders.updateOrder (envConnectionPool env) oid i
ordersDelete env oid = liftQ $ Orders.deleteOrder (envConnectionPool env) oid

integrationsList env = liftQ $ Integrations.listIntegrations (envConnectionPool env)
integrationGet env iid = liftQ $ Integrations.getIntegration (envConnectionPool env) iid
integrationUpdateStatus env iid status = liftQ $ Integrations.updateIntegrationStatus (envConnectionPool env) iid status

usersList env = liftQ $ DAL.Mutations.listUsers (envConnectionPool env)
usersCreate env i = liftQ $ DAL.Mutations.createUser (envConnectionPool env) i
usersGet env uid = liftQ $ DAL.Mutations.getUser (envConnectionPool env) uid
usersUpdate env uid i = liftQ $ DAL.Mutations.updateUser (envConnectionPool env) uid i

workflowsList env = liftQ $ Workflow.listWorkflows (envConnectionPool env)
workflowsCreate env i = liftQ $ Workflow.createWorkflow (envConnectionPool env) i
workflowsInstancesList env = liftQ $ Workflow.listWorkflowInstances (envConnectionPool env)
workflowsGetInstance env iid = liftQ $ Workflow.getWorkflowInstance (envConnectionPool env) iid
workflowsCompleteInstance env iid = liftQ $ Workflow.completeWorkflow (envConnectionPool env) iid

-- ── Classifier handlers ──────────────────────────────────────────────────────
classifiersOksmList env = liftQ $ Classifiers.listOksm (envConnectionPool env)
classifiersOkvList env = liftQ $ Classifiers.listOkv (envConnectionPool env)
classifiersOkeiList env = liftQ $ Classifiers.listOkei (envConnectionPool env)
classifiersOkpd2List env = liftQ $ Classifiers.listOkpd2 (envConnectionPool env)
classifiersOkved2List env = liftQ $ Classifiers.listOkved2 (envConnectionPool env)
classifiersTnvedList env = liftQ $ Classifiers.listTnved (envConnectionPool env)
classifiersOkatoList env = liftQ $ Classifiers.listOkato (envConnectionPool env)
classifiersOktmoList env = liftQ $ Classifiers.listOktmo (envConnectionPool env)
classifiersOkofList env = liftQ $ Classifiers.listOkof (envConnectionPool env)
classifiersOkpList env = liftQ $ Classifiers.listOkp (envConnectionPool env)
classifiersOkdpList env = liftQ $ Classifiers.listOkdp (envConnectionPool env)
classifiersOksoList env = liftQ $ Classifiers.listOkso (envConnectionPool env)
classifiersOkunList env = liftQ $ Classifiers.listOkun (envConnectionPool env)
classifiersOkudList env = liftQ $ Classifiers.listOkud (envConnectionPool env)
classifiersOkfsList env = liftQ $ Classifiers.listOkfs (envConnectionPool env)
classifiersOknpoList env = liftQ $ Classifiers.listOknpo (envConnectionPool env)
