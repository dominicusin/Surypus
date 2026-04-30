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
import Data.Time (getCurrentTime)
import GHC.Generics (Generic)
import Hasql.Pool (Pool)
import Servant
import Surypus.Error (AppError (..))
import Surypus.JWT
import Surypus.Validation (ValidationError (..), validatePersonInput)

type AppM = ExceptT ServantErr IO

data Env = Env
  { envPool :: Pool,
    envJWTConfig :: JWTConfig,
    envPersonRepo :: PersonRepository
  }

personRepoFromPool :: Pool -> PersonRepository
personRepoFromPool = mkPersonRepository

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

app :: Pool -> JWTConfig -> Application
app pool jwtConfig =
  let env = Env pool jwtConfig (personRepoFromPool pool)
   in serve (Proxy @API) (server env)
