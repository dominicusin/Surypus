-- ============================================================================
-- API V1 - Production
-- Production planning and scheduling endpoints
-- ============================================================================

-- ============================================================================
-- API V1 - Production
-- Production planning and scheduling endpoints
-- ============================================================================
module API.V1.Production (productionAPI) where

import Control.Monad.IO.Class (MonadIO (..))
import Data.Aeson (Value (..), encode, object, (.=))
import qualified Data.HashMap.Strict as HM
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.UUID as UUID
import Servant
import Service.Auth (HasJWT, requireJWT, requirePerm)
import qualified Service.ProductionService as PS

-- | Production Tech Cards API
productionTechAPI :: PS.ProductionService -> API
productionTechAPI svc = "tech" :> (getTechCards :<|> createTechCard)
  where
    getTechCards :: Handler [Value]
    getTechCards = do
      result <- liftIO $ PS.listTechCards svc
      return $ map (\tc -> object ["id" .= (1 :: Int64), "name" .= ("default" :: Text)]) result

    createTechCard :: Value -> Handler Value
    createTechCard input = do
      -- Basic input sanity check: must be a non-empty object with a name
      case input of
        Object o | not (HM.null o) && HM.member (T.pack "name") o -> do
          result <- liftIO $ PS.createTechCard svc input
          case result of
            Right tid -> return $ object ["tech_card_id" .= tid]
            Left err -> throwError err500 {errBody = encode err}
        _ -> throwError err400 {errBody = encode $ object ["error" .= ("Invalid input" :: Text)]}

-- | Production Work Orders API
productionWorkOrdersAPI :: PS.ProductionService -> API
productionWorkOrdersAPI svc = "work-orders" :> (getWorkOrders :<|> createWorkOrder)
  where
    getWorkOrders ::
      QueryParam "status" Text
        :. QueryParam "goods_id" Int64
        :. Handler [Value]
    getWorkOrders = \status gid -> do
      result <- liftIO $ PS.listWorkOrders svc status gid
      return []

    createWorkOrder :: Value -> Handler Value
    createWorkOrder input = do
      -- Basic input sanity check: require non-empty object
      case input of
        Object o | not (HM.null o) && HM.member (Data.Text.pack "name") o -> do
          result <- liftIO $ PS.createWorkOrder svc input
          case result of
            Right wid -> return $ object ["work_order_id" .= wid]
            Left err -> throwError err500 {errBody = encode err}
        _ -> throwError err400 {errBody = encode $ object ["error" .= ("Invalid input" :: Text)]}

-- | Work Order Actions API
workOrderActionsAPI :: PS.ProductionService -> API
workOrderActionsAPI svc =
  "work-orders"
    :> capture "id" Int64
    :> (releaseWorkOrder svc :<|> completeWorkOrder svc)
  where
    releaseWorkOrder :: PS.ProductionService -> Int64 -> Handler Value
    releaseWorkOrder s oid = do
      -- invariant: qty_released <= qty_plan
      result <- liftIO $ PS.releaseWorkOrder s oid 1
      case result of
        Right () -> return $ object ["status" .= ("released" :: Text)]
        Left err -> throwError err500 {errBody = encode err}

    completeWorkOrder :: PS.ProductionService -> Int64 -> Handler Value
    completeWorkOrder s oid = do
      result <- liftIO $ PS.completeWorkOrder s oid
      case result of
        Right () -> return $ object ["status" .= ("completed" :: Text)]
        Left err -> throwError err500 {errBody = encode err}

-- | Full production API combining endpoints
productionAPICombined :: PS.ProductionService -> API
productionAPICombined svc = "production" :> (productionTechAPI svc :<|> productionWorkOrdersAPI svc :<|> workOrderActionsAPI svc)

server :: PS.ProductionService -> Server (productionAPICombined PS.ProductionService)
server svc = productionTechServer svc :<|> productionWorkOrdersServer svc :<|> workOrderActionsServer svc
  where
    productionTechServer = serverFor (Proxy :: Proxy (productionAPICombined PS.ProductionService))
    productionWorkOrdersServer = serverFor (Proxy :: Proxy (productionAPICombined PS.ProductionService))
    workOrderActionsServer = serverFor (Proxy :: Proxy (productionAPICombined PS.ProductionService))

app :: PS.ProductionService -> Application
app svc = serveWithContext (Proxy :: Proxy (productionAPICombined PS.ProductionService)) ctx (server svc)
  where
    ctx = ()

runOnPort :: Int -> PS.ProductionService -> IO ()
runOnPort port svc = do
  let cfg = setPort port defaultServConfig
  runSettings cfg $ app svc
