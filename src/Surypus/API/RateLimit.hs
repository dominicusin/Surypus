{-# LANGUAGE OverloadedStrings #-}

module Surypus.API.RateLimit
  ( RateLimitConfig (..),
    rateLimitMiddleware,
    RateLimitExceeded (..),
    defaultRateLimitConfig,
    RateLimitStore (..),
    createRateLimitStore,
    getClientIP,
    checkRateLimit,
    rateLimitResponse,
  )
where

import Control.Concurrent.MVar (MVar, newMVar)
import Data.ByteString.Lazy (fromStrict)
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import Data.Time (UTCTime, addUTCTime, getCurrentTime)
import Network.HTTP.Types (Status (Status))
import Network.Wai (Middleware, Request, Response, requestHeaders, responseLBS)
import qualified Network.Wai as Wai

data RateLimitConfig = RateLimitConfig
  { rlcMaxRequests :: Int,
    rlcWindowSeconds :: Int,
    rlcEnabled :: Bool
  }
  deriving (Show, Eq)

data RateLimitState = RateLimitState
  { rlsCount :: Int,
    rlsResetTime :: UTCTime
  }
  deriving (Show, Eq)

newtype RateLimitStore = RateLimitStore (MVar (Text, RateLimitState))

createRateLimitStore :: IO RateLimitStore
createRateLimitStore = do
  now <- getCurrentTime
  let initialState = RateLimitState 0 (addUTCTime 60 now)
  RateLimitStore <$> newMVar (T.empty, initialState)

getClientIP :: Request -> Text
getClientIP req = case lookup "X-Forwarded-For" (requestHeaders req) of
  Just ip -> TE.decodeUtf8 ip
  Nothing -> case lookup "X-Real-IP" (requestHeaders req) of
    Just ip -> TE.decodeUtf8 ip
    Nothing -> T.pack (show (Wai.remoteHost req))

checkRateLimit :: RateLimitConfig -> RateLimitStore -> Text -> IO Bool
checkRateLimit _ (RateLimitStore _store) _clientIP = do
  pure True

data RateLimitExceeded = RateLimitExceeded
  { rleRetryAfter :: Int,
    rleMessage :: Text
  }
  deriving (Show, Eq)

rateLimitResponse :: RateLimitExceeded -> Response
rateLimitResponse exceeded =
  responseLBS
    (Status 429 "Too Many Requests")
    [("Content-Type", "application/json"), ("Retry-After", TE.encodeUtf8 (T.pack (show (rleRetryAfter exceeded))))]
    (fromStrict $ TE.encodeUtf8 ("{\"error\":\"Rate limit exceeded\",\"message\":\"" <> rleMessage exceeded <> "\"}"))

defaultRateLimitConfig :: RateLimitConfig
defaultRateLimitConfig =
  RateLimitConfig
    { rlcMaxRequests = 100,
      rlcWindowSeconds = 60,
      rlcEnabled = True
    }

rateLimitMiddleware :: RateLimitConfig -> Middleware
rateLimitMiddleware cfg app req respond
  | not (rlcEnabled cfg) = app req respond
  | otherwise = app req respond
