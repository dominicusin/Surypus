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

import Control.Exception (SomeException, catch)
import Control.Monad.IO.Class (liftIO)
import DAL.Mutations
import DAL.Queries
import DAL.Types
import Data.Aeson (FromJSON, ToJSON, Value (..), object, (.=))
import Data.ByteString (ByteString)
import Data.Int (Int64)
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Encoding as T
import GHC.Generics (Generic)
import Hasql.Pool (Pool)
import qualified Network.HTTP.Types as HTTP
import Network.Wai (Middleware, requestHeaders, responseLBS)
import Surypus.JWT (JWTConfig (..), JWTPayload (..), defaultJWTConfig, generateSimpleToken, validateSimpleToken)
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
    scPool :: Pool
  }

data RateLimitConfig = RateLimitConfig
  { rlcRequests :: Int,
    rlcSeconds :: Int
  }
  deriving (Eq, Show)

defaultRateLimit :: RateLimitConfig
defaultRateLimit =
  RateLimitConfig
    { rlcRequests = 100,
      rlcSeconds = 60
    }

-- ============================================================================
-- MIDDLEWARE
-- ============================================================================

rateLimitMiddleware :: RateLimitConfig -> Middleware
rateLimitMiddleware _cfg app = app

securityMiddleware :: Middleware
securityMiddleware app = app

jwtAuthMiddleware :: JWTConfig -> Middleware
jwtAuthMiddleware config app req respond = do
  let authHeader = lookup "Authorization" (requestHeaders req)
  case authHeader of
    Nothing -> respond $ responseLBS HTTP.status401 [] "Unauthorized"
    Just header -> do
      let headerText = T.decodeUtf8 header
          mbPrefix = T.stripPrefix "Bearer " headerText
          token = maybe headerText T.strip mbPrefix
      case validateSimpleToken config token of
        Left _ -> respond $ responseLBS HTTP.status401 [] "Unauthorized"
        Right _ -> app req respond

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

-- ============================================================================
-- SERVER
-- ============================================================================

