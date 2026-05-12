module Integration.API.ExternalAPI where

import Control.Exception (SomeException, try)
import Data.Aeson (Value, decode, encode)
import qualified Data.ByteString.Lazy as LBS
import Data.Text (Text)
import qualified Data.Text as T
-- import Network.HTTP.Client (HttpException, Manager, defaultManagerSettings, newManager, parseRequest)
-- import Network.HTTP.Client.TLS (tlsManagerSettings)
-- import Network.HTTP.Simple (httpLbs, setRequestBodyLBS, setRequestHeader, setRequestMethod)

-- | API client configuration
data APIClient = APIClient
  { manager :: (), -- Manager stub
    baseUrl :: String,
    apiKey :: Maybe Text
  }

-- | Initialize API client
-- initAPIClient :: String -> Maybe Text -> IO APIClient
-- initAPIClient url key = undefined
initAPIClient :: String -> Maybe Text -> IO APIClient
initAPIClient url key = pure $ APIClient () url key

-- | Make GET request
-- apiGet :: APIClient -> String -> IO (Either String LBS.ByteString)
-- apiGet client endpoint = undefined
apiGet :: APIClient -> String -> IO (Either String LBS.ByteString)
apiGet client endpoint = pure $ Left "Not implemented"

-- | Make POST request with JSON
-- apiPost :: APIClient -> String -> LBS.ByteString -> IO (Either String LBS.ByteString)
-- apiPost client endpoint body = undefined
apiPost :: APIClient -> String -> LBS.ByteString -> IO (Either String LBS.ByteString)
apiPost client endpoint body = pure $ Left "Not implemented"

-- | Handle API errors
-- handleAPIError :: Either HttpException a -> Either String a
-- handleAPIError = undefined
handleAPIError :: Either SomeException a -> Either String a
handleAPIError (Left err) = Left $ "HTTP error: " ++ show err
handleAPIError (Right val) = Right val

-- | Retry failed requests with exponential backoff
-- retryRequest :: Int -> IO a -> IO (Either String a)
-- retryRequest = undefined
retryRequest :: Int -> IO a -> IO (Either String a)
retryRequest 0 action = do
  result <- try (action :: IO a)
  return $ case result of
    Right val -> Right val
    Left err -> Left $ "HTTP error: " ++ show (err :: SomeException)
retryRequest n action = do
  result <- try (action :: IO a)
  case result of
    Right val -> pure $ Right val
    Left err -> do
      -- threadDelay (1000000 * (2 ^ (5 - n))) -- Wait with exponential backoff
      retryRequest (n - 1) action
