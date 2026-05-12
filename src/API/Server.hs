{-# LANGUAGE OverloadedStrings #-}

-- | API Server - STUBBED
module API.Server
  ( -- app,
    -- server,
    -- PersonAPI,
    -- PersonsAPI,
    -- AuthAPI,
    -- HealthAPI,
    -- APIv1,
    -- API
  ) where

import API.Types
import Control.Monad.IO.Class (liftIO)
import Control.Monad.Trans.Except (ExceptT, throwE)
-- import DAL.Repository
-- import DAL.Repository.Person (HasPersonRepository (..), PersonRepository, mkPersonRepository)
-- import DAL.Types
-- import Data.Pagination (Pagination (..))
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import Data.Time (getCurrentTime, UTCTime)
import GHC.Generics (Generic)
-- import Hasql.Pool (Pool)
import Network.Wai (Request, requestMethod, rawPathInfo, requestHeaders, getRequestBodyChunk, Middleware, Application, responseLBS)
-- import Network.Wai.Middleware.RequestLogger (logStdout, logStdoutDev)
import Network.HTTP.Types.Status (status503)
import Servant
import System.CircuitBreakerBulkheadFullWithMetrics (CircuitBreakerBulkheadFullWithMetrics, initCircuitBreakerBulkheadFullWithMetrics, executeWithFullMetrics)
-- import System.Metrics (Metrics, registerCounter, registerTimer, getCounter, getTimer)
import System.Log.FastLogger (LoggerSet, newStdoutLoggerSet, defaultBufSize, pushLogStr)
-- import Surypus.Error (AppError (..))
-- import Surypus.JWT
-- import Surypus.Validation (ValidationError (..), validatePersonInput)

-- All handlers stubbed
type AppM = IO ()

-- Stub types
type Pool = ()
type PersonRepository = ()
type Metrics = ()
type JWTConfig = ()
type ValidationError = String
type AppError = String

-- All handlers stubbed - commented out
-- type AppM = ExceptT ServantErr IO
-- data Env = Env
-- personRepoFromPool :: Pool -> PersonRepository
-- loggingMiddleware :: LoggerSet -> Middleware
-- metricsMiddleware :: Metrics -> Middleware
-- circuitBreakerMiddleware :: CircuitBreakerBulkheadFullWithMetrics -> Middleware
-- initEnv :: Pool -> JWTConfig -> IO Env
-- listPersonsHandler :: Env -> AppM (PageResponse PersonResponse)
-- createPersonHandler :: Env -> PersonInput -> AppM PersonResponse
-- getPersonHandler :: Env -> Int -> AppM PersonResponse
-- updatePersonHandler :: Env -> Int -> PersonInput -> AppM PersonResponse
-- deletePersonHandler :: Env -> Int -> AppM ()
-- searchPersonsHandler :: Env -> Maybe Text -> AppM (PageResponse PersonResponse)
-- loginHandler :: Env -> LoginRequest -> AppM LoginResponse
-- refreshHandler :: Env -> RefreshRequest -> AppM RefreshResponse
-- logoutHandler :: Env -> Maybe Text -> AppM ()
-- healthHandler :: Env -> AppM Text
-- healthDbHandler :: Env -> AppM Text
-- err400 :: Text -> ServantErr
-- err401 :: Text -> ServantErr
-- err404 :: Text -> ServantErr
-- err409 :: Text -> ServantErr
-- err500 :: Text -> ServantErr
-- err503 :: Text -> ServantErr
-- healthCheckDB :: Pool -> IO Bool
-- personToResponse :: Person -> PersonResponse
-- defaultPersonFilter :: PersonFilter
-- server :: Env -> Server API
-- app :: Application

-- Rest of the server code stubbed
-- authServer =
--   loginHandler env
--     :<|> refreshHandler env
--     :<|> logoutHandler env
-- healthServer =
--   healthHandler env
--     :<|> healthDbHandler env
-- apiServer = authServer :<|> personsServer :<|> healthServer
-- swaggerHandler = pure "Swagger JSON placeholder"
-- in apiServer :<|> swaggerHandler

-- app :: Pool -> JWTConfig -> IO Application
-- app pool jwtConfig = do
--   env <- initEnv pool jwtConfig
--   let baseApp = serve (Proxy @API) (server env)
--       loggedApp = loggingMiddleware (envLogger env) baseApp
--       metricsApp = metricsMiddleware (envMetrics env) loggedApp
--       protectedApp = circuitBreakerMiddleware (envCircuitBreaker env) metricsApp
--   return protectedApp
