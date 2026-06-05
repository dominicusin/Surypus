{-# LANGUAGE OverloadedStrings #-}

module Main where

import Network.Wai (Application, responseFile, responseLBS, pathInfo, requestMethod, Response, ResponseReceived)
import Network.Wai.Middleware.Gzip (gzip, def)
import Network.Wai.Middleware.RequestLogger (logStdoutDev)
import Network.HTTP.Types (status200, status404)
import Network.Wai.Handler.Warp (run)
import Data.Aeson (encode, object, (.=))
import Data.Text (Text)
import qualified Data.Text as T
import System.Environment (lookupEnv)
import System.IO (hFlush, stdout)
import System.FilePath ((</>))
import System.Directory (doesFileExist)

staticDir :: FilePath
staticDir = "web"

app :: Application
app req respond = do
  let path = T.intercalate "/" (pathInfo req)
  if requestMethod req == "GET"
    then case path of
      "api/health" -> respond $ responseLBS status200
        [("Content-Type", "application/json")]
        (encode $ object ["status" .= ("ok" :: Text), "service" .= ("surypus" :: Text)])
      "api/version" -> respond $ responseLBS status200
        [("Content-Type", "application/json")]
        (encode $ object ["version" .= ("0.1.0.0" :: Text)])
      _ -> serveFile path respond
    else respond $ responseLBS status404 [("Content-Type", "text/plain")] "Not found"

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
