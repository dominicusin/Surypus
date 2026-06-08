{-# LANGUAGE OverloadedStrings #-}

module Main where
import Network.Wai (Application, Request, responseFile, responseLBS, pathInfo, requestMethod, queryString, getRequestBodyChunk, Response, ResponseReceived)
import Network.Wai.Middleware.Gzip (gzip, def)
import Network.Wai.Middleware.RequestLogger (logStdoutDev)
import Network.HTTP.Types (status200, status400, status404, status405)
import Network.Wai.Handler.Warp (run)
import Data.Aeson (Value(..), decode, encode, object, (.=), (.:))
import Data.Aeson.Types (FromJSON(..), withObject)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Text.Encoding (decodeUtf8)
import Data.Decimal (Decimal)
import System.Environment (lookupEnv)
import System.IO (hFlush, stdout)
import System.FilePath ((</>))
import System.Directory (doesFileExist)
import qualified Data.ByteString as B
import qualified Data.ByteString.Lazy as BL

import Finance.Tax (mkTaxRate, calcVAT, calcPriceWithVAT, calcVATFromInclusive, calcPriceWithoutVAT)

staticDir :: FilePath
staticDir = "web"

app :: Application
app req respond = do
  let path = T.intercalate "/" (pathInfo req)
      method = requestMethod req
  case method of
    "GET" -> case path of
      "api/health"   -> respond $ responseLBS status200 [("Content-Type", "application/json")] (encode $ object
          [ "status" .= ("ok" :: Text)
          , "service" .= ("surypus" :: Text)
          , "version" .= ("0.1.0.0" :: Text)
          , "db" .= ("ok" :: Text)
          ])
      "api/version"  -> respond $ responseLBS status200 [("Content-Type", "application/json")] (encode $ object ["version" .= ("0.1.0.0" :: Text)])
      "api/finance/info" -> handleFinanceInfo respond
      "api/tax/calc-vat" -> handleCalcVAT req respond
      "api/tax/calc-from-inclusive" -> handleCalcFromInclusive req respond
      _ -> serveFile path respond
    "POST" -> case path of
      "api/accounting/validate" -> handleValidateTransaction req respond
      _ -> respond $ responseLBS status405 [("Content-Type", "application/json")] (encode $ object ["error" .= ("Method not allowed" :: Text)])
    _ -> respond $ responseLBS status405 [("Content-Type", "application/json")] (encode $ object ["error" .= ("Method not allowed" :: Text)])

handleCalcVAT :: Request -> (Response -> IO ResponseReceived) -> IO ResponseReceived
handleCalcVAT req respond = do
  let params = parseParams req
  case (lookup "amount" params, lookup "rate" params) of
    (Just amountStr, Just rateStr) ->
      case (readMaybeDecimal amountStr, readMaybeDecimal rateStr) of
        (Just amount, Just rate) ->
          case mkTaxRate rate of
            Just tr ->
              respond $ responseLBS status200 [("Content-Type", "application/json")] $
                encode $ object
                  [ "amount" .= (realToFrac amount :: Double)
                  , "rate" .= (realToFrac rate :: Double)
                  , "vat" .= (realToFrac (calcVAT amount tr) :: Double)
                  , "inclusive" .= (realToFrac (calcPriceWithVAT amount tr) :: Double)
                  ]
            Nothing ->
              respond $ responseLBS status400 [("Content-Type", "application/json")] $
                encode $ object ["error" .= ("Invalid tax rate (must be 0-100)" :: Text)]
        _ ->
          respond $ responseLBS status400 [("Content-Type", "application/json")] $
            encode $ object ["error" .= ("Invalid amount or rate" :: Text)]
    _ ->
      respond $ responseLBS status400 [("Content-Type", "application/json")] $
        encode $ object ["error" .= ("Missing 'amount' or 'rate' query parameter" :: Text)]

handleCalcFromInclusive :: Request -> (Response -> IO ResponseReceived) -> IO ResponseReceived
handleCalcFromInclusive req respond = do
  let params = parseParams req
  case (lookup "amount" params, lookup "rate" params) of
    (Just amountStr, Just rateStr) ->
      case (readMaybeDecimal amountStr, readMaybeDecimal rateStr) of
        (Just amount, Just rate) ->
          case mkTaxRate rate of
            Just tr ->
              respond $ responseLBS status200 [("Content-Type", "application/json")] $
                encode $ object
                  [ "inclusive" .= (realToFrac amount :: Double)
                  , "rate" .= (realToFrac rate :: Double)
                  , "vat" .= (realToFrac (calcVATFromInclusive amount tr) :: Double)
                  , "exclusive" .= (realToFrac (calcPriceWithoutVAT amount tr) :: Double)
                  ]
            Nothing ->
              respond $ responseLBS status400 [("Content-Type", "application/json")] $
                encode $ object ["error" .= ("Invalid tax rate (must be 0-100)" :: Text)]
        _ ->
          respond $ responseLBS status400 [("Content-Type", "application/json")] $
            encode $ object ["error" .= ("Invalid amount or rate" :: Text)]
    _ ->
      respond $ responseLBS status400 [("Content-Type", "application/json")] $
        encode $ object ["error" .= ("Missing 'amount' or 'rate' query parameter" :: Text)]

handleFinanceInfo :: (Response -> IO ResponseReceived) -> IO ResponseReceived
handleFinanceInfo respond =
  respond $ responseLBS status200 [("Content-Type", "application/json")] $
    encode $ object
      [ "service" .= ("Surypus Finance API" :: Text)
      , "endpoints" .= ([
          object [ "path" .= ("/api/tax/calc-vat" :: Text), "method" .= ("GET" :: Text), "params" .= ("amount, rate" :: Text), "description" .= ("Calculate VAT and inclusive price from net amount" :: Text) ]
        , object [ "path" .= ("/api/tax/calc-from-inclusive" :: Text), "method" .= ("GET" :: Text), "params" .= ("amount, rate" :: Text), "description" .= ("Extract VAT and exclusive price from gross amount" :: Text) ]
        , object [ "path" .= ("/api/accounting/validate" :: Text), "method" .= ("POST" :: Text), "body" .= ("{\"debits\": [number], \"credits\": [number]}" :: Text), "description" .= ("Validate double-entry bookkeeping balance" :: Text) ]
        , object [ "path" .= ("/api/finance/info" :: Text), "method" .= ("GET" :: Text), "description" .= ("This documentation" :: Text) ]
        , object [ "path" .= ("/" :: Text), "method" .= ("GET" :: Text), "description" .= ("Serve web dashboard (index.html)" :: Text) ]
        ] :: [Value])
      ]

data BalanceInput = BalanceInput { biDebits :: [Double], biCredits :: [Double] }

instance FromJSON BalanceInput where
  parseJSON = withObject "BalanceInput" $ \o ->
    BalanceInput <$> o .: "debits" <*> o .: "credits"

getRequestBody :: Request -> IO BL.ByteString
getRequestBody req = BL.fromChunks <$> go
  where
    go = do
      chunk <- getRequestBodyChunk req
      if B.null chunk then pure [] else (chunk:) <$> go

handleValidateTransaction :: Request -> (Response -> IO ResponseReceived) -> IO ResponseReceived
handleValidateTransaction req respond = do
  body <- getRequestBody req
  case decode body of
    Just (BalanceInput debits credits) ->
      let totalDebits = sum debits
          totalCredits = sum credits
          diff = abs (totalDebits - totalCredits)
          balanced = diff < 0.001
      in respond $ responseLBS (if balanced then status200 else status400) [("Content-Type", "application/json")] $
        encode $ object
          [ "balanced" .= balanced
          , "totalDebits" .= totalDebits
          , "totalCredits" .= totalCredits
          , "difference" .= diff
          , "message" .= (if balanced then ("Transaction is balanced" :: Text) else ("Debits and credits do not match" :: Text))
          ]
    Nothing ->
      respond $ responseLBS status400 [("Content-Type", "application/json")] $
        encode $ object ["error" .= ("Invalid JSON body. Expected {\"debits\": [number], \"credits\": [number]}" :: Text)]

-- | Parse query string parameters: [(Text, Maybe Text)]
parseParams :: Request -> [(Text, Text)]
parseParams req = [(decodeUtf8 k, decodeUtf8 v) | (k, Just v) <- queryString req]

-- | Safely parse a Decimal from Text
readMaybeDecimal :: Text -> Maybe Decimal
readMaybeDecimal t = case reads (T.unpack t) of
  [(d, "")] -> Just d
  _         -> Nothing

serveFile :: Text -> (Response -> IO ResponseReceived) -> IO ResponseReceived
serveFile path respond = do
  let filePath = staticDir </> T.unpack path
  exists <- doesFileExist filePath
  if exists
    then respond $ responseFile status200 [] filePath Nothing
    else do
      indexExists <- doesFileExist (staticDir </> "index.html")
      if indexExists
        then respond $ responseFile status200 [] (staticDir </> "index.html") Nothing
        else respond $ responseLBS status404 [("Content-Type", "text/plain")] "Not found"

main :: IO ()
main = do
  port <- fmap (maybe 8080 read) (lookupEnv "PORT")
  putStrLn $ "Starting Surypus server on http://0.0.0.0:" ++ show port
  hFlush stdout
  run port $ logStdoutDev $ gzip def app