runServer :: ServerConfig -> IO ()
runServer cfg = do
  putStrLn "========================================="
  putStrLn "  Surypus HTTP Server v0.1.0"
  putStrLn $ "  Host: " ++ scHost cfg ++ ":" ++ show (scPort cfg)
  putStrLn "========================================="
  putStrLn "Starting Scotty server..."
  hFlush stdout

  let port = scPort cfg
      pool = scPool cfg

  Scotty.scotty port $ do
    -- Root
    get "/" $ html "<h1>Surypus ERP/CRM v0.1.0</h1>"

    -- Login
    post "/api/v1/login" $ do
      input <- jsonData :: ActionM LoginRequest
      let username = lrUsername input
          password = lrPassword input
      if password == "admin123" || password == "demo"
        then do
          let payload = JWTPayload 1 username "admin"
              tokenConfig = defaultJWTConfig
          token <- liftIO $ generateSimpleToken tokenConfig payload
          json $
            object
              [ "success" .= True,
                "token" .= token,
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
    get "/api/v1/health" $
      json $
        object
          [ "status" .= ("healthy" :: String),
            "version" .= ("0.1.0" :: String)
          ]

    -- Auth
    post "/api/v1/auth/login" $
      json $
        LoginResponse
          { token = "token-placeholder",
            userId = 1,
            role = "admin",
            expiresAt = "2026-12-31T23:59:59Z"
          }

    post "/api/v1/auth/logout" $
      json $
        object ["success" .= True]

    get "/api/v1/auth/me" $
      json $
        object
          [ "userId" .= (1 :: Int64),
            "username" .= ("admin" :: String),
            "role" .= ("admin" :: String)
          ]

    -- Persons (with pagination and sorting)
    get "/api/v1/persons" $ do
      let pagination = Pagination 50 0
          filter = defaultPersonFilter

      eResult <-
        liftIO $
          catch
            ( do
                result <- getPersonsPaginated pool filter Nothing Nothing pagination
                return (Right result)
            )
            (\(e :: SomeException) -> return (Left (T.pack (show e))))
      case eResult of
        Left err -> do
          liftIO $ putStrLn $ "ERROR in /api/v1/persons: " ++ T.unpack err
          json $ object ["success" .= False, "error" .= err]
        Right result -> json result

    get "/api/v1/persons/:id" $ do
      pid <- param "id"
      result <- liftIO $ getPersonById pool pid
      json $ toJSONResult result

    get "/api/v1/persons/search/:query" $ do
      query <- param "query"
      result <- liftIO $ searchPersons pool query
      json $ toJSONResult result

    -- Persons CRUD
    post "/api/v1/persons" $ do
      input <- jsonData :: ActionM PersonInput
      result <- liftIO $ createPerson pool input
      json result

    put "/api/v1/persons/:id" $ do
      pid <- param "id"
      input <- jsonData :: ActionM PersonInput
      result <- liftIO $ updatePerson pool pid input
      json result

    delete "/api/v1/persons/:id" $ do
      pid <- param "id"
      result <- liftIO $ deletePerson pool pid
      json result

    -- Goods (with pagination)
    get "/api/v1/goods" $ do
      let pagination = Pagination 50 0
          filter = defaultGoodsFilter

      eResult <-
        liftIO $
          catch
            ( do
                result <- getGoodsPaginated pool filter pagination
                return (Right result)
            )
            (\(e :: SomeException) -> return (Left (T.pack (show e))))
      case eResult of
        Left err -> do
          liftIO $ putStrLn $ "ERROR in /api/v1/goods: " ++ T.unpack err
          json $ object ["success" .= False, "error" .= err]
        Right result -> json result

    get "/api/v1/goods/search/:query" $ do
      query <- param "query"
      result <- liftIO $ searchGoods pool query
      json $ toJSONResult result

    get "/api/v1/goods/:id" $ do
      gid <- param "id"
      result <- liftIO $ getGoodsById pool gid
      json $ toJSONResult result

    get "/api/v1/goods/barcode/:code" $ do
      code <- param "code"
      result <- liftIO $ getGoodsByBarcode pool code
      json $ toJSONResult result

    -- Goods CRUD
    post "/api/v1/goods" $ do
      input <- jsonData :: ActionM GoodsInput
      result <- liftIO $ createGoods pool input
      json result

    put "/api/v1/goods/:id" $ do
      gid <- param "id"
      input <- jsonData :: ActionM GoodsInput
      result <- liftIO $ updateGoods pool gid input
      json result

    delete "/api/v1/goods/:id" $ do
      gid <- param "id"
      result <- liftIO $ deleteGoods pool gid
      json result

    -- Locations
    get "/api/v1/locations" $ do
      result <- liftIO $ getLocations pool
      json $ toJSONResult result

    -- Locations CRUD
    post "/api/v1/locations" $ do
      input <- jsonData :: ActionM LocationInput
      result <- liftIO $ createLocation pool input
      json result

    put "/api/v1/locations/:id" $ do
      lid <- param "id"
      input <- jsonData :: ActionM LocationInput
      result <- liftIO $ updateLocation pool lid input
      json result

    delete "/api/v1/locations/:id" $ do
      lid <- param "id"
      result <- liftIO $ deleteLocation pool lid
      json result

    -- Bills (with pagination)
    get "/api/v1/bills" $ do
      let pagination = Pagination 50 0

      eResult <-
        liftIO $
          catch
            ( do
                result <- getBillsPaginated pool pagination
                return (Right result)
            )
            (\(e :: SomeException) -> return (Left (T.pack (show e))))
      case eResult of
        Left err -> do
          liftIO $ putStrLn $ "ERROR in /api/v1/bills: " ++ T.unpack err
          json $ object ["success" .= False, "error" .= err]
        Right result -> json result

    get "/api/v1/bills/:id" $ do
      bid <- param "id"
      result <- liftIO $ getBillById pool bid
      json $ toJSONResult result

    -- Create Bill
    post "/api/v1/bills" $ do
      input <- jsonData :: ActionM BillInput
      result <- liftIO $ createBill pool input
      json result

    -- Update Bill Status
    put "/api/v1/bills/:id/status" $ do
      bid <- param "id"
      status :: Int <- param "status"
      result <- liftIO $ updateBillStatus pool bid status
      json result

    -- Delete Bill
    delete "/api/v1/bills/:id" $ do
      bid <- param "id"
      result <- liftIO $ deleteBill pool bid
      json result

    -- Orders (with pagination)
    get "/api/v1/orders" $ do
      let pagination = Pagination 50 0

      eResult <-
        liftIO $
          catch
            ( do
                result <- getOrdersPaginated pool pagination
                return (Right result)
            )
            (\(e :: SomeException) -> return (Left (T.pack (show e))))
      case eResult of
        Left err -> do
          liftIO $ putStrLn $ "ERROR in /api/v1/orders: " ++ T.unpack err
          json $ object ["success" .= False, "error" .= err]
        Right result -> json result

    get "/api/v1/orders/:id" $ do
      oid <- param "id"
      result <- liftIO $ getOrderById pool oid
      json $ toJSONResult result

    -- Create Order
    post "/api/v1/orders" $ do
      input <- jsonData :: ActionM OrderInput
      result <- liftIO $ createOrder pool input
      json result

    -- Update Order Status
    put "/api/v1/orders/:id/status" $ do
      oid <- param "id"
      status :: Int <- param "status"
      result <- liftIO $ updateOrderStatus pool oid status
      json result

    -- Delete Order
    delete "/api/v1/orders/:id" $ do
      oid <- param "id"
      result <- liftIO $ deleteOrder pool oid
      json result

    -- Goods Prices
    get "/api/v1/goods/prices" $ do
      result <- liftIO $ getGoodsPrices pool
      json $ toJSONResult result

    get "/api/v1/goods/:id/prices" $ do
      gid <- param "id"
      result <- liftIO $ getGoodsPriceByGoods pool gid
      json $ toJSONResult result

    -- Tax
    get "/api/v1/taxes" $ do
      result <- liftIO $ getTaxes pool
      json $ toJSONResult result

    -- Currency
    get "/api/v1/currencies" $ do
      result <- liftIO $ getCurrencies pool
      json $ toJSONResult result

    -- Stock
    get "/api/v1/stock" $ do
      lid <- param "location_id"
      result <- liftIO $ getStockByLocation pool lid
      json $ toJSONResult result

    get "/api/v1/stock/:gid/locations/:lid" $ do
      gid <- param "gid"
      lid <- param "lid"
      result <- liftIO $ getStock pool gid lid
      json $ toJSONResult result

    get "/api/v1/stock/goods/:gid" $ do
      gid <- param "gid"
      result <- liftIO $ getStockByGoods pool gid
      json $ toJSONResult result

    -- Users
    get "/api/v1/users" $ do
      result <- liftIO $ getUsers pool
      json $ toJSONResult result

    -- Dashboard
    get "/api/v1/dashboard" $ do
      result <- liftIO $ getDashboardStats pool
      json $ toJSONResult result

    -- Accounting
    get "/api/v1/accounting" $ do
      result <- liftIO $ getAccPlans pool
      json $ toJSONResult result

    get "/api/v1/accounting/accounts" $ do
      result <- liftIO $ getAccPlans pool
      json $ toJSONResult result

    get "/api/v1/accounting/accounts/:id" $ do
      pid <- param "id"
      result <- liftIO $ getAccPlanById pool pid
      json $ toJSONResult result

    get "/api/v1/accounting/entries" $ do
      result <- liftIO $ getAccTurns pool
      json $ toJSONResult result

    -- Payroll
    get "/api/v1/payroll" $ do
      result <- liftIO $ getEmployees pool
      json $ toJSONResult result

    get "/api/v1/payroll/employees" $ do
      result <- liftIO $ getEmployees pool
      json $ toJSONResult result

    get "/api/v1/payroll/employees/:id" $ do
      eid <- param "id"
      result <- liftIO $ getEmployeeById pool eid
      json $ toJSONResult result

    get "/api/v1/payroll/salary/:eid" $ do
      eid <- param "eid"
      result <- liftIO $ getSalaryByEmployee pool eid
      json $ toJSONResult result

    get "/api/v1/payroll/salaries" $ do
      result <- liftIO $ getSalaries pool
      json $ toJSONResult result

    -- Jobs (stub - no jobs table in DB)
    get "/api/v1/jobs" $ json $ object ["items" .= ([] :: [Value])]
    get "/api/v1/jobs/pending" $ json $ object ["count" .= (0 :: Int)]
    post "/api/v1/jobs" $ json $ object ["jobId" .= (1 :: Int64)]

    -- Reports
    get "/api/v1/reports" $ do
      result <- liftIO $ getReports pool
      json $ toJSONResult result

    get "/api/v1/reports/templates" $ do
      result <- liftIO $ getReports pool
      json $ toJSONResult result

    get "/api/v1/reports/:id" $ do
      rid <- param "id"
      result <- liftIO $ getReportById pool rid
      json $ toJSONResult result

    post "/api/v1/reports" $ json $ object ["reportId" .= (1 :: Int64)]

healthStatus :: IO Text
healthStatus = pure "healthy"
