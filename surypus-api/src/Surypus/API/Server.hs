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
import Data.Aeson (FromJSON, ToJSON)
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as DT
import qualified Data.Text.Encoding as TE
import qualified Data.Text.Lazy as TL
import qualified Data.Text.Lazy.Encoding as LBS
import Data.Time.Calendar (fromGregorian)
import qualified Data.UUID as UUID
import qualified Data.UUID.V4 as UUID
import GHC.Generics (Generic)
import Network.HTTP.Types (status401)
import Network.Wai as W
import Servant
import Surypus (
    Bill (..),
    BillInput (..),
    Goods (..),
    MutationResult (..),
    Payment (..),
    Person (..),
    Pool,
    QueryResult (..),
    User (..),
    UserInput (..),
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
    { envPool :: Pool
    , envLogger :: Log.Logger
    , envWSHandler :: Maybe WS.WebSocketHandler
    }

correlationMiddleware :: Log.Logger -> Application -> Application
correlationMiddleware logger app req respond = do
    let corrIdHeader = lookup "x-correlation-id" (W.requestHeaders req)
    corrId <- case corrIdHeader of
        Just cid -> return (TE.decodeUtf8 cid)
        Nothing -> UUID.toText <$> UUID.nextRandom
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

apiServer :: Pool -> Log.Logger -> Application
apiServer pool logger =
    let env = Env pool logger Nothing
     in correlationMiddleware logger $ authMiddleware (serve (Proxy @SurypusApi) (server env))

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
    result <- liftIO $ DAL.Mutations.authenticateUser (envPool env) (lrUsername req) (lrPassword req)
    case result of
        QueryError e -> throwError $ err500{errBody = LBS.encodeUtf8 (TL.fromStrict e)}
        QuerySuccess Nothing -> throwError err401
        QuerySuccess (Just user) -> do
            token <- liftIO $ JWT.generateToken (envPool env) user
            pure $ LoginResponse token Nothing (DAL.userId user) 3600

billsList env = liftQ $ Bills.listBills (envPool env)
billsCreate env i = liftQ $ fmap (const (Bill 0 Nothing 0 0 (fromGregorian 2000 1 1) Nothing Nothing 0 0 0)) <$> Bills.createBill (envPool env) i
billGet env bid = liftQ $ Bills.getBill (envPool env) bid
billPost env bid = liftQ $ Bills.postBill (envPool env) bid

goodsList env = liftQ $ Goods.listGoods (envPool env)
personsList env = liftQ $ Persons.listPersons (envPool env) Nothing Nothing Nothing Nothing Nothing
paymentsList env = liftQ $ Payments.listPayments (envPool env)

dashboardKPI env = liftQ $ Dashboard.getDashboardKPI (envPool env)
dashboardRevenue env = liftQ $ Dashboard.getRevenueTrend (envPool env)
dashboardOrders env = liftQ $ Dashboard.getOrderStatuses (envPool env)
dashboardStock env = liftQ $ fmap (\s -> [s]) <$> Dashboard.getStockSummary (envPool env)

crmDealsList env = liftQ $ CRM.listDeals (envPool env)
crmDealCreate env i = liftQ $ CRM.createDeal (envPool env) i
crmDealGet env did = liftQ $ CRM.getDeal (envPool env) did
crmDealStageUpdate env d s = liftQ $ CRM.updateDealStage (envPool env) d s
crmPipelineForecast env = liftQ $ CRM.getPipelineForecast (envPool env)
crmDealActivities env did = liftQ $ CRM.listActivities (envPool env) did
crmContactsList env = liftQ $ CRM.listContacts (envPool env)
crmContactCreate env i = liftQ $ CRM.createContact (envPool env) i
crmContactGet env cid = liftQ $ CRM.getContact (envPool env) cid
crmContactUpdate env cid i = liftQ $ CRM.updateContact (envPool env) cid i
crmContactDelete env cid = liftQ $ CRM.deleteContact (envPool env) cid
crmContactSearch env q = liftQ $ CRM.searchContacts (envPool env) q
crmCompaniesList env = liftQ $ CRM.listCompanies (envPool env)
crmCompanyCreate env i = liftQ $ CRM.createCompany (envPool env) i
crmCompanyGet env coid = liftQ $ CRM.getCompany (envPool env) coid
crmCompanyUpdate env coid i = liftQ $ CRM.updateCompany (envPool env) coid i
crmCompanyDelete env coid = liftQ $ CRM.deleteCompany (envPool env) coid
crmCompanySearch env q = liftQ $ CRM.searchCompanies (envPool env) q
crmPipelineStagesList env = liftQ $ CRM.listPipelineStages (envPool env)
crmPipelineStageRules env s = liftQ $ CRM.getStageRules (envPool env) s
crmPipelineForecastRefresh env = liftQ $ CRM.refreshPipelineForecast (envPool env)
crmDealStageHistory env did = liftQ $ CRM.getStageHistory (envPool env) did

notificationsList env = liftQ $ Notifications.listNotifications (envPool env) 1
notificationsCreate env i = liftQ $ Notifications.createNotification (envPool env) i
notificationsMarkRead env nid = liftQ $ Notifications.markNotificationRead (envPool env) nid
notificationsGetPrefs env = liftQ $ Notifications.getNotificationPrefs (envPool env) 1
notificationsUpdatePrefs env i = liftQ $ Notifications.updateNotificationPrefs (envPool env) 1 i
notificationsSendTest env =
    liftQ $
        Notifications.sendEmailNotification
            (envPool env)
            (Notifications.NotificationInput 1 "Test" "Test notification" "test")
notificationsSendDigest env f = liftQ $ Notifications.sendDigestNotification (envPool env) 1 f

reportsPnL env = liftQ $ Reports.getPnLReport (envPool env)
reportsInventory env = liftQ $ Reports.getInventoryReport (envPool env)

ordersList env = liftQ $ Orders.listOrders (envPool env)
ordersCreate env i = liftQ $ Orders.createOrder (envPool env) i
ordersGet env oid = liftQ $ Orders.getOrder (envPool env) oid
ordersUpdate env oid i = liftQ $ Orders.updateOrder (envPool env) oid i
ordersDelete env oid = liftQ $ Orders.deleteOrder (envPool env) oid

integrationsList env = liftQ $ Integrations.listIntegrations (envPool env)
integrationGet env iid = liftQ $ Integrations.getIntegration (envPool env) iid
integrationUpdateStatus env iid status = liftQ $ Integrations.updateIntegrationStatus (envPool env) iid status

usersList env = liftQ $ DAL.Mutations.listUsers (envPool env)
usersCreate env i = liftQ $ DAL.Mutations.createUser (envPool env) i
usersGet env uid = liftQ $ DAL.Mutations.getUser (envPool env) uid
usersUpdate env uid i = liftQ $ DAL.Mutations.updateUser (envPool env) uid i

workflowsList env = liftQ $ Workflow.listWorkflows (envPool env)
workflowsCreate env i = liftQ $ Workflow.createWorkflow (envPool env) i
workflowsInstancesList env = liftQ $ Workflow.listWorkflowInstances (envPool env)
workflowsGetInstance env iid = liftQ $ Workflow.getWorkflowInstance (envPool env) iid
workflowsCompleteInstance env iid = liftQ $ Workflow.completeWorkflow (envPool env) iid

-- ── Classifier handlers ──────────────────────────────────────────────────────
classifiersOksmList env = liftQ $ Classifiers.listOksm (envPool env)
classifiersOkvList env = liftQ $ Classifiers.listOkv (envPool env)
classifiersOkeiList env = liftQ $ Classifiers.listOkei (envPool env)
classifiersOkpd2List env = liftQ $ Classifiers.listOkpd2 (envPool env)
classifiersOkved2List env = liftQ $ Classifiers.listOkved2 (envPool env)
classifiersTnvedList env = liftQ $ Classifiers.listTnved (envPool env)
classifiersOkatoList env = liftQ $ Classifiers.listOkato (envPool env)
classifiersOktmoList env = liftQ $ Classifiers.listOktmo (envPool env)
classifiersOkofList env = liftQ $ Classifiers.listOkof (envPool env)
classifiersOkpList env = liftQ $ Classifiers.listOkp (envPool env)
classifiersOkdpList env = liftQ $ Classifiers.listOkdp (envPool env)
classifiersOksoList env = liftQ $ Classifiers.listOkso (envPool env)
classifiersOkunList env = liftQ $ Classifiers.listOkun (envPool env)
classifiersOkudList env = liftQ $ Classifiers.listOkud (envPool env)
classifiersOkfsList env = liftQ $ Classifiers.listOkfs (envPool env)
classifiersOknpoList env = liftQ $ Classifiers.listOknpo (envPool env)
