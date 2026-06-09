{-# LANGUAGE OverloadedStrings #-}
module Surypus.API.RateLimiter
  ( RateLimiterConfig(..)
  , RateLimiterState(..)
  , initRateLimiter
  , rateLimiterMiddleware
  , defaultRateLimiterConfig
  ) where

import Control.Concurrent.STM (TVar, atomically, newTVarIO, readTVar, writeTVar)
import Data.Int (Int64)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as M
import Data.Maybe (fromMaybe)
import Data.Sequence (Seq)
import qualified Data.Sequence as Seq
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import Data.Time.Clock (NominalDiffTime, UTCTime, diffUTCTime, getCurrentTime)
import Network.HTTP.Types (status429)
import Network.Socket (SockAddr(..))
import Network.Wai (Application, Request, requestHeaders, responseLBS)
import qualified Network.Wai as W
import qualified Surypus.JWT.Token as JWT

data RateLimiterConfig = RateLimiterConfig
  { rlcDefaultIpLimit :: !Int
  , rlcDefaultTenantLimit :: !Int
  , rlcWindowSec :: !Int
  , rlcTenantOverrides :: !(Map Int64 Int)
  }

data RateLimiterState = RateLimiterState
  { rlsIpWindows :: !(TVar (Map Text (Seq UTCTime)))
  , rlsTenantWindows :: !(TVar (Map Int64 (Seq UTCTime)))
  }

defaultRateLimiterConfig :: RateLimiterConfig
defaultRateLimiterConfig = RateLimiterConfig
  { rlcDefaultIpLimit = 100
  , rlcDefaultTenantLimit = 500
  , rlcWindowSec = 60
  , rlcTenantOverrides = M.empty
  }

initRateLimiter :: RateLimiterConfig -> IO RateLimiterState
initRateLimiter _cfg = do
  ipVar <- newTVarIO M.empty
  tenantVar <- newTVarIO M.empty
  return $ RateLimiterState ipVar tenantVar

rateLimiterMiddleware :: RateLimiterConfig -> RateLimiterState -> Application -> Application
rateLimiterMiddleware cfg state app req respond = do
  let clientIp = extractClientIp req

  ipLimitOk <- checkSlidingWindow
    (rlsIpWindows state)
    clientIp
    (rlcDefaultIpLimit cfg)
    (rlcWindowSec cfg)
  if not ipLimitOk
    then respond rateLimitedResponse
    else do
      tenantCheck <- case extractBearerToken req of
        Just token -> do
          result <- JWT.verifyToken token
          case result of
            Right claims -> case JWT.ucTenantId claims of
              Just tid -> do
                let limit = fromMaybe (rlcDefaultTenantLimit cfg)
                          (M.lookup tid (rlcTenantOverrides cfg))
                checkSlidingWindow (rlsTenantWindows state) tid limit (rlcWindowSec cfg)
              Nothing -> return True
            Left _ -> return True
        Nothing -> return True
      if tenantCheck
        then app req respond
        else respond rateLimitedResponse

rateLimitedResponse :: W.Response
rateLimitedResponse =
  responseLBS status429
    [("Content-Type", "application/json")]
    "{\"error\":\"Rate limit exceeded\"}"

extractClientIp :: Request -> Text
extractClientIp req =
  case lookup "x-forwarded-for" (W.requestHeaders req) of
    Just ips -> T.takeWhile (/= ',') (TE.decodeUtf8 ips)
    Nothing -> case W.remoteHost req of
      SockAddrInet _ addr -> T.pack (show addr)
      SockAddrInet6 _ _ addr _ -> T.pack (show addr)
      _ -> "unknown"

extractBearerToken :: Request -> Maybe Text
extractBearerToken req = do
  hdr <- lookup "Authorization" (W.requestHeaders req)
  let hdrStr = TE.decodeUtf8 hdr
  T.stripPrefix "Bearer " hdrStr

checkSlidingWindow :: (Ord k) => TVar (Map k (Seq UTCTime)) -> k -> Int -> Int -> IO Bool
checkSlidingWindow var key limit windowSec = do
  now <- getCurrentTime
  let windowSize = fromIntegral windowSec :: NominalDiffTime
  atomically $ do
    m <- readTVar var
    let reqs = fromMaybe Seq.empty (M.lookup key m)
        valid = Seq.dropWhileL (\t -> diffUTCTime now t > windowSize) reqs
    if Seq.length valid < limit
      then do
        writeTVar var (M.insert key (valid Seq.|> now) m)
        return True
      else return False
