{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Surypus.API.JWTMiddleware
  ( withJWTAuth,
    extractUserIdFromRequest,
    extractRoleFromRequest,
  )
where

import Control.Monad.IO.Class (liftIO)
import Data.Aeson (decode)
import Data.ByteString.Lazy (fromStrict)
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import Network.HTTP.Types (status401)
import Network.Wai (Middleware, Request, rawPathInfo, requestHeaders, responseLBS)
import qualified Network.Wai as Wai
import Surypus.JWT (JWTConfig (..), JWTPayload (..), validateAccessToken)
import Text.Read (readMaybe)

withJWTAuth :: JWTConfig -> [Text] -> Middleware
withJWTAuth jwtCfg publicPaths app req respond
  | isPublicPath = app req respond
  | otherwise = do
      let authResult = validateJWT jwtCfg req
      case authResult of
        Left err -> respond $ unauthorizedResponse (T.pack err)
        Right payload -> do
          let req' =
                req
                  { Wai.requestHeaders =
                      ("x-user-id", TE.encodeUtf8 (T.pack (show (jwtUserId payload))))
                        : ("x-user-role", TE.encodeUtf8 (jwtRole payload))
                        : requestHeaders req
                  }
          app req' respond
  where
    isPublicPath = pathInfo req `elem` publicPaths
    pathInfo = TE.decodeUtf8 . rawPathInfo

validateJWT :: JWTConfig -> Request -> Either String JWTPayload
validateJWT _ req = do
  let mAuthHeader = lookup "Authorization" (requestHeaders req)
  authHeader <- maybe (Left "Missing Authorization header") Right mAuthHeader
  token <- stripBearer (TE.decodeUtf8 authHeader)
  let tokenBS = TE.encodeUtf8 token
  case decode (fromStrict tokenBS) of
    Nothing -> Left "Invalid token format"
    Just p -> Right p

stripBearer :: Text -> Either String Text
stripBearer t = case T.stripPrefix "Bearer " t of
  Just rest -> if T.null rest then Left "Empty token" else Right rest
  Nothing -> Left "Invalid Authorization header format"

unauthorizedResponse :: Text -> Wai.Response
unauthorizedResponse msg =
  responseLBS
    status401
    [("Content-Type", "application/json")]
    (fromStrict . TE.encodeUtf8 $ ("{\"error\":\"" <> msg <> "\"}"))

extractUserIdFromRequest :: Request -> Maybe Int
extractUserIdFromRequest req = do
  mUserId <- lookup "x-user-id" (Wai.requestHeaders req)
  let userIdStr = TE.decodeUtf8 mUserId
  readMaybe (T.unpack userIdStr)

extractRoleFromRequest :: Request -> Maybe Text
extractRoleFromRequest req = do
  mRole <- lookup "x-user-role" (Wai.requestHeaders req)
  pure $ TE.decodeUtf8 mRole
