{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

-- | API Server module for the Surypus ERP system.
--
-- This module defines the HTTP API server using the Scotty web framework.
-- It includes configuration types, route definitions, and server startup logic.
--
-- The server exposes RESTful endpoints for managing entities such as persons,
-- goods, bills, orders, payments, and more. It also includes middleware for
-- CORS, rate limiting, and JSON request/response handling.
--
-- Example usage:
-- @
-- main :: IO ()
-- main = do
--   pool <- createConnectionPool
--   let config = ServerConfig
--         { scHost = "127.0.0.1"
--         , scPort = 8080
--         , scPool = pool
--         , scWebSocketHub = undefined -- TODO: Initialize WebSocket hub
--         }
--   runServer config
-- @
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
import Data.Int (Int16, Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (Day, diffUTCTime, fromGregorian, getCurrentTime, utctDay, utctDayTime)
import GHC.Generics (Generic)
import qualified Hasql.Decoders as D
import qualified Hasql.Encoders as E
import Hasql.Pool (Pool, use)
import qualified Hasql.Session as Session
import Hasql.Statement (Statement)
import qualified Network.HTTP.Types as HTTP
import Network.Wai (Middleware, rawPathInfo, requestHeaders, requestMethod, responseLBS, responseStatus)
import Service.PersonService (PersonService, defaultPersonService, listPersons)
import Surypus.Config (loadAppConfig)
import Surypus.JWT (JWTPayload (..), defaultJWTConfig, generateSimpleToken, jwtConfigFromSecret)
import Surypus.RBAC (checkPermissions)
import qualified Surypus.Reports as Reports
import Surypus.WebSocket (NotificationType (..), WebSocketHub, WebSocketMessage (..), broadcastMessage)
import Data.Maybe (fromMaybe)
import Control.Concurrent.STM (newTQueueIO)
import Surypus.Cache (Cache, createCache)
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

respondAppError :: AppError -> ActionM ()
respondAppError err = case err of
  RepoError repoErr -> respondRepositoryError repoErr
  ValidationError msg -> do
    status HTTP.status400
    json $ object ["success" .= False, "error" .= msg]
  NotFound msg -> do
    status HTTP.status404
    json $ object ["success" .= False, "error" .= msg]
  DatabaseError msg -> do
    status HTTP.status500
    json $ object ["success" .= False, "error" .= msg]
  AuthError msg -> do
    status HTTP.status401
    json $ object ["success" .= False, "error" .= msg]
  RateLimitError -> do
    status HTTP.status429
    json $ object ["success" .= False, "error" .= ("Rate limit exceeded" :: Text)]
  InternalError msg -> do
    status HTTP.status500
    json $ object ["success" .= False, "error" .= msg]

-- | Build the AppEnv from the ServerConfig and environment variables.
buildAppEnv :: ServerConfig -> IO AppEnv
buildAppEnv cfg = do
   cache <- createCache
   mJwtSecret <- fmap pack <$> lookupEnv "JWT_SECRET"
   let jwtSecret' = fromMaybe (scJwtSecret cfg) mJwtSecret
   rateLimitReqStr <- fromMaybe "" <$> lookupEnv "RATE_LIMIT_REQUESTS"
   rateLimitSecStr <- fromMaybe "" <$> lookupEnv "RATE_LIMIT_SECONDS"
   let rateLimitReq = if null rateLimitReqStr then 100 else read rateLimitReqStr
       rateLimitSec = if null rateLimitSecStr then 60 else read rateLimitSecStr
   rateLimitStore <- newIORef []
   let rateLimitConfig = RateLimitConfig rateLimitReq rateLimitSec rateLimitStore 0
   enableWS <- (== "true") . fromMaybe "false" <$> lookupEnv "ENABLE_WEBSOCKET"
   let hub = if enableWS then scWebSocketHub cfg else Nothing
   jobQueue <- newTQueueIO
   let repos = mkRepositoryContainer (scPool cfg)
       services = mkServiceContainer repos
   in pure AppEnv
      { aePool = scPool cfg
      , aeCache = cache
      , aeConfig = AppConfig
          { acDatabase = scDatabase cfg
          , acJwtSecret = jwtSecret'
          , acRateLimit = rateLimitConfig
          , acWebSocketHub = hub
          }
      , aeServices = services
      , aeRepositories = repos
      , aeJobQueue = jobQueue
      , aeWebsocketHub = hub
      }

publishWebSocketEvent :: Maybe WebSocketHub -> NotificationType -> Text -> Value -> IO ()
publishWebSocketEvent Nothing _ _ _ = pure ()
publishWebSocketEvent (Just hub) eventType eventName payload = do
  now <- getCurrentTime
  broadcastMessage hub (WebSocketMessage eventType eventName payload now)

parseDate :: Text -> Day
parseDate s = case reads (T.unpack s) of
  [(d, "")] -> d
  _ -> fromGregorian 2024 1 1

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


      middleware
      (metricsMiddleware metricsRef)
      middleware
      (rateLimitMiddleware (scRateLimit cfg))
      middleware
      requestLoggingMiddleware
      -- Root
      get
      "/"
      $ html
        "<h1>Surypus ERP/CRM v0.1.0</h1>"
        -- Prometheus metrics
        get
        "/metrics"
      $ do
        metricsState <- liftIO $ readIORef metricsRef
        setHeader "Content-Type" "text/plain; version=0.0.4; charset=utf-8"
        raw (LBS8.pack (renderPrometheusMetrics metricsState))
       get
       "/api/v1/metrics"
      $ do
        metricsState <- liftIO $ readIORef metricsRef
        setHeader "Content-Type" "text/plain; version=0.0.4; charset=utf-8"
        raw (LBS8.pack (renderPrometheusMetrics metricsState))

       -- Login
       post
       "/api/v1/login"
      $ do
        input <- jsonData :: ActionM LoginRequest
        let username = lrUsername input
            password = lrPassword input
        repoResult <- liftIO $ runExceptT $ do
          userRepo <- liftIO $ asks rcUserRepository
          maybeUser <- findByLogin userRepo username
          case maybeUser of
            Nothing -> throwE (ValidationError "Invalid credentials")
            Just user -> do
              authResult <- liftIO $ verifyUserCredentials (urPool userRepo) username password
              case authResult of
                Nothing -> throwE (ValidationError "Invalid credentials")
                Just authUser -> do
                  let payload = JWTPayload (fromIntegral (appUserId authUser)) (appUserLogin authUser) (appUserRole authUser)
                  tokenConfig <- liftIO $ jwtConfigFromSecret <$> (pure scJwtSecret)
                  accessToken <- generateAccessToken tokenConfig payload
                  case accessToken of
                    Left err -> throwE (InternalError err)
                    Right token -> return token
        case repoResult of
          Left repoErr -> respondRepositoryError repoErr
          Right token -> json $ object ["success" .= True, "token" .= token]

        -- Health
        get
        "/api/v1/health"
       $ do
         appEnv <- liftIO $ buildAppEnv cfg
         result <- liftIO $ runAppM appEnv $ do
           p <- asks aePool
           liftIO $ healthCheck p
         case result of
           Left err -> respondAppError err
           Right health -> json health
       get
       "/api/v1/health/live"
      $ json
      $ object
        ["status" .= ("alive" :: Text)]
        get
        "/api/v1/health/ready"
      $ do
        ready <- liftIO $ isDatabaseReady pool
        if ready
          then json $ object ["status" .= ("ready" :: Text)]
          else do
            status HTTP.status503
            json $ object ["status" .= ("not_ready" :: Text), "database" .= ("disconnected" :: Text)]

        -- Auth
        post
        "/api/v1/auth/login"
       $ do
         appEnv <- liftIO $ buildAppEnv cfg
         input <- jsonData :: ActionM LoginRequest
         let username = lrUsername input
             password = lrPassword input
         result <- liftIO $ runAppM appEnv $ do
           userRepo <- getRepository
           maybeAppUser <- runExceptT $ do
             appUserOpt <- findByLogin userRepo username
             case appUserOpt of
               Nothing -> throwE (ValidationError "Invalid credentials")
               Just appUser -> do
                 verified <- liftIO $ verifyUserCredentials (urPool userRepo) username password
                 case verified of
                   Nothing -> throwE (ValidationError "Invalid credentials")
                   Just verifiedAppUser -> pure verifiedAppUser
           case maybeAppUser of
             Left appErr -> throwE appErr
             Right appUser -> do
               let payload = JWTPayload (fromIntegral (appUserId appUser)) (appUserLogin appUser) (appUserRole appUser)
               tokenConfig <- jwtConfigFromSecret <$> (pure scJwtSecret)
               accessToken <- generateAccessToken tokenConfig payload
               case accessToken of
                 Left err -> throwE (InternalError err)
                 Right token -> return $ LoginResponse
                   { token = token
                   , userId = fromIntegral (appUserId appUser)
                   , role = appUserRole appUser
                   , expiresAt = "" -- We'll set this properly later if needed
                   }
         case result of
           Left appErr -> respondAppError appErr
           Right loginResponse -> json loginResponse
        post
        "/api/v1/auth/logout"
        . json
      $ object
        ["success" .= True]
        get
        "/api/v1/auth/me"
        . json
      $ object
        [ "userId" .= (1 :: Int64),
          "username" .= ("admin" :: String),
          "role" .= ("admin" :: String)
        ]
        -- Roles
        get
        "/api/v1/roles"
       $ do
         appEnv <- liftIO $ buildAppEnv cfg
         result <- liftIO $ runAppM appEnv $ do
           -- In a real implementation, we would fetch roles from the database
           -- For now, we'll return the same hardcoded data but through AppM
           let roles = [ object ["id" .= (1 :: Int64), "name" .= ("admin" :: Text), "permissions" .= (["admin"] :: [Text])],
                       object ["id" .= (2 :: Int64), "name" .= ("manager" :: Text), "permissions" .= (["read_goods", "write_goods", "read_bills", "write_bills"] :: [Text])],
                       object ["id" .= (3 :: Int64), "name" .= ("cashier" :: Text), "permissions" .= (["read_goods", "read_prices", "write_bills"] :: [Text])],
                       object ["id" .= (4 :: Int64), "name" .= ("accountant" :: Text), "permissions" .= (["read_accounting", "write_accounting", "read_payroll"] :: [Text])]
                     ]
           pure $ object [ "success" .= True, "data" .= roles ]
         case result of
           Left appErr -> respondAppError appErr
           Right rolesResponse -> json rolesResponse
        -- Persons (with pagination and sorting)
        get
        "/api/v1/persons"
      $ do
        let pagination = Pagination 50 0
        result <- liftIO $ runAppM env $ do
          personService <- getPersonService
          listPersons personService defaultPersonFilter pagination Nothing Nothing
        case result of
          Left appErr -> respondAppError appErr
          Right persons -> json $ object ["success" .= True, "data" .= persons]
       get
       "/api/v1/persons/:id"
      $ do
        pid <- captureParam "id"
        result <- liftIO $ runAppM env $ do
          personService <- getPersonService
          getPerson personService pid
        case result of
          Left appErr -> respondAppError appErr
          Right person -> json $ object ["success" .= True, "data" .= person]
       get
       "/api/v1/persons/search/:query"
      $ do
        query <- captureParam "query"
        result <- liftIO $ runAppM env $ do
          personService <- getPersonService
          searchPersons personService query
        case result of
          Left appErr -> respondAppError appErr
          Right persons -> json $ object ["success" .= True, "data" .= persons]

       -- Persons CRUD
       post
       "/api/v1/persons"
      $ do
        input <- jsonData :: ActionM PersonInput
        result <- liftIO $ runAppM env $ do
          personService <- getPersonService
          created <- createPerson personService input
          liftIO $ publishWebSocketEvent wsHub NTPersonChanged "person.created" (object ["id" .= pId created])
          pure created
        case result of
          Left appErr -> respondAppError appErr
          Right person -> json $ object ["success" .= True, "data" .= person]
       put
       "/api/v1/persons/:id"
      $ do
        pid <- captureParam "id"
        input <- jsonData :: ActionM PersonInput
        result <- liftIO $ runAppM env $ do
          personService <- getPersonService
          updated <- updatePerson personService pid input
          liftIO $ publishWebSocketEvent wsHub NTPersonChanged "person.updated" (object ["id" .= pId updated])
          pure updated
        case result of
          Left appErr -> respondAppError appErr
          Right person -> json $ object ["success" .= True, "data" .= person]
       delete
       "/api/v1/persons/:id"
      $ do
        pid <- captureParam "id"
        repoResult <- liftIO $ runExceptT $ deletePersonRepo personRepo pid
        case repoResult of
          Left repoErr -> respondRepositoryError repoErr
          Right () -> do
            liftIO $ publishWebSocketEvent wsHub NTPersonChanged "person.deleted" (object ["id" .= pid])
            json $ object ["success" .= True]

        -- Goods (with pagination)
        get
        "/api/v1/goods"
       $ do
         checkPermissions [PermRead EntityGoods]
         let pagination = Pagination 50 0
         result <- liftIO $ runAppM env $ do
           goodsService <- getGoodsService
           listGoods goodsService defaultGoodsFilter pagination Nothing Nothing
         case result of
           Left appErr -> respondAppError appErr
           Right goods -> json $ object ["success" .= True, "data" .= goods]

        -- Goods CRUD
        post
        "/api/v1/goods"
       $ do
         input <- jsonData :: ActionM GoodsInput
         result <- liftIO $ runAppM env $ do
           goodsService <- getGoodsService
           created <- createGoods service input
           liftIO $ publishWebSocketEvent wsHub NTGoodsChanged "goods.created" (object ["id" .= gId created])
           pure created
         case result of
           Left appErr -> respondAppError appErr
           Right goods -> json $ object ["success" .= True, "data" .= goods]
        put
        "/api/v1/goods/:id"
       $ do
         gid <- captureParam "id"
         input <- jsonData :: ActionM GoodsInput
         result <- liftIO $ runAppM env $ do
           goodsService <- getGoodsService
           updated <- updateGoods goodsService gid input
           liftIO $ publishWebSocketEvent wsHub NTGoodsChanged "goods.updated" (object ["id" .= gId updated])
           pure updated
         case result of
           Left appErr -> respondAppError appErr
           Right goods -> json $ object ["success" .= True, "data" .= goods]
        delete
        "/api/v1/goods/:id"
       $ do
         gid <- captureParam "id"
         result <- liftIO $ runAppM env $ do
           goodsService <- getGoodsService
           deleteGoods goodsService gid
           pure ()
         case result of
           Left appErr -> respondAppError appErr
           Right () -> do
             liftIO $ publishWebSocketEvent wsHub NTGoodsChanged "goods.deleted" (object ["id" .= gid])
             json $ object ["success" .= True]

        -- Locations
        get
        "/api/v1/locations"
       $ do
         result <- liftIO $ runAppM env $ do
           locationService <- getLocationService
           listLocations locationService defaultLocationFilter (Pagination 50 0) Nothing Nothing
         case result of
           Left appErr -> respondAppError appErr
           Right locations -> json $ object ["success" .= True, "data" .= locations]

        -- Locations CRUD
        post
        "/api/v1/locations"
       $ do
         input <- jsonData :: ActionM LocationInput
         result <- liftIO $ runAppM env $ do
           locationService <- getLocationService
           created <- createLocation locationService input
           pure created
         case result of
           Left appErr -> respondAppError appErr
           Right location -> json $ object ["success" .= True, "data" .= location]
        put
        "/api/v1/locations/:id"
       $ do
         lid <- captureParam "id"
         input <- jsonData :: ActionM LocationInput
         result <- liftIO $ runAppM env $ do
           locationService <- getLocationService
           updated <- updateLocation locationService lid input
           pure updated
         case result of
           Left appErr -> respondAppError appErr
           Right location -> json $ object ["success" .= True, "data" .= location]
       delete
       "/api/v1/locations/:id"
      $ do
        lid <- captureParam "id"
        repoResult <- liftIO $ runExceptT $ deleteLocationRepo locationRepo lid
        case repoResult of
          Left repoErr -> respondRepositoryError repoErr
          Right () -> json $ object ["success" .= True]

        -- Bills (with pagination)
        get
        "/api/v1/bills"
       $ do
         checkPermissions [PermRead EntityBills]
         let pagination = Pagination 50 0
         result <- liftIO $ runAppM env $ do
           billService <- getBillService
           listBills billService defaultBillFilter pagination Nothing Nothing
         case result of
           Left appErr -> respondAppError appErr
           Right bills -> json $ object ["success" .= True, "data" .= bills]

        -- Create Bill
        post
        "/api/v1/bills"
       $ do
         input <- jsonData :: ActionM BillInput
         result <- liftIO $ runAppM env $ do
           billService <- getBillService
           created <- createBill billService input
           liftIO $ publishWebSocketEvent wsHub NTBillChanged "bill.created" (object ["id" .= bId created])
           pure created
         case result of
           Left appErr -> respondAppError appErr
           Right bill -> json $ object ["success" .= True, "data" .= bill]

        -- Update Bill Status
        put
        "/api/v1/bills/:id/status"
       $ do
         bid <- captureParam "id"
         newStatus <- queryParam "status"
         result <- liftIO $ runAppM env $ do
           billService <- getBillService
           updated <- updateBillStatus billService bid newStatus
           liftIO $ publishWebSocketEvent wsHub NTBillChanged "bill.status_updated" (object ["id" .= bId updated, "status" .= newStatus])
           pure updated
         case result of
           Left appErr -> respondAppError appErr
           Right bill -> json $ object ["success" .= True, "id" .= bId bill]

        -- Delete Bill
        delete
        "/api/v1/bills/:id"
       $ do
         bid <- captureParam "id"
         result <- liftIO $ runAppM env $ do
           billService <- getBillService
           deleteBill billService bid
           pure ()
         case result of
           Left appErr -> respondAppError appErr
           Right () -> do
             liftIO $ publishWebSocketEvent wsHub NTBillChanged "bill.deleted" (object ["id" .= bid])
             json $ object ["success" .= True]

        -- Payments
        get
        "/api/v1/payments"
       $ do
         result <- liftIO $ runAppM env $ do
           paymentService <- getPaymentService
           listPayments paymentService (Pagination 50 0)
         case result of
           Left appErr -> respondAppError appErr
           Right payments -> json $ object ["success" .= True, "data" .= payments]
        get
        "/api/v1/payments/:id"
       $ do
         paymentId <- captureParam "id"
         result <- liftIO $ runAppM env $ do
           paymentService <- getPaymentService
           getPayment paymentService paymentId
         case result of
           Left appErr -> respondAppError appErr
           Right payment -> json $ object ["success" .= True, "data" .= payment]
        post
        "/api/v1/payments"
       $ do
         input <- jsonData :: ActionM PaymentInput
         result <- liftIO $ runAppM env $ do
           paymentService <- getPaymentService
           created <- createPayment paymentService input
           liftIO $ publishWebSocketEvent wsHub NTPaymentChanged "payment.created" (object ["id" .= pId created])
           pure created
         case result of
           Left appErr -> respondAppError appErr
           Right payment -> json $ object ["success" .= True, "data" .= payment]
        put
        "/api/v1/payments/:id"
       $ do
         paymentId <- captureParam "id"
         input <- jsonData :: ActionM PaymentInput
         result <- liftIO $ runAppM env $ do
           paymentService <- getPaymentService
           updated <- updatePayment paymentService paymentId input
           liftIO $ publishWebSocketEvent wsHub NTPaymentChanged "payment.updated" (object ["id" .= pId updated])
           pure updated
         case result of
           Left appErr -> respondAppError appErr
           Right payment -> json $ object ["success" .= True, "data" .= payment]
       delete
       "/api/v1/payments/:id"
      $ do
        paymentId <- captureParam "id"
        repoResult <- liftIO $ runExceptT $ deletePaymentRepo paymentRepo paymentId
        case repoResult of
          Left repoErr -> respondRepositoryError repoErr
          Right () -> do
            liftIO $ publishWebSocketEvent wsHub NTPaymentChanged "payment.deleted" (object ["id" .= paymentId])
            json $ object ["success" .= True]

        -- Get payments by status
        get
        "/api/v1/payments/status/:status"
       $ do
          statusVal <- captureParam "status"
          let status = read (T.unpack statusVal) :: Int16
          result <- liftIO $ getPaymentsByStatus (aePool env) status
          case result of
            Left appErr -> respondAppError appErr
            Right payments -> json $ object ["success" .= True, "data" .= payments]

        -- Get payments for a specific bill
        get
        "/api/v1/bills/:id/payments"
       $ do
          billId <- captureParam "id"
          result <- liftIO $ getPaymentsByBill (aePool env) billId
          case result of
            Left appErr -> respondAppError appErr
            Right payments -> json $ object ["success" .= True, "data" .= payments]

        -- Get total payments for a bill
        get
        "/api/v1/bills/:id/payments/total"
       $ do
          billId <- captureParam "id"
          result <- liftIO $ getPaymentTotalByBill (aePool env) billId
          case result of
            Left appErr -> respondAppError appErr
            Right total -> json $ object ["success" .= True, "data" .= total]

        -- Get unpaid bills (accounts receivable)
        get
        "/api/v1/bills/unpaid"
       $ do
          checkPermissions [PermRead EntityBills]
          result <- liftIO $ getUnpaidBills (aePool env)
          case result of
            Left appErr -> respondAppError appErr
            Right bills -> json $ object ["success" .= True, "data" .= bills]

        -- Orders (with pagination)
        get
        "/api/v1/orders"
       $ do
         checkPermissions [PermRead EntityOrders]
         let pagination = Pagination 50 0
         result <- liftIO $ runAppM env $ do
           orderService <- getOrderService
           listOrders orderService defaultOrderFilter pagination Nothing Nothing
         case result of
           Left appErr -> respondAppError appErr
           Right orders -> json $ object ["success" .= True, "data" .= orders]

        -- Create Order
        post
        "/api/v1/orders"
       $ do
         input <- jsonData :: ActionM OrderInput
         result <- liftIO $ runAppM env $ do
           orderService <- getOrderService
           created <- createOrder orderService input
           liftIO $ publishWebSocketEvent wsHub NTOrderChanged "order.created" (object ["id" .= oId created])
           pure created
         case result of
           Left appErr -> respondAppError appErr
           Right order -> json $ object ["success" .= True, "data" .= order]

       -- Update Order Status
       put
       "/api/v1/orders/:id/status"
      $ do
        oid <- captureParam "id"
        newStatus :: Int <- queryParam "status"
        repoResult <- liftIO $ runExceptT $ updateOrderStatusRepo orderRepo oid newStatus
        case repoResult of
          Left repoErr -> respondRepositoryError repoErr
          Right updatedId -> do
            liftIO $ publishWebSocketEvent wsHub NTOrderChanged "order.status_updated" (object ["id" .= updatedId, "status" .= newStatus])
            json $ object ["success" .= True, "id" .= updatedId]

       -- Delete Order
       delete
       "/api/v1/orders/:id"
      $ do
        oid <- captureParam "id"
        repoResult <- liftIO $ runExceptT $ deleteOrderRepo orderRepo oid
        case repoResult of
          Left repoErr -> respondRepositoryError repoErr
          Right () -> do
            liftIO $ publishWebSocketEvent wsHub NTOrderChanged "order.deleted" (object ["id" .= oid])
            json $ object ["success" .= True]

        -- Goods Prices
        get
        "/api/v1/goods/prices"
       $ do
         result <- liftIO $ runAppM env $ do
           priceService <- getPriceService
           listGoodsPrices priceService
         case result of
           Left appErr -> respondAppError appErr
           Right prices -> json $ object ["success" .= True, "data" .= prices]
        get
        "/api/v1/goods/:id/prices"
       $ do
         gid <- captureParam "id"
         result <- liftIO $ runAppM env $ do
           priceService <- getPriceService
            listPricesByGoods priceService gid
          case result of
            Left appErr -> respondAppError appErr
            Right prices -> json $ object ["success" .= True, "data" .= prices]

        -- Get effective price for goods on a specific date
        get
        "/api/v1/goods/:id/price"
       $ do
           gid <- captureParam "id"
           dateStr <- queryParamWithDef "date" "" :: ActionM Text
           effectiveDate <- if T.null dateStr 
                             then liftIO getCurrentTime >>= \t -> pure (utctDay t)
                             else pure (parseDate dateStr)
           result <- liftIO $ getGoodsPriceEffective (aePool env) gid effectiveDate
           case result of
             Left appErr -> respondAppError appErr
             Right price -> json $ object ["success" .= True, "data" .= price]

        -- Create Price
       post
       "/api/v1/goods/prices"
      $ do
        input <- jsonData :: ActionM PriceInput
        repoResult <- liftIO $ runExceptT $ createPriceRepo priceRepo input
        case repoResult of
          Left repoErr -> respondRepositoryError repoErr
          Right priceVal -> do
            liftIO $ publishWebSocketEvent wsHub NTGoodsChanged "goods.price_created" (object ["id" .= gpId priceVal, "goodsId" .= gpGoodsId priceVal])
            json $ object ["success" .= True, "data" .= priceVal]

        -- Units
        get
        "/api/v1/units"
       $ do
         result <- liftIO $ runAppM env $ do
           unitService <- getUnitService
           getUnits unitService
         case result of
           Left appErr -> respondAppError appErr
           Right units -> json $ object ["success" .= True, "data" .= units]

        -- Document Operation Kinds (Bill types)
        get
        "/api/v1/document-types"
       $ do
         result <- liftIO $ getDocumentOpKinds pool
         json $ toJSONResult result

        -- Tax
        get
        "/api/v1/taxes"
       $ do
         result <- liftIO $ runAppM env $ do
           taxService <- getTaxService
           listTaxes taxService
         case result of
           Left appErr -> respondAppError appErr
           Right taxes -> json $ object ["success" .= True, "data" .= taxes]
       get
       "/api/v1/taxes/:id"
      $ do
        tid <- captureParam "id"
        repoResult <- liftIO $ runExceptT $ find taxRepo tid
        case repoResult of
          Left repoErr -> respondRepositoryError repoErr
          Right Nothing -> respondRepositoryError (NotFound "Tax not found")
          Right (Just taxVal) -> json $ object ["success" .= True, "data" .= taxVal]

       -- Create Tax
       post
       "/api/v1/taxes"
      $ do
        input <- jsonData :: ActionM TaxInput
        repoResult <- liftIO $ runExceptT $ createTaxRepo taxRepo input
        case repoResult of
          Left repoErr -> respondRepositoryError repoErr
          Right taxVal -> do
            liftIO $ publishWebSocketEvent wsHub NTTaxChanged "tax.created" (object ["id" .= taxId taxVal])
            json $ object ["success" .= True, "data" .= taxVal]
       put
       "/api/v1/taxes/:id"
      $ do
        tid <- captureParam "id"
        input <- jsonData :: ActionM TaxInput
        repoResult <- liftIO $ runExceptT $ updateTaxRepo taxRepo tid input
        case repoResult of
          Left repoErr -> respondRepositoryError repoErr
          Right taxVal -> do
            liftIO $ publishWebSocketEvent wsHub NTTaxChanged "tax.updated" (object ["id" .= taxId taxVal])
            json $ object ["success" .= True, "data" .= taxVal]

       -- Delete Tax
       delete
       "/api/v1/taxes/:id"
      $ do
        tid <- captureParam "id"
        repoResult <- liftIO $ runExceptT $ deleteTaxRepo taxRepo tid
        case repoResult of
          Left repoErr -> respondRepositoryError repoErr
          Right () -> do
            liftIO $ publishWebSocketEvent wsHub NTTaxChanged "tax.deleted" (object ["id" .= tid])
            json $ object ["success" .= True]

       -- Currency
       get
       "/api/v1/currencies"
      $ do
        repoResult <- liftIO $ runExceptT $ listCurrenciesRepo currencyRepo
        case repoResult of
          Left repoErr -> respondRepositoryError repoErr
          Right currencies -> json $ object ["success" .= True, "data" .= currencies]
       get
       "/api/v1/currencies/:id"
      $ do
        cid <- captureParam "id"
        repoResult <- liftIO $ runExceptT $ find currencyRepo cid
        case repoResult of
          Left repoErr -> respondRepositoryError repoErr
          Right Nothing -> respondRepositoryError (NotFound "Currency not found")
          Right (Just currency) -> json $ object ["success" .= True, "data" .= currency]

       -- Create Currency
       post
       "/api/v1/currencies"
      $ do
        input <- jsonData :: ActionM CurrencyInput
        repoResult <- liftIO $ runExceptT $ createCurrencyRepo currencyRepo input
        case repoResult of
          Left repoErr -> respondRepositoryError repoErr
          Right currency -> do
            liftIO $ publishWebSocketEvent wsHub NTCurrencyChanged "currency.created" (object ["id" .= currId currency])
            json $ object ["success" .= True, "data" .= currency]
       put
       "/api/v1/currencies/:id"
      $ do
        cid <- captureParam "id"
        input <- jsonData :: ActionM CurrencyInput
        repoResult <- liftIO $ runExceptT $ updateCurrencyRepo currencyRepo cid input
        case repoResult of
          Left repoErr -> respondRepositoryError repoErr
          Right currency -> do
            liftIO $ publishWebSocketEvent wsHub NTCurrencyChanged "currency.updated" (object ["id" .= currId currency])
            json $ object ["success" .= True, "data" .= currency]

       -- Delete Currency
       delete
       "/api/v1/currencies/:id"
      $ do
        cid <- captureParam "id"
        repoResult <- liftIO $ runExceptT $ deleteCurrencyRepo currencyRepo cid
        case repoResult of
          Left repoErr -> respondRepositoryError repoErr
          Right () -> do
            liftIO $ publishWebSocketEvent wsHub NTCurrencyChanged "currency.deleted" (object ["id" .= cid])
            json $ object ["success" .= True]

       -- Inventory Documents
       get
       "/api/v1/inventory"
      $ do
        result <- liftIO $ getInventoryDocuments pool
        json $ toJSONResult result

       -- Stock
       get
       "/api/v1/stock"
      $ do
        lid <- queryParam "location_id"
        result <- liftIO $ getStockByLocation pool lid
        json $ toJSONResult result
       get
       "/api/v1/stock/:gid/locations/:lid"
      $ do
        gid <- captureParam "gid"
        lid <- captureParam "lid"
        result <- liftIO $ getStock pool gid lid
        json $ toJSONResult result
       get
        "/api/v1/stock/goods/:gid"
       $ do
         gid <- captureParam "gid"
         result <- liftIO $ runAppM env $ do
           inventoryService <- getInventoryService
           getStockByGoods inventoryService gid
         case result of
           Left appErr -> respondAppError appErr
           Right stock -> json $ object ["success" .= True, "data" .= stock]

        -- Stock summary (all stock)
        get
        "/api/v1/stock/summary"
       $ do
         result <- liftIO $ getStockAll pool
         json $ toJSONResult result

       -- Users
       get
       "/api/v1/users"
      $ do
        result <- liftIO $ getUsers pool
        json $ toJSONResult result

       -- Dashboard
       get
       "/api/v1/dashboard"
      $ do
        result <- liftIO $ getDashboardStats pool
        json $ toJSONResult result

       -- Sales Summary (last N days)
       get
       "/api/v1/sales/summary"
      $ do
        days <- queryParam "days"
        limit <- queryParam "limit"
        result <- liftIO $ getSalesSummary pool days limit
        json $ toJSONResult result

       -- Top Selling Goods
       get
       "/api/v1/goods/top"
      $ do
        limit <- queryParam "limit"
        result <- liftIO $ getTopSellingGoods pool limit
        json $ toJSONResult result

       -- Low Stock Goods
       get
       "/api/v1/goods/low-stock"
      $ do
        result <- liftIO $ getLowStockGoods pool
        json $ toJSONResult result

       -- Accounting
       get
       "/api/v1/accounting/accounts"
      $ do
        result <- liftIO $ runExceptT $ listAccPlansRepo accPlanRepo
        case result of
          Left repoErr -> respondRepositoryError repoErr
          Right plans -> json $ object ["success" .= True, "data" .= plans]
       get
       "/api/v1/accounting/accounts/:id"
      $ do
        pid <- captureParam "id"
        result <- liftIO $ runExceptT $ find accPlanRepo pid
        case result of
          Left repoErr -> respondRepositoryError repoErr
          Right Nothing -> respondRepositoryError (NotFound "Acc plan not found")
          Right (Just plan) -> json $ object ["success" .= True, "data" .= plan]

       -- Create AccPlan
       post
       "/api/v1/accounting/accounts"
      $ do
        input <- jsonData :: ActionM AccPlanInput
        repoResult <- liftIO $ runExceptT $ createAccPlanRepo accPlanRepo input
        case repoResult of
          Left repoErr -> respondRepositoryError repoErr
          Right accPlanVal -> do
            liftIO $ publishWebSocketEvent wsHub NTAccountingChanged "account_plan.created" (object ["id" .= apId accPlanVal])
            json $ object ["success" .= True, "data" .= accPlanVal]

       -- Update AccPlan
       put
       "/api/v1/accounting/accounts/:id"
      $ do
        pid <- captureParam "id"
        input <- jsonData :: ActionM AccPlanInput
        repoResult <- liftIO $ runExceptT $ updateAccPlanRepo accPlanRepo pid input
        case repoResult of
          Left repoErr -> respondRepositoryError repoErr
          Right accPlanVal -> do
            liftIO $ publishWebSocketEvent wsHub NTAccountingChanged "account_plan.updated" (object ["id" .= apId accPlanVal])
            json $ object ["success" .= True, "data" .= accPlanVal]

       -- Delete AccPlan
       delete
       "/api/v1/accounting/accounts/:id"
      $ do
        pid <- captureParam "id"
        repoResult <- liftIO $ runExceptT $ deleteAccPlanRepo accPlanRepo pid
        case repoResult of
          Left repoErr -> respondRepositoryError repoErr
          Right () -> do
            liftIO $ publishWebSocketEvent wsHub NTAccountingChanged "account_plan.deleted" (object ["id" .= pid])
            json $ object ["success" .= True]

       -- Accounting entries (turns)
       get
       "/api/v1/accounting/entries"
      $ do
        result <- liftIO $ getAccTurns pool
        json $ toJSONResult result

       -- Get AccTurn by ID
       get
       "/api/v1/accounting/entries/:id"
      $ do
        turnId <- captureParam "id"
        repoResult <- liftIO $ runExceptT $ find accTurnRepo turnId
        case repoResult of
          Left repoErr -> respondRepositoryError repoErr
          Right Nothing -> respondRepositoryError (NotFound "Accounting entry not found")
          Right (Just accTurnVal) -> json $ object ["success" .= True, "data" .= accTurnVal]

       -- Create AccTurn
       post
       "/api/v1/accounting/entries"
      $ do
        input <- jsonData :: ActionM AccTurnInput
        repoResult <- liftIO $ runExceptT $ createAccTurnRepo accTurnRepo input
        case repoResult of
          Left repoErr -> respondRepositoryError repoErr
          Right accTurnVal -> do
            liftIO $ publishWebSocketEvent wsHub NTAccountingChanged "account_entry.created" (object ["id" .= atId accTurnVal])
            json $ object ["success" .= True, "data" .= accTurnVal]

       -- Update AccTurn
       put
       "/api/v1/accounting/entries/:id"
      $ do
        turnId <- captureParam "id"
        input <- jsonData :: ActionM AccTurnInput
        repoResult <- liftIO $ runExceptT $ updateAccTurnRepo accTurnRepo turnId input
        case repoResult of
          Left repoErr -> respondRepositoryError repoErr
          Right accTurnVal -> do
            liftIO $ publishWebSocketEvent wsHub NTAccountingChanged "account_entry.updated" (object ["id" .= atId accTurnVal])
            json $ object ["success" .= True, "data" .= accTurnVal]

       -- Delete AccTurn
       delete
       "/api/v1/accounting/entries/:id"
      $ do
        turnId <- captureParam "id"
        repoResult <- liftIO $ runExceptT $ deleteAccTurnRepo accTurnRepo turnId
        case repoResult of
          Left repoErr -> respondRepositoryError repoErr
          Right () -> do
            liftIO $ publishWebSocketEvent wsHub NTAccountingChanged "account_entry.deleted" (object ["id" .= turnId])
            json $ object ["success" .= True]

       -- Payroll
       get
       "/api/v1/payroll"
      $ do
        result <- liftIO $ getEmployees pool
        json $ toJSONResult result
       get
       "/api/v1/payroll/employees"
      $ do
        result <- liftIO $ getEmployees pool
        json $ toJSONResult result
       get
       "/api/v1/payroll/employees/:id"
      $ do
        eid <- captureParam "id"
        result <- liftIO $ getEmployeeById pool eid
        json $ toJSONResult result
       get
       "/api/v1/payroll/salary/:eid"
      $ do
        eid <- captureParam "eid"
        result <- liftIO $ getSalaryByEmployee pool eid
        json $ toJSONResult result
       get
       "/api/v1/payroll/salaries"
      $ do
        result <- liftIO $ getSalaries pool
        json $ toJSONResult result

       -- Jobs (stub - no jobs table in DB)
       get
       "/api/v1/jobs"
        . json
      $ object
        ["items" .= ([] :: [Value])]
        get
        "/api/v1/jobs/pending"
        . json
      $ object
        ["count" .= (0 :: Int)]
        post
        "/api/v1/jobs"
        . json
      $ object
        ["jobId" .= (1 :: Int64)]
        -- Reports
        get
        "/api/v1/reports/metadata"
      $ do
        reportMeta <- liftIO Reports.getReportsMetadata
        json $ object ["success" .= True, "data" .= reportMeta]
       get
       "/api/v1/reports/jrxml/:name"
      $ do
        reportName <- captureParam "name"
        mjrxml <- liftIO $ Reports.generateReportJRXML reportName
        case mjrxml of
          Nothing -> respondRepositoryError (NotFound "Report template not found")
          Just jrxml -> json $ object ["success" .= True, "name" .= reportName, "jrxml" .= jrxml]
       get
       "/api/v1/reports"
      $ do
        result <- liftIO $ getReports pool
        json $ toJSONResult result
       get
       "/api/v1/reports/templates"
      $ do
        result <- liftIO $ getReports pool
        json $ toJSONResult result
       get
       "/api/v1/reports/:id"
      $ do
        rid <- captureParam "id"
        result <- liftIO $ getReportById pool rid
        json $ toJSONResult result
       post
       "/api/v1/reports"
        . json
      $ object ["reportId" .= (1 :: Int64)]

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
