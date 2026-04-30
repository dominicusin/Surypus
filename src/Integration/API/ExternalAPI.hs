module Integration.API.ExternalAPI where

import Control.Exception (SomeException, try)
import Data.Aeson (Value, decode, encode)
import qualified Data.ByteString.Lazy as LBS
import Data.Text (Text)
import qualified Data.Text as T
-- import Network.HTTP.Client (HttpException, defaultManagerSettings, newManager, parseRequest)
-- import Network.HTTP.Client.TLS (tlsManagerSettings)
-- import Network.HTTP.Simple

-- | API client configuration
data APIClient = APIClient
  { manager :: Manager,
    baseUrl :: String,
    apiKey :: Maybe Text
  }

-- | Initialize API client
initAPIClient :: String -> Maybe Text -> IO APIClient
initAPIClient url key = do
  mgr <- newManager tlsManagerSettings
  return $ APIClient mgr url key

-- | Make GET request
apiGet :: APIClient -> String -> IO (Either String LBS.ByteString)
apiGet client endpoint = do
  let url = baseUrl client ++ endpoint
  req <- parseRequest url
  let req' = setRequestMethod "GET" req
  response <- try (httpLbs req' (manager client)) :: IO (Either HttpException (Response LBS.ByteString))
  case response of
    Left err -> return $ Left $ show err
    Right res -> return $ Right $ getResponseBody res

-- | Make POST request with JSON
apiPost :: APIClient -> String -> LBS.ByteString -> IO (Either String LBS.ByteString)
apiPost client endpoint body = do
  let url = baseUrl client ++ endpoint
  req <- parseRequest url
  let req' =
        setRequestMethod "POST" $
          setRequestBodyLBS body $
            setRequestHeader "Content-Type" ["application/json"] $
              req
  response <- try (httpLbs req' (manager client)) :: IO (Either HttpException (Response LBS.ByteString))
  case response of
    Left err -> return $ Left $ show err
    Right res -> return $ Right $ getResponseBody res

-- | Handle API errors
handleAPIError :: Either HttpException a -> Either String a
handleAPIError (Left err) = Left $ "HTTP error: " ++ show err
handleAPIError (Right val) = Right val

-- | Retry failed requests with exponential backoff
retryRequest :: Int -> IO a -> IO (Either String a)
retryRequest 0 action = try action
retryRequest n action = do
  result <- try action
  case result of
    Right val -> return $ Right val
    Left err -> do
      threadDelay (1000000 * (2 ^ (5 - n))) -- Wait with exponential backoff
      retryRequest (n - 1) action
