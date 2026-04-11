{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Surypus.API.JWT
  ( withJWTAuth,
    extractUserId,
    extractUserRole,
    JWTClaims (..),
  )
where

import Data.Aeson (decode)
import qualified Data.ByteString.Lazy as LBS
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import Network.Wai (Middleware, Request, requestHeaders)
import qualified Network.Wai as Wai
import Surypus.JWT (JWTConfig (..), JWTPayload (..))
import Text.Read (readMaybe)

data JWTClaims = JWTClaims
  { jwtClaimsUserId :: Int,
    jwtClaimsUsername :: Text,
    jwtClaimsRole :: Text
  }
  deriving (Show, Eq)

withJWTAuth :: JWTConfig -> [Text] -> Middleware
withJWTAuth jwtCfg publicPaths app req respond
  | isPublicPath = app req respond
  | otherwise = do
      let authResult = validateJWT jwtCfg req
      case authResult of
        Left err -> respond $ errorResponse 401 (T.pack err)
        Right claims -> do
          let req' =
                req
                  { Wai.requestHeaders =
                      ("x-user-id", TE.encodeUtf8 (T.pack (show (jwtClaimsUserId claims))))
                        : ("x-user-role", TE.encodeUtf8 (jwtClaimsRole claims))
                        : requestHeaders req
                  }
          app req' respond
  where
    isPublicPath = pathInfo req `elem` publicPaths
    pathInfo = TE.decodeUtf8 . Wai.rawPathInfo

validateJWT :: JWTConfig -> Request -> Either String JWTClaims
validateJWT _ req = do
  let mAuthHeader = lookup "Authorization" (requestHeaders req)
  authHeader <- maybe (Left "Missing Authorization header") Right mAuthHeader
  token <- stripBearer (TE.decodeUtf8 authHeader)
  let tokenBS = TE.encodeUtf8 token
      tokenLazy = LBS.fromStrict tokenBS
  payload <- case decode tokenLazy of
    Nothing -> Left "Invalid token format"
    Just p -> Right p
  pure $
    JWTClaims
      { jwtClaimsUserId = jwtUserId payload,
        jwtClaimsUsername = jwtUsername payload,
        jwtClaimsRole = jwtRole payload
      }

stripBearer :: Text -> Either String Text
stripBearer t = case T.stripPrefix "Bearer " t of
  Just rest -> if T.null rest then Left "Empty token" else Right rest
  Nothing -> Left "Invalid Authorization header"

errorResponse :: Int -> Text -> Wai.Response
errorResponse status msg =
  let body = LBS.fromStrict (TE.encodeUtf8 ("{\"error\":\"" <> msg <> "\"}"))
   in Wai.responseLBS (toEnum status) [("Content-Type", "application/json")] body

extractUserId :: Request -> Maybe Int
extractUserId req = do
  header <- lookup "x-user-id" (Wai.requestHeaders req)
  readMaybe (T.unpack (TE.decodeUtf8 header)) :: Maybe Int

extractUserRole :: Request -> Maybe Text
extractUserRole req = do
  header <- lookup "x-user-role" (Wai.requestHeaders req)
  pure $ TE.decodeUtf8 header
