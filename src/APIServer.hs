{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module APIServer
  ( ServerConfig (..),
    RateLimitConfig (..),
    defaultRateLimit,
    runServer,
    healthStatus,
  )
where

import Control.Monad.IO.Class (liftIO)
import Control.Monad.Trans.Except (runExceptT)
import DAL.Queries
import DAL.Repository (Repository (find), RepositoryError (..))
import DAL.Repository.AccPlan (createAccPlanRepo, deleteAccPlanRepo, listAccPlansRepo, updateAccPlanRepo)
import DAL.Repository.AccTurn (createAccTurnRepo, deleteAccTurnRepo, listAccTurnsRepo, updateAccTurnRepo)
import DAL.Repository.Bill (createBillRepo, deleteBillRepo, listBillsPage, updateBillStatusRepo)
import DAL.Repository.Container (RepositoryContainer (..), mkRepositoryContainer)
import DAL.Repository.Currency (createCurrencyRepo, deleteCurrencyRepo, listCurrenciesRepo, updateCurrencyRepo)
import DAL.Repository.Goods (createGoodsRepo, deleteGoodsRepo, listGoodsPage, updateGoodsRepo)
import DAL.Repository.Location (createLocationRepo, deleteLocationRepo, listLocationsRepo, updateLocationRepo)
import DAL.Repository.Order (createOrderRepo, deleteOrderRepo, listOrdersPage, updateOrderStatusRepo)
import DAL.Repository.Payment (createPaymentRepo, deletePaymentRepo, listPaymentsRepo, updatePaymentRepo)
import DAL.Repository.Person (createPersonRepo, deletePersonRepo, listPersonsPage, searchPersonsRepo, updatePersonRepo)
import DAL.Repository.Price (createPriceRepo, listGoodsPricesByGoodsRepo, listGoodsPricesRepo)
import DAL.Repository.Tax (createTaxRepo, deleteTaxRepo, listTaxesRepo, updateTaxRepo)
import DAL.Types
import Data.Aeson (FromJSON, ToJSON, Value (..), object, (.=))
import qualified Data.ByteString.Lazy.Char8 as LBS8
import Data.IORef (IORef, atomicModifyIORef', newIORef, readIORef, writeIORef)
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Encoding as T
import Data.Time (diffUTCTime, getCurrentTime, utctDayTime)
import GHC.Generics (Generic)
import qualified Hasql.Decoders as D
import qualified Hasql.Encoders as E
import Hasql.Pool (Pool, use)
import qualified Hasql.Session as Session
import Hasql.Statement (Statement)
import qualified Network.HTTP.Types as HTTP
import Network.Wai (Middleware, rawPathInfo, requestHeaders, requestMethod, responseLBS, responseStatus)
import Surypus.JWT (JWTPayload (..), defaultJWTConfig, generateSimpleToken)
import Surypus.RBAC (checkPermissions)
import qualified Surypus.Reports as Reports
import Surypus.WebSocket (NotificationType (..), WebSocketHub, WebSocketMessage (..), broadcastMessage)
import System.IO (hFlush, stdout)
import Web.Scotty
import qualified Web.Scotty as Scotty

-- ============================================================================
-- CONFIG
-- ============================================================================

data ServerConfig = ServerConfig
  { scHost :: String,
    scPort :: Int,
    scLogRequests :: Bool,
    scJwtSecret :: Text,
    scRateLimit :: RateLimitConfig,
    scPool :: Pool,
    scWebSocketHub :: Maybe WebSocketHub
  }

data RateLimitConfig = RateLimitConfig
  { rlcRequests :: Int,
    rlcSeconds :: Int,
    rlcStore :: RateLimitStore,
    rlcCurrentTime :: Int
  }
  deriving (Eq)

defaultRateLimit :: IO RateLimitConfig
defaultRateLimit = do
  store <- newIORef ([] :: [(String, (Int, Int))])
  pure $
    RateLimitConfig
      { rlcRequests = 100,
        rlcSeconds = 60,
        rlcStore = store,
        rlcCurrentTime = 0
      }

-- ============================================================================
-- MIDDLEWARE
-- ============================================================================

type RateLimitStore = IORef [(String, (Int, Int))]

cleanOldEntries :: Int -> [(String, (Int, Int))] -> [(String, (Int, Int))]
cleanOldEntries _ [] = []
cleanOldEntries now ((ip, (count, timestamp)) : rest)
  | now - timestamp > 60 = cleanOldEntries now rest
  | otherwise = (ip, (count, timestamp)) : cleanOldEntries now rest

rateLimitMiddleware :: RateLimitConfig -> Middleware
rateLimitMiddleware cfg app req respond = do
  let store = rlcStore cfg
      maxRequests = rlcRequests cfg

  now <- liftIO $ do
    t <- getCurrentTime
    pure (floor (utctDayTime t) :: Int)

  entries <- liftIO $ readIORef store
  let cleaned = cleanOldEntries now entries
      clientIP = show $ requestHeaders req
      currentCount = maybe 0 fst $ lookup (show clientIP) cleaned

  if currentCount >= maxRequests
    then respond $ responseLBS HTTP.status429 [] "Rate limit exceeded"
    else do
      let newCount = currentCount + 1
      liftIO $ writeIORef store ((show clientIP, (newCount, now)) : cleaned)
      app req respond

data MetricsState = MetricsState
  { msHttpRequestsTotal :: Int64,
    msHttpResponses4xx :: Int64,
    msHttpResponses5xx :: Int64
  }

initialMetricsState :: MetricsState
initialMetricsState = MetricsState 0 0 0

metricsMiddleware :: IORef MetricsState -> Middleware
metricsMiddleware metricsRef app req respond = do
  liftIO $ atomicModifyIORef' metricsRef $ \m -> (m {msHttpRequestsTotal = msHttpRequestsTotal m + 1}, ())
  app req $ \res -> do
    let statusCode = HTTP.statusCode (responseStatus res)
    liftIO $ atomicModifyIORef' metricsRef $ \m ->
      if statusCode >= 500
        then (m {msHttpResponses5xx = msHttpResponses5xx m + 1}, ())
        else
          if statusCode >= 400
            then (m {msHttpResponses4xx = msHttpResponses4xx m + 1}, ())
            else (m, ())
    respond res

renderPrometheusMetrics :: MetricsState -> String
renderPrometheusMetrics m =
  unlines
    [ "# HELP surypus_http_requests_total Total HTTP requests",
      "# TYPE surypus_http_requests_total counter",
      "surypus_http_requests_total " <> show (msHttpRequestsTotal m),
      "# HELP surypus_http_responses_4xx_total Total HTTP 4xx responses",
      "# TYPE surypus_http_responses_4xx_total counter",
      "surypus_http_responses_4xx_total " <> show (msHttpResponses4xx m),
      "# HELP surypus_http_responses_5xx_total Total HTTP 5xx responses",
      "# TYPE surypus_http_responses_5xx_total counter",
      "surypus_http_responses_5xx_total " <> show (msHttpResponses5xx m)
    ]

requestLoggingMiddleware :: Middleware
requestLoggingMiddleware app req respond = do
  let method' = show (requestMethod req)
      path' = T.unpack (T.decodeUtf8 (rawPathInfo req))
  start <- liftIO getCurrentTime
  app req $ \res -> do
    end <- liftIO getCurrentTime
    let statusCode = HTTP.statusCode $ responseStatus res
        diff = diffUTCTime end start
    liftIO . putStrLn $
      method'
        <> " "
        <> path'
        <> " "
        <> show statusCode
        <> " "
        <> show diff
    respond res

-- ============================================================================
-- AUTH TYPES
-- ============================================================================

data LoginRequest = LoginRequest
  { lrUsername :: Text,
    lrPassword :: Text
  }
  deriving (Show, Generic)

instance FromJSON LoginRequest

data LoginResponse = LoginResponse
  { token :: Text,
    userId :: Int64,
    role :: Text,
    expiresAt :: Text
  }
  deriving (Show, Generic)

instance ToJSON LoginResponse

data ErrorResponse = ErrorResponse
  { errorCode :: Int,
    errorMessage :: Text
  }
  deriving (Show, Generic)

instance ToJSON ErrorResponse

-- ============================================================================
-- HELPERS
-- ============================================================================

toJSONResult :: (ToJSON a) => QueryResult a -> Value
toJSONResult (QuerySuccess a) = object ["success" .= True, "data" .= a]
toJSONResult (QueryError e) = object ["success" .= False, "error" .= e]

repositoryErrorStatus :: RepositoryError -> HTTP.Status
repositoryErrorStatus repoErr = case repoErr of
  NotFound _ -> HTTP.status404
  ValidationError _ -> HTTP.status400
  DuplicateKey _ -> HTTP.status409
  TransactionError _ -> HTTP.status500
  DatabaseError _ -> HTTP.status500

repositoryErrorMessage :: RepositoryError -> Text
repositoryErrorMessage repoErr = case repoErr of
  NotFound msg -> msg
  ValidationError msg -> msg
  DuplicateKey msg -> msg
  TransactionError msg -> msg
  DatabaseError msg -> msg

respondRepositoryError :: RepositoryError -> ActionM ()
respondRepositoryError repoErr = do
  status (repositoryErrorStatus repoErr)
  json $ object ["success" .= False, "error" .= repositoryErrorMessage repoErr]

publishWebSocketEvent :: Maybe WebSocketHub -> NotificationType -> Text -> Value -> IO ()
publishWebSocketEvent Nothing _ _ _ = pure ()
publishWebSocketEvent (Just hub) eventType eventName payload = do
  now <- getCurrentTime
  broadcastMessage hub (WebSocketMessage eventType eventName payload now)

-- ============================================================================
-- SERVER
-- ============================================================================

runServer :: ServerConfig -> IO ()
runServer cfg = do
  putStrLn "========================================="
  putStrLn "  Surypus HTTP Server v0.1.0"
  putStrLn $ "  Host: " <> scHost cfg <> ":" <> show (scPort cfg)
  putStrLn "========================================="
  putStrLn "Starting Scotty server..."
  hFlush stdout
  metricsRef <- newIORef initialMetricsState

  let port = scPort cfg
      pool = scPool cfg
      wsHub = scWebSocketHub cfg
      repositories = mkRepositoryContainer pool
      personRepo = rcPersonRepository repositories
      goodsRepo = rcGoodsRepository repositories
      locationRepo = rcLocationRepository repositories
      paymentRepo = rcPaymentRepository repositories
      taxRepo = rcTaxRepository repositories
      currencyRepo = rcCurrencyRepository repositories
      priceRepo = rcPriceRepository repositories
      billRepo = rcBillRepository repositories
      orderRepo = rcOrderRepository repositories
      accPlanRepo = rcAccPlanRepository repositories
      accTurnRepo = rcAccTurnRepository repositories

  Scotty.scotty port $ do
    middleware (metricsMiddleware metricsRef)
    middleware (rateLimitMiddleware (scRateLimit cfg))
    middleware requestLoggingMiddleware

    -- Root
    get "/" $ html "<h1>Surypus ERP/CRM v0.1.0</h1>"

    -- Prometheus metrics
    get "/metrics" $ do
      metricsState <- liftIO $ readIORef metricsRef
      setHeader "Content-Type" "text/plain; version=0.0.4; charset=utf-8"
      raw (LBS8.pack (renderPrometheusMetrics metricsState))

    get "/api/v1/metrics" $ do
      metricsState <- liftIO $ readIORef metricsRef
      setHeader "Content-Type" "text/plain; version=0.0.4; charset=utf-8"
      raw (LBS8.pack (renderPrometheusMetrics metricsState))

    -- Login
    post "/api/v1/login" $ do
      input <- jsonData :: ActionM LoginRequest
      let username = lrUsername input
          password = lrPassword input
      if password == "admin123" || password == "demo"
        then do
          let payload = JWTPayload 1 username "admin"
              tokenConfig = defaultJWTConfig
          jwtToken <- liftIO $ generateSimpleToken tokenConfig payload
          json $
            object
              [ "success" .= True,
                "token" .= jwtToken,
                "userId" .= (1 :: Int),
                "role" .= ("admin" :: Text)
              ]
        else do
          json $
            object
              [ "success" .= False,
                "error" .= ("Invalid credentials" :: Text)
              ]

    -- Health
    get "/api/v1/health" $ do
      result <- liftIO $ healthCheck pool
      json result

    get "/api/v1/health/live" $
      json $
        object ["status" .= ("alive" :: Text)]

    get "/api/v1/health/ready" $ do
      ready <- liftIO $ isDatabaseReady pool
      if ready
        then json $ object ["status" .= ("ready" :: Text)]
        else do
          status HTTP.status503
          json $ object ["status" .= ("not_ready" :: Text), "database" .= ("disconnected" :: Text)]

    -- Auth
    post "/api/v1/auth/login" . json $
      LoginResponse
        { token = "token-placeholder",
          userId = 1,
          role = "admin",
          expiresAt = "2026-12-31T23:59:59Z"
        }

    post "/api/v1/auth/logout" . json $
      object ["success" .= True]

    get "/api/v1/auth/me" . json $
      object
        [ "userId" .= (1 :: Int64),
          "username" .= ("admin" :: String),
          "role" .= ("admin" :: String)
        ]

    -- Roles
    get "/api/v1/roles" . json $
      object
        [ "success" .= True,
          "data"
            .= ( [ object ["id" .= (1 :: Int64), "name" .= ("admin" :: Text), "permissions" .= (["admin"] :: [Text])],
                   object ["id" .= (2 :: Int64), "name" .= ("manager" :: Text), "permissions" .= (["read_goods", "write_goods", "read_bills", "write_bills"] :: [Text])],
                   object ["id" .= (3 :: Int64), "name" .= ("cashier" :: Text), "permissions" .= (["read_goods", "read_prices", "write_bills"] :: [Text])],
                   object ["id" .= (4 :: Int64), "name" .= ("accountant" :: Text), "permissions" .= (["read_accounting", "write_accounting", "read_payroll"] :: [Text])]
                 ] ::
                   [Value]
               )
        ]

    -- Persons (with pagination and sorting)
    get "/api/v1/persons" $ do
      let pagination = Pagination 50 0
      repoResult <- liftIO $ runExceptT $ listPersonsPage personRepo defaultPersonFilter pagination Nothing Nothing
      case repoResult of
        Left repoErr -> respondRepositoryError repoErr
        Right page -> json $ object ["success" .= True, "data" .= page]

    get "/api/v1/persons/:id" $ do
      pid <- captureParam "id"
      repoResult <- liftIO $ runExceptT $ find personRepo pid
      case repoResult of
        Left repoErr -> respondRepositoryError repoErr
        Right Nothing -> respondRepositoryError (NotFound "Person not found")
        Right (Just person) -> json $ object ["success" .= True, "data" .= person]

    get "/api/v1/persons/search/:query" $ do
      query <- captureParam "query"
      repoResult <- liftIO $ runExceptT $ searchPersonsRepo personRepo query
      case repoResult of
        Left repoErr -> respondRepositoryError repoErr
        Right persons -> json $ object ["success" .= True, "data" .= persons]

    -- Persons CRUD
    post "/api/v1/persons" $ do
      input <- jsonData :: ActionM PersonInput
      repoResult <- liftIO $ runExceptT $ createPersonRepo personRepo input
      case repoResult of
        Left repoErr -> respondRepositoryError repoErr
        Right person -> do
          liftIO $ publishWebSocketEvent wsHub NTPersonChanged "person.created" (object ["id" .= pId person])
          json $ object ["success" .= True, "data" .= person]

    put "/api/v1/persons/:id" $ do
      pid <- captureParam "id"
      input <- jsonData :: ActionM PersonInput
      repoResult <- liftIO $ runExceptT $ updatePersonRepo personRepo pid input
      case repoResult of
        Left repoErr -> respondRepositoryError repoErr
        Right person -> do
          liftIO $ publishWebSocketEvent wsHub NTPersonChanged "person.updated" (object ["id" .= pId person])
          json $ object ["success" .= True, "data" .= person]

    delete "/api/v1/persons/:id" $ do
      pid <- captureParam "id"
      repoResult <- liftIO $ runExceptT $ deletePersonRepo personRepo pid
      case repoResult of
        Left repoErr -> respondRepositoryError repoErr
        Right () -> do
          liftIO $ publishWebSocketEvent wsHub NTPersonChanged "person.deleted" (object ["id" .= pid])
          json $ object ["success" .= True]

    -- Goods (with pagination)
    get "/api/v1/goods" $ do
      checkPermissions [PermRead EntityGoods]
      let pagination = Pagination 50 0
      repoResult <- liftIO $ runExceptT $ listGoodsPage goodsRepo defaultGoodsFilter pagination Nothing Nothing
      case repoResult of
        Left repoErr -> respondRepositoryError repoErr
        Right page -> json $ object ["success" .= True, "data" .= page]

    -- Goods CRUD
    post "/api/v1/goods" $ do
      input <- jsonData :: ActionM GoodsInput
      repoResult <- liftIO $ runExceptT $ createGoodsRepo goodsRepo input
      case repoResult of
        Left repoErr -> respondRepositoryError repoErr
        Right goods -> do
          liftIO $ publishWebSocketEvent wsHub NTGoodsChanged "goods.created" (object ["id" .= gId goods])
          json $ object ["success" .= True, "data" .= goods]

    put "/api/v1/goods/:id" $ do
      gid <- captureParam "id"
      input <- jsonData :: ActionM GoodsInput
      repoResult <- liftIO $ runExceptT $ updateGoodsRepo goodsRepo gid input
      case repoResult of
        Left repoErr -> respondRepositoryError repoErr
        Right goods -> do
          liftIO $ publishWebSocketEvent wsHub NTGoodsChanged "goods.updated" (object ["id" .= gId goods])
          json $ object ["success" .= True, "data" .= goods]

    delete "/api/v1/goods/:id" $ do
      gid <- captureParam "id"
      repoResult <- liftIO $ runExceptT $ deleteGoodsRepo goodsRepo gid
      case repoResult of
        Left repoErr -> respondRepositoryError repoErr
        Right () -> do
          liftIO $ publishWebSocketEvent wsHub NTGoodsChanged "goods.deleted" (object ["id" .= gid])
          json $ object ["success" .= True]

    -- Locations
    get "/api/v1/locations" $ do
      repoResult <- liftIO $ runExceptT $ listLocationsRepo locationRepo
      case repoResult of
        Left repoErr -> respondRepositoryError repoErr
        Right locations -> json $ object ["success" .= True, "data" .= locations]

    -- Locations CRUD
    post "/api/v1/locations" $ do
      input <- jsonData :: ActionM LocationInput
      repoResult <- liftIO $ runExceptT $ createLocationRepo locationRepo input
      case repoResult of
        Left repoErr -> respondRepositoryError repoErr
        Right location -> json $ object ["success" .= True, "data" .= location]

    put "/api/v1/locations/:id" $ do
      lid <- captureParam "id"
      input <- jsonData :: ActionM LocationInput
      repoResult <- liftIO $ runExceptT $ updateLocationRepo locationRepo lid input
      case repoResult of
        Left repoErr -> respondRepositoryError repoErr
        Right location -> json $ object ["success" .= True, "data" .= location]

    delete "/api/v1/locations/:id" $ do
      lid <- captureParam "id"
      repoResult <- liftIO $ runExceptT $ deleteLocationRepo locationRepo lid
      case repoResult of
        Left repoErr -> respondRepositoryError repoErr
        Right () -> json $ object ["success" .= True]

    -- Bills (with pagination)
    get "/api/v1/bills" $ do
      checkPermissions [PermRead EntityBills]
      let pagination = Pagination 50 0
      repoResult <- liftIO $ runExceptT $ listBillsPage billRepo defaultBillFilter pagination Nothing Nothing
      case repoResult of
        Left repoErr -> respondRepositoryError repoErr
        Right page -> json $ object ["success" .= True, "data" .= page]

    -- Create Bill
    post "/api/v1/bills" $ do
      input <- jsonData :: ActionM BillInput
      repoResult <- liftIO $ runExceptT $ createBillRepo billRepo input
      case repoResult of
        Left repoErr -> respondRepositoryError repoErr
        Right bill -> do
          liftIO $ publishWebSocketEvent wsHub NTBillChanged "bill.created" (object ["id" .= bId bill])
          json $ object ["success" .= True, "data" .= bill]

    -- Update Bill Status
    put "/api/v1/bills/:id/status" $ do
      bid <- captureParam "id"
      newStatus :: Int <- queryParam "status"
      repoResult <- liftIO $ runExceptT $ updateBillStatusRepo billRepo bid newStatus
      case repoResult of
        Left repoErr -> respondRepositoryError repoErr
        Right updatedId -> do
          liftIO $ publishWebSocketEvent wsHub NTBillChanged "bill.status_updated" (object ["id" .= updatedId, "status" .= newStatus])
          json $ object ["success" .= True, "id" .= updatedId]

    -- Delete Bill
    delete "/api/v1/bills/:id" $ do
      bid <- captureParam "id"
      repoResult <- liftIO $ runExceptT $ deleteBillRepo billRepo bid
      case repoResult of
        Left repoErr -> respondRepositoryError repoErr
        Right () -> do
          liftIO $ publishWebSocketEvent wsHub NTBillChanged "bill.deleted" (object ["id" .= bid])
          json $ object ["success" .= True]

    -- Payments
    get "/api/v1/payments" $ do
      repoResult <- liftIO $ runExceptT $ listPaymentsRepo paymentRepo
      case repoResult of
        Left repoErr -> respondRepositoryError repoErr
        Right payments -> json $ object ["success" .= True, "data" .= payments]

    get "/api/v1/payments/:id" $ do
      paymentId <- captureParam "id"
      repoResult <- liftIO $ runExceptT $ find paymentRepo paymentId
      case repoResult of
        Left repoErr -> respondRepositoryError repoErr
        Right Nothing -> respondRepositoryError (NotFound "Payment not found")
        Right (Just payment) -> json $ object ["success" .= True, "data" .= payment]

    post "/api/v1/payments" $ do
      input <- jsonData :: ActionM PaymentInput
      repoResult <- liftIO $ runExceptT $ createPaymentRepo paymentRepo input
      case repoResult of
        Left repoErr -> respondRepositoryError repoErr
        Right payment -> do
          liftIO $ publishWebSocketEvent wsHub NTPaymentChanged "payment.created" (object ["id" .= payId payment])
          json $ object ["success" .= True, "data" .= payment]

    put "/api/v1/payments/:id" $ do
      paymentId <- captureParam "id"
      input <- jsonData :: ActionM PaymentInput
      repoResult <- liftIO $ runExceptT $ updatePaymentRepo paymentRepo paymentId input
      case repoResult of
        Left repoErr -> respondRepositoryError repoErr
        Right payment -> do
          liftIO $ publishWebSocketEvent wsHub NTPaymentChanged "payment.updated" (object ["id" .= payId payment])
          json $ object ["success" .= True, "data" .= payment]

    delete "/api/v1/payments/:id" $ do
      paymentId <- captureParam "id"
      repoResult <- liftIO $ runExceptT $ deletePaymentRepo paymentRepo paymentId
      case repoResult of
        Left repoErr -> respondRepositoryError repoErr
        Right () -> do
          liftIO $ publishWebSocketEvent wsHub NTPaymentChanged "payment.deleted" (object ["id" .= paymentId])
          json $ object ["success" .= True]

    -- Orders (with pagination)
    get "/api/v1/orders" $ do
      checkPermissions [PermRead EntityOrders]
      let pagination = Pagination 50 0
      repoResult <- liftIO $ runExceptT $ listOrdersPage orderRepo defaultOrderFilter pagination Nothing Nothing
      case repoResult of
        Left repoErr -> respondRepositoryError repoErr
        Right page -> json $ object ["success" .= True, "data" .= page]

    -- Create Order
    post "/api/v1/orders" $ do
      input <- jsonData :: ActionM OrderInput
      repoResult <- liftIO $ runExceptT $ createOrderRepo orderRepo input
      case repoResult of
        Left repoErr -> respondRepositoryError repoErr
        Right orderVal -> do
          liftIO $ publishWebSocketEvent wsHub NTOrderChanged "order.created" (object ["id" .= oId orderVal])
          json $ object ["success" .= True, "data" .= orderVal]

    -- Update Order Status
    put "/api/v1/orders/:id/status" $ do
      oid <- captureParam "id"
      newStatus :: Int <- queryParam "status"
      repoResult <- liftIO $ runExceptT $ updateOrderStatusRepo orderRepo oid newStatus
      case repoResult of
        Left repoErr -> respondRepositoryError repoErr
        Right updatedId -> do
          liftIO $ publishWebSocketEvent wsHub NTOrderChanged "order.status_updated" (object ["id" .= updatedId, "status" .= newStatus])
          json $ object ["success" .= True, "id" .= updatedId]

    -- Delete Order
    delete "/api/v1/orders/:id" $ do
      oid <- captureParam "id"
      repoResult <- liftIO $ runExceptT $ deleteOrderRepo orderRepo oid
      case repoResult of
        Left repoErr -> respondRepositoryError repoErr
        Right () -> do
          liftIO $ publishWebSocketEvent wsHub NTOrderChanged "order.deleted" (object ["id" .= oid])
          json $ object ["success" .= True]

    -- Goods Prices
    get "/api/v1/goods/prices" $ do
      repoResult <- liftIO $ runExceptT $ listGoodsPricesRepo priceRepo
      case repoResult of
        Left repoErr -> respondRepositoryError repoErr
        Right prices -> json $ object ["success" .= True, "data" .= prices]

    get "/api/v1/goods/:id/prices" $ do
      gid <- captureParam "id"
      repoResult <- liftIO $ runExceptT $ listGoodsPricesByGoodsRepo priceRepo gid
      case repoResult of
        Left repoErr -> respondRepositoryError repoErr
        Right prices -> json $ object ["success" .= True, "data" .= prices]

    -- Create Price
    post "/api/v1/goods/prices" $ do
      input <- jsonData :: ActionM PriceInput
      repoResult <- liftIO $ runExceptT $ createPriceRepo priceRepo input
      case repoResult of
        Left repoErr -> respondRepositoryError repoErr
        Right priceVal -> do
          liftIO $ publishWebSocketEvent wsHub NTGoodsChanged "goods.price_created" (object ["id" .= gpId priceVal, "goodsId" .= gpGoodsId priceVal])
          json $ object ["success" .= True, "data" .= priceVal]

    -- Units
    get "/api/v1/units" $ do
      result <- liftIO $ getUnits pool
      json $ toJSONResult result

    -- Document Operation Kinds (Bill types)
    get "/api/v1/document-types" $ do
      result <- liftIO $ getDocumentOpKinds pool
      json $ toJSONResult result

    -- Tax
    get "/api/v1/taxes" $ do
      repoResult <- liftIO $ runExceptT $ listTaxesRepo taxRepo
      case repoResult of
        Left repoErr -> respondRepositoryError repoErr
        Right taxes -> json $ object ["success" .= True, "data" .= taxes]

    get "/api/v1/taxes/:id" $ do
      tid <- captureParam "id"
      repoResult <- liftIO $ runExceptT $ find taxRepo tid
      case repoResult of
        Left repoErr -> respondRepositoryError repoErr
        Right Nothing -> respondRepositoryError (NotFound "Tax not found")
        Right (Just taxVal) -> json $ object ["success" .= True, "data" .= taxVal]

    -- Create Tax
    post "/api/v1/taxes" $ do
      input <- jsonData :: ActionM TaxInput
      repoResult <- liftIO $ runExceptT $ createTaxRepo taxRepo input
      case repoResult of
        Left repoErr -> respondRepositoryError repoErr
        Right taxVal -> do
          liftIO $ publishWebSocketEvent wsHub NTTaxChanged "tax.created" (object ["id" .= taxId taxVal])
          json $ object ["success" .= True, "data" .= taxVal]

    put "/api/v1/taxes/:id" $ do
      tid <- captureParam "id"
      input <- jsonData :: ActionM TaxInput
      repoResult <- liftIO $ runExceptT $ updateTaxRepo taxRepo tid input
      case repoResult of
        Left repoErr -> respondRepositoryError repoErr
        Right taxVal -> do
          liftIO $ publishWebSocketEvent wsHub NTTaxChanged "tax.updated" (object ["id" .= taxId taxVal])
          json $ object ["success" .= True, "data" .= taxVal]

    -- Delete Tax
    delete "/api/v1/taxes/:id" $ do
      tid <- captureParam "id"
      repoResult <- liftIO $ runExceptT $ deleteTaxRepo taxRepo tid
      case repoResult of
        Left repoErr -> respondRepositoryError repoErr
        Right () -> do
          liftIO $ publishWebSocketEvent wsHub NTTaxChanged "tax.deleted" (object ["id" .= tid])
          json $ object ["success" .= True]

    -- Currency
    get "/api/v1/currencies" $ do
      repoResult <- liftIO $ runExceptT $ listCurrenciesRepo currencyRepo
      case repoResult of
        Left repoErr -> respondRepositoryError repoErr
        Right currencies -> json $ object ["success" .= True, "data" .= currencies]

    get "/api/v1/currencies/:id" $ do
      cid <- captureParam "id"
      repoResult <- liftIO $ runExceptT $ find currencyRepo cid
      case repoResult of
        Left repoErr -> respondRepositoryError repoErr
        Right Nothing -> respondRepositoryError (NotFound "Currency not found")
        Right (Just currency) -> json $ object ["success" .= True, "data" .= currency]

    -- Create Currency
    post "/api/v1/currencies" $ do
      input <- jsonData :: ActionM CurrencyInput
      repoResult <- liftIO $ runExceptT $ createCurrencyRepo currencyRepo input
      case repoResult of
        Left repoErr -> respondRepositoryError repoErr
        Right currency -> do
          liftIO $ publishWebSocketEvent wsHub NTCurrencyChanged "currency.created" (object ["id" .= currId currency])
          json $ object ["success" .= True, "data" .= currency]

    put "/api/v1/currencies/:id" $ do
      cid <- captureParam "id"
      input <- jsonData :: ActionM CurrencyInput
      repoResult <- liftIO $ runExceptT $ updateCurrencyRepo currencyRepo cid input
      case repoResult of
        Left repoErr -> respondRepositoryError repoErr
        Right currency -> do
          liftIO $ publishWebSocketEvent wsHub NTCurrencyChanged "currency.updated" (object ["id" .= currId currency])
          json $ object ["success" .= True, "data" .= currency]

    -- Delete Currency
    delete "/api/v1/currencies/:id" $ do
      cid <- captureParam "id"
      repoResult <- liftIO $ runExceptT $ deleteCurrencyRepo currencyRepo cid
      case repoResult of
        Left repoErr -> respondRepositoryError repoErr
        Right () -> do
          liftIO $ publishWebSocketEvent wsHub NTCurrencyChanged "currency.deleted" (object ["id" .= cid])
          json $ object ["success" .= True]

    -- Inventory Documents
    get "/api/v1/inventory" $ do
      result <- liftIO $ getInventoryDocuments pool
      json $ toJSONResult result

    -- Stock
    get "/api/v1/stock" $ do
      lid <- queryParam "location_id"
      result <- liftIO $ getStockByLocation pool lid
      json $ toJSONResult result

    get "/api/v1/stock/:gid/locations/:lid" $ do
      gid <- captureParam "gid"
      lid <- captureParam "lid"
      result <- liftIO $ getStock pool gid lid
      json $ toJSONResult result

    get "/api/v1/stock/goods/:gid" $ do
      gid <- captureParam "gid"
      result <- liftIO $ getStockByGoods pool gid
      json $ toJSONResult result

    -- Stock summary (all stock)
    get "/api/v1/stock/summary" $ do
      result <- liftIO $ getStockAll pool
      json $ toJSONResult result

    -- Users
    get "/api/v1/users" $ do
      result <- liftIO $ getUsers pool
      json $ toJSONResult result

    -- Dashboard
    get "/api/v1/dashboard" $ do
      result <- liftIO $ getDashboardStats pool
      json $ toJSONResult result

    -- Sales Summary (last N days)
    get "/api/v1/sales/summary" $ do
      days <- queryParam "days"
      limit <- queryParam "limit"
      result <- liftIO $ getSalesSummary pool days limit
      json $ toJSONResult result

    -- Top Selling Goods
    get "/api/v1/goods/top" $ do
      limit <- queryParam "limit"
      result <- liftIO $ getTopSellingGoods pool limit
      json $ toJSONResult result

    -- Low Stock Goods
    get "/api/v1/goods/low-stock" $ do
      result <- liftIO $ getLowStockGoods pool
      json $ toJSONResult result

    -- Accounting
    get "/api/v1/accounting" $ do
      result <- liftIO $ getAccPlans pool
      json $ toJSONResult result

    get "/api/v1/accounting/accounts" $ do
      result <- liftIO $ getAccPlans pool
      json $ toJSONResult result

    get "/api/v1/accounting/accounts/:id" $ do
      pid <- captureParam "id"
      result <- liftIO $ getAccPlanById pool pid
      json $ toJSONResult result

    -- Create AccPlan
    post "/api/v1/accounting/accounts" $ do
      input <- jsonData :: ActionM AccPlanInput
      repoResult <- liftIO $ runExceptT $ createAccPlanRepo accPlanRepo input
      case repoResult of
        Left repoErr -> respondRepositoryError repoErr
        Right accPlanVal -> do
          liftIO $ publishWebSocketEvent wsHub NTAccountingChanged "account_plan.created" (object ["id" .= apId accPlanVal])
          json $ object ["success" .= True, "data" .= accPlanVal]

    -- Update AccPlan
    put "/api/v1/accounting/accounts/:id" $ do
      pid <- captureParam "id"
      input <- jsonData :: ActionM AccPlanInput
      repoResult <- liftIO $ runExceptT $ updateAccPlanRepo accPlanRepo pid input
      case repoResult of
        Left repoErr -> respondRepositoryError repoErr
        Right accPlanVal -> do
          liftIO $ publishWebSocketEvent wsHub NTAccountingChanged "account_plan.updated" (object ["id" .= apId accPlanVal])
          json $ object ["success" .= True, "data" .= accPlanVal]

    -- Delete AccPlan
    delete "/api/v1/accounting/accounts/:id" $ do
      pid <- captureParam "id"
      repoResult <- liftIO $ runExceptT $ deleteAccPlanRepo accPlanRepo pid
      case repoResult of
        Left repoErr -> respondRepositoryError repoErr
        Right () -> do
          liftIO $ publishWebSocketEvent wsHub NTAccountingChanged "account_plan.deleted" (object ["id" .= pid])
          json $ object ["success" .= True]

    -- Accounting entries (turns)
    get "/api/v1/accounting/entries" $ do
      result <- liftIO $ getAccTurns pool
      json $ toJSONResult result

    -- Get AccTurn by ID
    get "/api/v1/accounting/entries/:id" $ do
      turnId <- captureParam "id"
      repoResult <- liftIO $ runExceptT $ find accTurnRepo turnId
      case repoResult of
        Left repoErr -> respondRepositoryError repoErr
        Right Nothing -> respondRepositoryError (NotFound "Accounting entry not found")
        Right (Just accTurnVal) -> json $ object ["success" .= True, "data" .= accTurnVal]

    -- Create AccTurn
    post "/api/v1/accounting/entries" $ do
      input <- jsonData :: ActionM AccTurnInput
      repoResult <- liftIO $ runExceptT $ createAccTurnRepo accTurnRepo input
      case repoResult of
        Left repoErr -> respondRepositoryError repoErr
        Right accTurnVal -> do
          liftIO $ publishWebSocketEvent wsHub NTAccountingChanged "account_entry.created" (object ["id" .= atId accTurnVal])
          json $ object ["success" .= True, "data" .= accTurnVal]

    -- Update AccTurn
    put "/api/v1/accounting/entries/:id" $ do
      turnId <- captureParam "id"
      input <- jsonData :: ActionM AccTurnInput
      repoResult <- liftIO $ runExceptT $ updateAccTurnRepo accTurnRepo turnId input
      case repoResult of
        Left repoErr -> respondRepositoryError repoErr
        Right accTurnVal -> do
          liftIO $ publishWebSocketEvent wsHub NTAccountingChanged "account_entry.updated" (object ["id" .= atId accTurnVal])
          json $ object ["success" .= True, "data" .= accTurnVal]

    -- Delete AccTurn
    delete "/api/v1/accounting/entries/:id" $ do
      turnId <- captureParam "id"
      repoResult <- liftIO $ runExceptT $ deleteAccTurnRepo accTurnRepo turnId
      case repoResult of
        Left repoErr -> respondRepositoryError repoErr
        Right () -> do
          liftIO $ publishWebSocketEvent wsHub NTAccountingChanged "account_entry.deleted" (object ["id" .= turnId])
          json $ object ["success" .= True]

    -- Payroll
    get "/api/v1/payroll" $ do
      result <- liftIO $ getEmployees pool
      json $ toJSONResult result

    get "/api/v1/payroll/employees" $ do
      result <- liftIO $ getEmployees pool
      json $ toJSONResult result

    get "/api/v1/payroll/employees/:id" $ do
      eid <- captureParam "id"
      result <- liftIO $ getEmployeeById pool eid
      json $ toJSONResult result

    get "/api/v1/payroll/salary/:eid" $ do
      eid <- captureParam "eid"
      result <- liftIO $ getSalaryByEmployee pool eid
      json $ toJSONResult result

    get "/api/v1/payroll/salaries" $ do
      result <- liftIO $ getSalaries pool
      json $ toJSONResult result

    -- Jobs (stub - no jobs table in DB)
    get "/api/v1/jobs" . json $ object ["items" .= ([] :: [Value])]
    get "/api/v1/jobs/pending" . json $ object ["count" .= (0 :: Int)]
    post "/api/v1/jobs" . json $ object ["jobId" .= (1 :: Int64)]

    -- Reports
    get "/api/v1/reports/metadata" $ do
      reportMeta <- liftIO Reports.getReportsMetadata
      json $ object ["success" .= True, "data" .= reportMeta]

    get "/api/v1/reports/jrxml/:name" $ do
      reportName <- captureParam "name"
      mjrxml <- liftIO $ Reports.generateReportJRXML reportName
      case mjrxml of
        Nothing -> respondRepositoryError (NotFound "Report template not found")
        Just jrxml -> json $ object ["success" .= True, "name" .= reportName, "jrxml" .= jrxml]

    get "/api/v1/reports" $ do
      result <- liftIO $ getReports pool
      json $ toJSONResult result

    get "/api/v1/reports/templates" $ do
      result <- liftIO $ getReports pool
      json $ toJSONResult result

    get "/api/v1/reports/:id" $ do
      rid <- captureParam "id"
      result <- liftIO $ getReportById pool rid
      json $ toJSONResult result

    post "/api/v1/reports" . json $ object ["reportId" .= (1 :: Int64)]

healthStatus :: IO Text
healthStatus = pure "healthy"

isDatabaseReady :: Pool -> IO Bool
isDatabaseReady pool = do
  let stmt :: Statement () Int
      stmt = Statement "SELECT 1" E.noParams (D.singleRow (D.column (D.nonNullable D.int8))) True
  result <- use pool $ Session.statement () stmt
  case result of
    Left _ -> pure False
    Right _ -> pure True

healthCheck :: Pool -> IO Value
healthCheck pool = do
  ready <- isDatabaseReady pool
  if ready
    then pure $ object ["status" .= ("healthy" :: Text), "database" .= ("connected" :: Text)]
    else pure $ object ["status" .= ("unhealthy" :: Text), "database" .= ("disconnected" :: Text)]
