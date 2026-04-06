{-# LANGUAGE FlexibleInstances #-}

-- | Application Configuration and Service Container
--
-- This module provides the core configuration infrastructure including:
--
-- * Service container for dependency injection
-- * Generic service creation using type classes
-- * Configuration loading from environment variables
-- * Rate limiting configuration
--
-- = Design
--
-- The service container uses a simple approach where services wrap a
-- connection pool. This can be extended for more complex dependency injection.
--
-- = Environment Variables
--
-- * @JWT_SECRET@ - JWT secret key (default: provided value)
-- * @RATE_LIMIT_REQUESTS@ - Rate limit requests count (default: 100)
-- * @RATE_LIMIT_SECONDS@ - Rate limit time window in seconds (default: 60)
-- * @ENABLE_WEBSOCKET@ - Enable WebSocket support (default: \"false\")
module Surypus.Config where

import Control.Concurrent.STM (TQueue)
import DAL.Repository.Container (RepositoryContainer)
import Data.IORef (IORef, newIORef)
import Data.Maybe (fromMaybe)
import Data.Text (Text, pack)
import Database.Persist.Sql
import Hasql.Pool (Pool)
import Surypus.Cache (Cache, createCache)
import Surypus.JWT (JWTConfig, jwtConfigFromSecret)
import Surypus.JobRunner (Job)
import System.Environment (lookupEnv)

-- | Service type aliases
--
-- These type aliases represent services in the application.
-- Currently they wrap a connection pool.
type AccountingService = Pool

type AuditService = Pool

type BillService = Pool

type GoodsService = Pool

type InventoryService = Pool

type LocationService = Pool

type OrderService = Pool

type PaymentService = Pool

type PayrollService = Pool

type PersonService = Pool

type PriceService = Pool

type ReportService = Pool

type TaxService = Pool

type UnitService = Pool

-- | Application configuration
data AppConfig = AppConfig
  { appConfigPool :: ConnectionPool,
    appConfigCache :: Cache,
    appConfigJWT :: JWTConfig,
    appConfigPort :: Int,
    appConfigJwtSecret :: Text,
    appConfigRateLimit :: RateLimitConfig,
    appConfigEnableWebSocket :: Bool
  }

-- | Rate limiting configuration
data RateLimitConfig = RateLimitConfig
  { rlcRequests :: Int,
    rlcSeconds :: Int,
    rlcStore :: IORef [(String, (Int, Int))],
    rlcCurrentTime :: Int
  }
  deriving (Eq)

-- | Application runtime environment
data AppEnv = AppEnv
  { aePool :: ConnectionPool,
    aeCache :: Cache,
    aeConfig :: AppConfig,
    aeServices :: ServiceContainer,
    aeRepositories :: RepositoryContainer,
    aeJobQueue :: TQueue Job,
    aeWebsocketHub :: Maybe WebSocketHub
  }

-- | Container for all application services
--
-- Contains all service instances for the application.
data ServiceContainer = ServiceContainer
  { scAccountingService :: AccountingService,
    scAuditService :: AuditService,
    scBillService :: BillService,
    scGoodsService :: GoodsService,
    scInventoryService :: InventoryService,
    scLocationService :: LocationService,
    scOrderService :: OrderService,
    scPriceService :: PriceService,
    scPaymentService :: PaymentService,
    scPayrollService :: PayrollService,
    scPersonService :: PersonService,
    scReportService :: ReportService,
    scTaxService :: TaxService,
    scUnitService :: UnitService
  }

-- | Create a service container from a connection pool
mkServiceContainer :: Pool -> ServiceContainer
mkServiceContainer pool =
  ServiceContainer
    { scAccountingService = pool,
      scAuditService = pool,
      scBillService = pool,
      scGoodsService = pool,
      scInventoryService = pool,
      scLocationService = pool,
      scOrderService = pool,
      scPriceService = pool,
      scPaymentService = pool,
      scPayrollService = pool,
      scPersonService = pool,
      scReportService = pool,
      scTaxService = pool,
      scUnitService = pool
    }

-- | Load application configuration from environment and defaults
loadAppConfig :: ConnectionPool -> Int -> Text -> IO AppConfig
loadAppConfig pool port jwtSecret = do
  cache <- createCache
  jwtSecret' <- maybe jwtSecret pack <$> lookupEnv "JWT_SECRET"
  rateLimitReqStr <- fromMaybe "" <$> lookupEnv "RATE_LIMIT_REQUESTS"
  rateLimitSecStr <- fromMaybe "" <$> lookupEnv "RATE_LIMIT_SECONDS"
  let rateLimitReq = if null rateLimitReqStr then 100 else read rateLimitReqStr
      rateLimitSec = if null rateLimitSecStr then 60 else read rateLimitSecStr
  rateLimitStore <- newIORef []
  let rateLimitConfig = RateLimitConfig rateLimitReq rateLimitSec rateLimitStore 0
  enableWS <- (== "true") . fromMaybe "false" <$> lookupEnv "ENABLE_WEBSOCKET"
  pure
    AppConfig
      { appConfigPool = pool,
        appConfigCache = cache,
        appConfigJWT = jwtConfigFromSecret jwtSecret',
        appConfigPort = port,
        appConfigJwtSecret = jwtSecret',
        appConfigRateLimit = rateLimitConfig,
        appConfigEnableWebSocket = enableWS
      }

-- | Placeholder for WebSocket hub
type WebSocketHub = ()
