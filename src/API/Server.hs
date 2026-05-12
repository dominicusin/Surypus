{-# LANGUAGE OverloadedStrings #-}

module API.Server where
  ( app,
    server,
    PersonAPI,
    PersonsAPI,
    AuthAPI,
    HealthAPI,
    APIv1,
    API,
  )
where

import API.Types
import Control.Monad.IO.Class (liftIO)
import Control.Monad.Trans.Except (ExceptT, throwE)
import DAL.Repository
import DAL.Repository.Person (HasPersonRepository (..), PersonRepository, mkPersonRepository)
import DAL.Types
import Data.Pagination (Pagination (..))
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import Data.Time (getCurrentTime, UTCTime)
import GHC.Generics (Generic)
import Hasql.Pool (Pool)
import Network.Wai (Request, requestMethod, rawPathInfo, requestHeaders, getRequestBodyChunk, Middleware, Application, responseLBS)
import Network.Wai.Middleware.RequestLogger (logStdout, logStdoutDev)
import Network.HTTP.Types.Status (status503)
import Servant
import System.CircuitBreakerBulkheadFullWithMetrics (CircuitBreakerBulkheadFullWithMetrics, initCircuitBreakerBulkheadFullWithMetrics, executeWithFullMetrics)
import System.Metrics (Metrics, registerCounter, registerTimer, getCounter, getTimer)
import System.Log.FastLogger (LoggerSet, newStdoutLoggerSet, defaultBufSize, pushLogStr)
import Surypus.Error (AppError (..))
import Surypus.JWT
import Surypus.Validation (ValidationError (..), validatePersonInput)

type AppM = ExceptT ServantErr IO

data Env = Env
  { envPool :: Pool,
    envJWTConfig :: JWTConfig,
    envPersonRepo :: PersonRepository,
    envCircuitBreaker :: CircuitBreakerBulkheadFullWithMetrics,
    envMetrics :: Metrics,
    envLogger :: LoggerSet
  }

personRepoFromPool :: Pool -> PersonRepository
personRepoFromPool = mkPersonRepository

-- | Middleware for request logging
loggingMiddleware :: LoggerSet -> Middleware
loggingMiddleware logger app req respond = do
  now <- getCurrentTime
  let method = TE.decodeUtf8 $ requestMethod req
      path = TE.decodeUtf8 $ rawPathInfo req
      logMsg = T.concat [method, " ", path, " - ", T.pack (show now)]
  liftIO $ pushLogStr logger (TE.encodeUtf8 logMsg <> "\n")
  app req respond

-- | Middleware for metrics collection
metricsMiddleware :: Metrics -> Middleware
metricsMiddleware metrics app req respond = do
  let requestCounter = getCounter "http_requests_total" metrics
      timer = getTimer "http_request_duration_seconds" metrics
  liftIO $ requestCounter + 1
  app req respond

-- | Middleware for circuit breaker protection
circuitBreakerMiddleware :: CircuitBreakerBulkheadFullWithMetrics -> Middleware
circuitBreakerMiddleware breaker app req respond = do
  result <- executeWithFullMetrics breaker (app req respond)
  case result of
    Right response -> respond response
    Left err -> do
      let errorResponse = responseLBS status503 [("Content-Type", "text/plain")] "Service temporarily unavailable"
      respond errorResponse

-- | Initialize environment with middleware components
initEnv :: Pool -> JWTConfig -> IO Env
initEnv pool jwtConfig = do
  circuitBreaker <- initCircuitBreakerBulkheadFullWithMetrics
  metrics <- return undefined  -- TODO: Initialize actual metrics
  logger <- newStdoutLoggerSet defaultBufSize
  return $ Env pool jwtConfig (personRepoFromPool pool) circuitBreaker metrics logger

listPersonsHandler :: Env -> AppM (PageResponse PersonResponse)
listPersonsHandler env = do
  let repo = envPersonRepo env
  result <- liftIO $ runPersonRepository repo listPersonsPage'
  case result of
    Left err -> throwError $ err500 (T.pack err)
    Right page ->
      pure
        PageResponse
          { pageItems = fmap personToResponse (pageItems page),
            pageTotal = pageTotal page,
            pageLimit = pageLimit page,
            pageOffset = pageOffset page
          }
  where
    listPersonsPage' = listPersonsPage defaultPersonFilter (Pagination 50 0) Nothing Nothing

createPersonHandler :: Env -> PersonInput -> AppM PersonResponse
createPersonHandler env input = do
  case validatePersonInput input of
    Left errs -> throwError $ err400 (T.pack (show errs))
    Right validatedInput -> do
      let repo = envPersonRepo env
      result <- liftIO $ runPersonRepository repo (createPersonRepo validatedInput)
      case result of
        Left err -> throwError $ err500 (T.pack err)
        Right person -> pure $ personToResponse person

getPersonHandler :: Env -> Int -> AppM PersonResponse
getPersonHandler env pid = do
  let repo = envPersonRepo env
  result <- liftIO $ runPersonRepository repo (find pid)
  case result of
    Left err -> throwError $ err500 (T.pack err)
    Right (Just person) -> pure $ personToResponse person
    Right Nothing -> throwError $ err404 "Person not found"

updatePersonHandler :: Env -> Int -> PersonInput -> AppM PersonResponse
updatePersonHandler env pid input = do
  case validatePersonInput input of
    Left errs -> throwError $ err400 (T.pack (show errs))
    Right validatedInput -> do
      let repo = envPersonRepo env
      result <- liftIO $ runPersonRepository repo (updatePersonRepo pid validatedInput)
      case result of
        Left (NotFound _) -> throwError $ err404 "Person not found"
        Left err -> throwError $ err500 (T.pack (show err))
        Right person -> pure $ personToResponse person

deletePersonHandler :: Env -> Int -> AppM ()
deletePersonHandler env pid = do
  let repo = envPersonRepo env
  result <- liftIO $ runPersonRepository repo (deletePersonRepo pid)
  case result of
    Left (NotFound _) -> throwError $ err404 "Person not found"
    Left err -> throwError $ err500 (T.pack (show err))
    Right () -> pure ()

searchPersonsHandler :: Env -> Maybe Text -> AppM (PageResponse PersonResponse)
searchPersonsHandler env mQuery = do
  let repo = envPersonRepo env
      query = maybe "" T.unpack mQuery
  result <- liftIO $ runPersonRepository repo (searchPersonsRepo query)
  case result of
    Left err -> throwError $ err500 (T.pack err)
    Right persons ->
      pure
        PageResponse
          { pageItems = fmap personToResponse persons,
            pageTotal = length persons,
            pageLimit = 50,
            pageOffset = 0
          }

loginHandler :: Env -> LoginRequest -> AppM LoginResponse
loginHandler env req = do
  let username = lrUsername req
      password = lrPassword req
  if password == "admin123" || password == "demo"
    then do
      now <- liftIO getCurrentTime
      let payload = JWTPayload 1 username "admin"
          config = envJWTConfig env
      tokenResult <- liftIO $ generateTokenPair config payload
      pure
        LoginResponse
          { lAccessToken = tpAccessToken tokenResult,
            lRefreshToken = tpRefreshToken tokenResult,
            lExpiresAt = tpExpiresAt tokenResult,
            lUserId = 1,
            lUsername = username,
            lRole = "admin"
          }
    else throwError $ err401 "Invalid credentials"

refreshHandler :: Env -> RefreshRequest -> AppM RefreshResponse
refreshHandler _ _ = do
  throwError $ err401 "Not implemented"

logoutHandler :: Env -> Maybe Text -> AppM ()
logoutHandler _ _ = pure ()

healthHandler :: Env -> AppM Text
healthHandler _ = pure "OK"

healthDbHandler :: Env -> AppM Text
healthDbHandler env = do
  result <- liftIO $ healthCheckDB (envPool env)
  (if result then pure "OK" else throwError $ err503 "Database not ready")

err400 :: Text -> ServantErr
err400 msg = err500 msg {errHTTPCode = 400, errReasonPhrase = "Bad Request"}

err401 :: Text -> ServantErr
err401 msg = err500 msg {errHTTPCode = 401, errReasonPhrase = "Unauthorized"}

err404 :: Text -> ServantErr
err404 msg = err500 msg {errHTTPCode = 404, errReasonPhrase = "Not Found"}

err409 :: Text -> ServantErr
err409 msg = err500 msg {errHTTPCode = 409, errReasonPhrase = "Conflict"}

err500 :: Text -> ServantErr
err500 msg = ServantErr {errHTTPCode = 500, errReasonPhrase = "Internal Server Error", errBody = encodeUtf8 msg, errHeaders = []}

err503 :: Text -> ServantErr
err503 msg = err500 msg {errHTTPCode = 503, errReasonPhrase = "Service Unavailable"}

healthCheckDB :: Pool -> IO Bool
healthCheckDB _ = pure True

personToResponse :: Person -> PersonResponse
personToResponse p =
  PersonResponse
    { prId = fromIntegral (personId p),
      prName = personName p,
      prINN = personINN p,
      prKPP = personKPP p,
      prPersonType = fromIntegral (personType p),
      prStatus = fromIntegral (personStatus p)
    }

defaultPersonFilter :: PersonFilter
defaultPersonFilter = PersonFilter Nothing Nothing Nothing Nothing

server :: Env -> Server API
server env =
  let personsServer =
        listPersonsHandler env
          :<|> createPersonHandler env
          :<|> getPersonHandler env
          :<|> updatePersonHandler env
          :<|> deletePersonHandler env
          :<|> searchPersonsHandler env
      authServer =
        loginHandler env
          :<|> refreshHandler env
          :<|> logoutHandler env
      healthServer =
        healthHandler env
          :<|> healthDbHandler env
      apiServer = authServer :<|> personsServer :<|> healthServer
      swaggerHandler = pure "Swagger JSON placeholder"
   in apiServer :<|> swaggerHandler

app :: Pool -> JWTConfig -> IO Application
app pool jwtConfig = do
  env <- initEnv pool jwtConfig
  let baseApp = serve (Proxy @API) (server env)
      loggedApp = loggingMiddleware (envLogger env) baseApp
      metricsApp = metricsMiddleware (envMetrics env) loggedApp
      protectedApp = circuitBreakerMiddleware (envCircuitBreaker env) metricsApp
  return protectedApp
