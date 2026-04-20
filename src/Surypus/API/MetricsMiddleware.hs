{-# LANGUAGE OverloadedStrings #-}

module Surypus.API.MetricsMiddleware
  ( withMetricsCollection,
    MetricsMiddlewareConfig (..),
  )
where

import Data.ByteString.Lazy (fromStrict)
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import Network.HTTP.Types (Status, statusCode)
import Network.Wai (Middleware, Request, Response, responseLBS)
import qualified Network.Wai as Wai
import Surypus.Metrics (Metrics (..), incrementRequests, incrementResponses4xx, incrementResponses5xx)

data MetricsMiddlewareConfig = MetricsMiddlewareConfig
  { mmcMetrics :: Metrics,
    mmcPublicPaths :: [Text]
  }

withMetricsCollection :: MetricsMiddlewareConfig -> Middleware
withMetricsCollection cfg app req respond = do
  let isPublic = TE.decodeUtf8 (Wai.rawPathInfo req) `elem` mmcPublicPaths cfg
  unless isPublic $ incrementRequests (mmcMetrics cfg)
  app req $ \response -> do
    let status = Wai.responseStatus response
    let code = statusCode status
    unless isPublic $ do
      if code >= 500
        then incrementResponses5xx (mmcMetrics cfg)
        else
          if code >= 400
            then incrementResponses4xx (mmcMetrics cfg)
            else pure ()
    respond response

unless :: Bool -> IO () -> IO ()
unless False action = action
unless True _ = pure ()

isPublicPath :: [Text] -> Text -> Bool
isPublicPath paths path = path `elem` paths
