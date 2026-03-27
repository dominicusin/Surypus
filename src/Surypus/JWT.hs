{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module Surypus.JWT where

import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (UTCTime, addUTCTime, getCurrentTime)
import GHC.Generics (Generic)
import Surypus.Types (AppError (..), AppResult)

data JWTPayload = JWTPayload
  { jwtUserId :: Int,
    jwtUsername :: Text,
    jwtRole :: Text
  }
  deriving (Show, Eq, Generic)

data JWTConfig = JWTConfig
  { jwtSecret :: Text,
    jwtExpirationHours :: Int,
    jwtRefreshExpirationDays :: Int
  }
  deriving (Show, Eq)

defaultJWTConfig :: JWTConfig
defaultJWTConfig =
  JWTConfig
    { jwtSecret = "surypus-secret-key",
      jwtExpirationHours = 24,
      jwtRefreshExpirationDays = 7
    }

data TokenPair = TokenPair
  { tpAccessToken :: Text,
    tpRefreshToken :: Text,
    tpExpiresAt :: UTCTime
  }
  deriving (Show, Eq)

generateTokenPair :: JWTConfig -> JWTPayload -> IO TokenPair
generateTokenPair config payload = do
  now <- getCurrentTime
  let accessExpiration = addUTCTime (fromIntegral (jwtExpirationHours config * 3600)) now
      refreshExpiration = addUTCTime (fromIntegral (jwtRefreshExpirationDays config * 24 * 3600)) now
      accessToken = jwtSecret config <> ":" <> T.pack (show (jwtUserId payload)) <> ":" <> jwtUsername payload <> ":" <> jwtRole payload <> ":" <> T.pack (show accessExpiration)
      refreshToken = "refresh:" <> T.pack (show (jwtUserId payload)) <> ":" <> T.pack (show refreshExpiration)
  pure $ TokenPair accessToken refreshToken accessExpiration

generateSimpleToken :: JWTConfig -> JWTPayload -> IO Text
generateSimpleToken config payload = do
  now <- getCurrentTime
  let expiration = addUTCTime (fromIntegral (jwtExpirationHours config * 3600)) now
      token = jwtSecret config <> ":" <> T.pack (show (jwtUserId payload)) <> ":" <> jwtUsername payload <> ":" <> jwtRole payload <> ":" <> T.pack (show expiration)
  pure token

validateSimpleToken :: JWTConfig -> Text -> AppResult JWTPayload
validateSimpleToken config token = do
  case T.splitOn ":" token of
    [secret, uid, username, role, _exp] ->
      if secret == jwtSecret config
        then case reads (T.unpack uid) of
          [(uId, "")] -> Right (JWTPayload uId username role)
          _ -> Left (AuthError "Invalid token")
        else Left (AuthError "Invalid secret")
    _ -> Left (AuthError "Invalid token format")

validateRefreshToken :: JWTConfig -> Text -> AppResult (Int, UTCTime)
validateRefreshToken config token = do
  case T.splitOn ":" token of
    [_uuid, uid, expStr] ->
      case reads (T.unpack uid) of
        [(uId, "")] ->
          case reads (T.unpack expStr) of
            [(exp, "")] -> Right (uId, exp)
            _ -> Left (AuthError "Invalid expiration")
        _ -> Left (AuthError "Invalid user id")
    _ -> Left (AuthError "Invalid refresh token format")

refreshAccessToken :: JWTConfig -> JWTPayload -> IO Text
refreshAccessToken config payload = do
  now <- getCurrentTime
  let expiration = addUTCTime (fromIntegral (jwtExpirationHours config * 3600)) now
      token = jwtSecret config <> ":" <> T.pack (show (jwtUserId payload)) <> ":" <> jwtUsername payload <> ":" <> jwtRole payload <> ":" <> T.pack (show expiration)
  pure token
