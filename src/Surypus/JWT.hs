{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module Surypus.JWT
  ( JWTPayload (..),
    JWTConfig (..),
    TokenPair (..),
    defaultJWTConfig,
    generateTokenPair,
    generateAccessToken,
    validateAccessToken,
    generateRefreshToken,
    validateRefreshToken,
    refreshAccessToken,
  )
where

import Data.Aeson (FromJSON, ToJSON, decode, encode)
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import Data.Time (UTCTime, addUTCTime, diffUTCTime, getCurrentTime)
import GHC.Generics (Generic)
import Jose.Jwt (Algorithm (HS256), ClaimsSet (..), JwtContent (..), jwtDecode, jwtEncode)
import Surypus.Types (AppError (..), AppResult)

data JWTPayload = JWTPayload
  { jwtUserId :: Int,
    jwtUsername :: Text,
    jwtRole :: Text
  }
  deriving (Show, Eq, Generic)

instance ToJSON JWTPayload

instance FromJSON JWTPayload

data JWTConfig = JWTConfig
  { jwtSecret :: Text,
    jwtExpirationHours :: Int,
    jwtRefreshExpirationDays :: Int
  }
  deriving (Show, Eq)

defaultJWTConfig :: JWTConfig
defaultJWTConfig =
  JWTConfig
    { jwtSecret = "surypus-secret-key-change-in-production",
      jwtExpirationHours = 24,
      jwtRefreshExpirationDays = 7
    }

data TokenPair = TokenPair
  { tpAccessToken :: Text,
    tpRefreshToken :: Text,
    tpExpiresAt :: UTCTime
  }
  deriving (Show, Eq)

encodePayload :: JWTPayload -> UTCTime -> ClaimsSet
encodePayload payload expTime =
  ClaimsSet
    { iss = Nothing,
      sub = Just (T.pack (show (jwtUserId payload))),
      aud = Nothing,
      exp = Just (floor (diffUTCTime expTime (read "1970-01-01 00:00:00 UTC" :: UTCTime)) `div` 1),
      nbf = Nothing,
      iat = Nothing,
      jti = Just (jwtUsername payload)
    }

makeClaims :: JWTPayload -> UTCTime -> ClaimsSet
makeClaims payload expTime =
  ClaimsSet
    { iss = Just "surypus",
      sub = Just (T.pack (show (jwtUserId payload))),
      aud = Nothing,
      exp = Just (floor (diffUTCTime expTime (read "1970-01-01 00:00:00 UTC" :: UTCTime))),
      nbf = Nothing,
      iat = Nothing,
      jti = Just (jwtRole payload)
    }

generateAccessToken :: JWTConfig -> JWTPayload -> IO (Either Text Text)
generateAccessToken config payload = do
  now <- getCurrentTime
  let expiration = addUTCTime (fromIntegral (jwtExpirationHours config * 3600)) now
      claims = makeClaims payload expiration
      secret = TE.encodeUtf8 (jwtSecret config)
  case jwtEncode (secret, HS256) claims of
    Right token -> Right token
    Left err -> Left (T.pack (show err))

generateTokenPair :: JWTConfig -> JWTPayload -> IO TokenPair
generateTokenPair config payload = do
  now <- getCurrentTime
  let accessExpiration = addUTCTime (fromIntegral (jwtExpirationHours config * 3600)) now
      refreshExpiration = addUTCTime (fromIntegral (jwtRefreshExpirationDays config * 24 * 3600)) now
      accessClaims = makeClaims payload accessExpiration
      refreshClaims = makeClaims payload refreshExpiration
      secret = TE.encodeUtf8 (jwtSecret config)
  case (jwtEncode (secret, HS256) accessClaims, jwtEncode (secret, HS256) refreshClaims) of
    (Right accessToken, Right refreshToken) -> pure $ TokenPair accessToken refreshToken accessExpiration
    (Left err, _) -> error (show err)
    (_, Left err) -> error (show err)

validateAccessToken :: JWTConfig -> Text -> AppResult JWTPayload
validateAccessToken config token = do
  let secret = TE.encodeUtf8 (jwtSecret config)
  case jwtDecode secret token of
    Right claims -> case sub claims of
      Nothing -> Left (AuthError "Missing subject")
      Just subClaim ->
        case reads (T.unpack subClaim) of
          [(uId, "")] ->
            let username = maybe "" id (jti claims)
                role = maybe "user" id (jti claims)
             in Right (JWTPayload uId username role)
          _ -> Left (AuthError "Invalid subject format")
    Left err -> Left (AuthError (T.pack (show err)))

generateRefreshToken :: JWTConfig -> JWTPayload -> IO (Either Text Text)
generateRefreshToken config payload = do
  now <- getCurrentTime
  let expiration = addUTCTime (fromIntegral (jwtRefreshExpirationDays config * 24 * 3600)) now
      claims =
        ClaimsSet
          { iss = Just "surypus-refresh",
            sub = Just (T.pack (show (jwtUserId payload))),
            aud = Nothing,
            exp = Just (floor (diffUTCTime expiration (read "1970-01-01 00:00:00 UTC" :: UTCTime))),
            nbf = Nothing,
            iat = Nothing,
            jti = Just (jwtUsername payload)
          }
      secret = TE.encodeUtf8 (jwtSecret config)
  case jwtEncode (secret, HS256) claims of
    Right token -> Right token
    Left err -> Left (T.pack (show err))

validateRefreshToken :: JWTConfig -> Text -> AppResult (Int, UTCTime)
validateRefreshToken config token = do
  let secret = TE.encodeUtf8 (jwtSecret config)
  case jwtDecode secret token of
    Right claims -> case sub claims of
      Nothing -> Left (AuthError "Missing subject")
      Just subClaim ->
        case reads (T.unpack subClaim) of
          [(uId, "")] ->
            case exp claims of
              Nothing -> Left (AuthError "Missing expiration")
              Just expClaim -> Right (uId, read "1970-01-01 00:00:00 UTC" :: UTCTime)
          _ -> Left (AuthError "Invalid subject format")
    Left err -> Left (AuthError (T.pack (show err)))

refreshAccessToken :: JWTConfig -> JWTPayload -> IO Text
refreshAccessToken config payload = do
  now <- getCurrentTime
  let expiration = addUTCTime (fromIntegral (jwtExpirationHours config * 3600)) now
      claims = makeClaims payload expiration
      secret = TE.encodeUtf8 (jwtSecret config)
  case jwtEncode (secret, HS256) claims of
    Right token -> pure token
    Left err -> error (show err)
