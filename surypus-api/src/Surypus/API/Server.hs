{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeOperators #-}

module Surypus.API.Server (apiServer, startServantServer) where

import Control.Monad.IO.Class (liftIO)
import Data.Int (Int64)
import Data.Proxy (Proxy (..))
import qualified Data.Text as DT
import qualified Data.Text.Encoding as TE
import qualified Data.Text.Lazy as TL
import qualified Data.Text.Lazy.Encoding as LBS
import Surypus (Pool, QueryResult (..), Bill (..), BillInput (..), Goods (..), Person (..), Payment (..))
import Network.Wai as W
import Servant (Application, Handler, Server, ServerError(..), err401, err403, err404, err500, serve, throwError, (:>), Get, Post, ReqBody, JSON, (:<|>) (..), Capture)
import qualified Data.UUID as UUID
import qualified Data.UUID.V4 as UUID
import qualified Surypus.API.Logger as Log
import qualified Surypus.API.Bills as Bills
import qualified Surypus.API.CRM as CRM
import qualified Surypus.API.Dashboard as Dashboard
import qualified Surypus.API.Goods as Goods
import qualified Surypus.API.Persons as Persons
import qualified Surypus.API.Payment as Payments
import qualified Surypus.WebSocket as WS

data Env = Env
  { envPool :: Pool,
    envLogger :: Log.Logger,
    envWSHandler :: Maybe WS.WebSocketHandler
  }

-- | Application context with both database and WebSocket
type AppContext = Env

-- | Create environment with WebSocket support
mkEnv :: Pool -> Log.Logger -> Maybe WS.WebSocketHandler -> Env
mkEnv pool logger wsHandler = Env pool logger wsHandler

-- | Authenticated user context (for future AuthProtect integration)
data AuthenticatedUser = AuthenticatedUser
  { userId :: Int64,
    username :: DT.Text,
    userRoles :: [DT.Text]
  }
  deriving (Show, Eq)

-- | Correlation ID middleware
correlationMiddleware :: Log.Logger -> Application -> Application
correlationMiddleware logger app req respond = do
  let corrIdHeader = lookup "x-correlation-id" (W.requestHeaders req)
  corrId <- case corrIdHeader of
    Just cid -> return (TE.decodeUtf8 cid)
    Nothing -> UUID.toText <$> UUID.nextRandom
  Log.withCorrelationId logger (DT.unpack corrId) $
    app req respond

-- | Auth check middleware - validates Authorization header
authMiddleware :: Application -> Application
authMiddleware app req respond = do
  let authHeader = lookup "Authorization" (W.requestHeaders req)
  case authHeader of
    Just _ -> app req respond  -- Has auth header, proceed
    Nothing -> respond $ W.responseLBS [W.status401] [("Content-Type", "text/plain")] "Unauthorized"

apiServer :: Pool -> Log.Logger -> Application
apiServer pool logger = apiServerWithWS pool logger Nothing

-- | API server with optional WebSocket handler for event broadcasting
apiServerWithWS :: Pool -> Log.Logger -> Maybe WS.WebSocketHandler -> Application
apiServerWithWS pool logger mbWsHandler =
  let env = Env pool logger mbWsHandler
   in correlationMiddleware logger $ authMiddleware (serve (Proxy @SurypusApi) (server env))

-- | Start server with WebSocket support
startServer :: Pool -> Log.Logger -> IO WS.WebSocketHandler
startServer pool logger = do
  wsHandler <- WS.initWebSocketHandler
  Log.logInfo logger "WebSocket handler initialized" []
  let env = Env pool logger (Just wsHandler)
  Log.logInfo logger "Starting Survant server with WebSocket support" []
  return wsHandler

-- | Full Surypus API type
type SurypusApi =
  "api" :> "v1" :> 
    ( "bills" :> Get '[JSON] [Bill]
      :<|> "bills" :> ReqBody '[JSON] BillInput :> Post '[JSON] Bill
      :<|> "bills" :> Capture "id" Int64 :> Get '[JSON] Bill
      :<|> "bills" :> Capture "id" Int64 :> "post" :> Post '[JSON] ()
      :<|> "goods" :> Get '[JSON] [Goods]
      :<|> "persons" :> Get '[JSON] [Person]
      :<|> "payments" :> Get '[JSON] [Payment]
      :<|> "dashboard" :> Get '[JSON] Dashboard.DashboardKPI
      :<|> "dashboard" :> "revenue" :> Get '[JSON] [Dashboard.RevenuePoint]
      :<|> "dashboard" :> "orders" :> Get '[JSON] [Dashboard.OrderStatus]
      :<|> "dashboard" :> "stock" :> Get '[JSON] [Dashboard.StockSummary]
      :<|> "crm" :> "deals" :> Get '[JSON] [CRM.Deal]
      :<|> "crm" :> "deals" :> ReqBody '[JSON] CRM.DealInput :> Post '[JSON] CRM.Deal
      :<|> "crm" :> "deals" :> Capture "id" Text :> Get '[JSON] CRM.Deal
      :<|> "crm" :> "deals" :> Capture "id" Text :> "stage" :> Capture "stageId" Text :> Post '[JSON] CRM.Deal
      :<|> "crm" :> "pipeline" :> Get '[JSON] [CRM.PipelineForecast]
      :<|> "crm" :> "deals" :> Capture "id" Text :> "activities" :> Get '[JSON] [CRM.Activity]
    )

server :: Env -> Server SurypusApi
server env =
  ( billsList env
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
  )

dashboardKPI :: Env -> Handler Dashboard.DashboardKPI
dashboardKPI env = do
  result <- liftIO $ Dashboard.getDashboardKPI (envPool env)
  case result of
    QuerySuccess kpi -> pure kpi
    QueryError err -> throwError $ err500 {errBody = LBS.encodeUtf8 $ "Dashboard error: " <> TL.fromStrict err}

dashboardRevenue :: Env -> Handler [Dashboard.RevenuePoint]
dashboardRevenue env = do
  result <- liftIO $ Dashboard.getRevenueTrend (envPool env)
  case result of
    QuerySuccess points -> pure points
    QueryError err -> throwError $ err500 {errBody = LBS.encodeUtf8 $ "Dashboard error: " <> TL.fromStrict err}

dashboardOrders :: Env -> Handler [Dashboard.OrderStatus]
dashboardOrders env = do
  result <- liftIO $ Dashboard.getOrderStatuses (envPool env)
  case result of
    QuerySuccess statuses -> pure statuses
    QueryError err -> throwError $ err500 {errBody = LBS.encodeUtf8 $ "Dashboard error: " <> TL.fromStrict err}

dashboardStock :: Env -> Handler [Dashboard.StockSummary]
dashboardStock env = do
  result <- liftIO $ Dashboard.getStockSummary (envPool env)
  case result of
    QuerySuccess summary -> pure summary
    QueryError err -> throwError $ err500 {errBody = LBS.encodeUtf8 $ "Dashboard error: " <> TL.fromStrict err}

crmDealsList :: Env -> Handler [CRM.Deal]
crmDealsList env = do
  result <- liftIO $ CRM.listDeals (envPool env)
  case result of
    QuerySuccess deals -> pure deals
    QueryError err -> throwError $ err500 {errBody = LBS.encodeUtf8 $ "CRM error: " <> TL.fromStrict err}

crmDealCreate :: Env -> CRM.DealInput -> Handler CRM.Deal
crmDealCreate env input = do
  result <- liftIO $ CRM.createDeal (envPool env) input
  case result of
    QuerySuccess deal -> pure deal
    QueryError err -> throwError $ err500 {errBody = LBS.encodeUtf8 $ "CRM error: " <> TL.fromStrict err}

crmDealGet :: Env -> Text -> Handler CRM.Deal
crmDealGet env did = do
  result <- liftIO $ CRM.getDeal (envPool env) did
  case result of
    QuerySuccess deal -> pure deal
    QueryError "Not Found" -> throwError err404
    QueryError err -> throwError $ err500 {errBody = LBS.encodeUtf8 $ "CRM error: " <> TL.fromStrict err}

crmDealStageUpdate :: Env -> Text -> Text -> Handler CRM.Deal
crmDealStageUpdate env did stageId = do
  result <- liftIO $ CRM.updateDealStage (envPool env) did stageId
  case result of
    QuerySuccess deal -> pure deal
    QueryError err -> throwError $ err500 {errBody = LBS.encodeUtf8 $ "CRM error: " <> TL.fromStrict err}

crmPipelineForecast :: Env -> Handler [CRM.PipelineForecast]
crmPipelineForecast env = do
  result <- liftIO $ CRM.getPipelineForecast (envPool env)
  case result of
    QuerySuccess forecast -> pure forecast
    QueryError err -> throwError $ err500 {errBody = LBS.encodeUtf8 $ "CRM error: " <> TL.fromStrict err}

crmDealActivities :: Env -> Text -> Handler [CRM.Activity]
crmDealActivities env did = do
  result <- liftIO $ CRM.listActivities (envPool env) did
  case result of
    QuerySuccess activities -> pure activities
    QueryError err -> throwError $ err500 {errBody = LBS.encodeUtf8 $ "CRM error: " <> TL.fromStrict err}

billsList :: Env -> Handler [Bill]
billsList env = do
  result <- liftIO $ Bills.listBills (envPool env)
  case result of
    QuerySuccess bills -> pure bills
    QueryError err -> throwError $ err500 {errBody = LBS.encodeUtf8 $ "Database error: " <> TL.fromStrict err}

billsCreate :: Env -> BillInput -> Handler Bill
billsCreate env input = do
  result <- liftIO $ Bills.createBill (envPool env) input
  case result of
    QuerySuccess bill -> pure bill
    QueryError err -> throwError $ err500 {errBody = LBS.encodeUtf8 $ "Database error: " <> TL.fromStrict err}

billGet :: Env -> Int64 -> Handler Bill
billGet env bid = do
  result <- liftIO $ Bills.getBill (envPool env) bid
  case result of
    QuerySuccess bill -> pure bill
    QueryError "Not Found" -> throwError err404
    QueryError err -> throwError $ err500 {errBody = LBS.encodeUtf8 $ "Database error: " <> TL.fromStrict err}

-- | Post a bill to update status
billPost :: Env -> Int64 -> Handler ()
billPost env bid = do
  result <- liftIO $ Bills.postBill (envPool env) bid
  case result of
    QuerySuccess () -> pure ()
    QueryError err -> throwError $ err500 {errBody = LBS.encodeUtf8 $ "Database error: " <> TL.fromStrict err}

goodsList :: Env -> Handler [Goods]
goodsList env = do
  result <- liftIO $ Goods.listGoods (envPool env)
  case result of
    QuerySuccess goods -> pure goods
    QueryError err -> throwError $ err500 {errBody = LBS.encodeUtf8 $ "Database error: " <> TL.fromStrict err}

personsList :: Env -> Handler [Person]
personsList env = do
  result <- liftIO $ Persons.listPersons (envPool env) Nothing Nothing Nothing Nothing Nothing
  case result of
    QuerySuccess persons -> pure persons
    QueryError err -> throwError $ err500 {errBody = LBS.encodeUtf8 $ "Database error: " <> TL.fromStrict err}

paymentsList :: Env -> Handler [Payment]
paymentsList env = do
  result <- liftIO $ Payments.listPayments (envPool env)
  case result of
    QuerySuccess payments -> pure payments
    QueryError err -> throwError $ err500 {errBody = LBS.encodeUtf8 $ "Database error: " <> TL.fromStrict err}