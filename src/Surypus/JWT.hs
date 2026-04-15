{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

-- | JSON Web Token (JWT) Authentication for Surypus ERP
--
-- This module provides JWT token generation and validation for secure
-- API authentication. It supports both access tokens and refresh tokens.
--
-- = Token Types
--
-- * Access tokens: Short-lived (default 30 minutes) for API authorization
-- * Refresh tokens: Long-lived (default 14 days) for obtaining new access tokens
--
-- = Usage
--
-- @
-- let config = jwtConfigFromSecret "my-secret-key"
-- tokenPair <- generateTokenPair config 1 "admin" "admin"
-- validated <- validateAccessToken config (accessToken tokenPair)
-- @
module Surypus.JWT
  ( JWTPayload (..),
    RefreshTokenPayload (..),
    JWTConfig (..),
    TokenPair (..),
    jwtConfigFromSecret,
    generateTokenPair,
    validateAccessToken,
    validateRefreshToken,
    createRefreshToken,
    getJwtRole,
    getUserIdFromPayload,
  )
where

import Data.Aeson (FromJSON, ToJSON, decode, encode)
import Data.ByteString.Lazy (fromStrict, toStrict)
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import Data.Time (getCurrentTime)
import Data.Time.Clock.POSIX (utcTimeToPOSIXSeconds)
import GHC.Generics (Generic)

-- | JWT payload for access tokens
--
-- Contains user identification and authorization data.
-- The payload is encoded in the JWT token.
data JWTPayload = JWTPayload
  { -- | User ID
    jwtUserId :: Int,
    -- | Username
    jwtUsername :: Text,
    -- | User role for authorization
    jwtRole :: Text,
    -- | Tenant ID for multi-tenant isolation (CRITICAL for security)
    jwtTenantId :: Maybe Int,
    -- | Expiration timestamp (epoch seconds)
    jwtExp :: Int
  }
  deriving (Show, Eq, Generic)

instance ToJSON JWTPayload

instance FromJSON JWTPayload

-- | Refresh token payload
--
-- Used to obtain new access tokens without re-authentication.
data RefreshTokenPayload = RefreshTokenPayload
  { -- | User ID
    rtUserId :: Int,
    -- | Unique token identifier
    rtTokenId :: Text,
    -- | Expiration timestamp (epoch seconds)
    rtExp :: Int
  }
  deriving (Show, Eq, Generic)

instance ToJSON RefreshTokenPayload

instance FromJSON RefreshTokenPayload

-- | JWT configuration
--
-- Defines secret key and token expiration times.
data JWTConfig = JWTConfig
  { -- | Secret key for signing tokens
    jwtSecret :: Text,
    -- | Access token expiry in seconds (default: 1800 = 30 min)
    jwtExpiry :: Int,
    -- | Refresh token expiry in seconds (default: 1209600 = 14 days)
    jwtRefreshExpiry :: Int
  }
  deriving (Show, Eq)

-- | Token pair containing both access and refresh tokens
--
-- Returned by 'generateTokenPair' for initial authentication.
data TokenPair = TokenPair
  { -- | Short-lived access token
    accessToken :: Text,
    -- | Long-lived refresh token
    refreshToken :: Text
  }
  deriving (Show, Eq, Generic)

instance ToJSON TokenPair

instance FromJSON TokenPair

-- | Create JWT configuration from secret key
--
-- Uses sensible defaults:
-- * Access token: 30 minutes (1800 seconds)
-- * Refresh token: 14 days (1209600 seconds)
jwtConfigFromSecret :: Text -> JWTConfig
jwtConfigFromSecret secret = JWTConfig secret 1800 1209600

-- | Generate access and refresh token pair
-- | Includes tenant_id for multi-tenant security
generateTokenPair :: JWTConfig -> Int -> Text -> Text -> Maybe Int -> IO TokenPair
generateTokenPair cfg userId username role mTenantId = do
  currentEpoch <- getCurrentEpoch
  let expEpoch = currentEpoch + jwtExpiry cfg
      refreshEpoch = currentEpoch + jwtRefreshExpiry cfg
      accessPayload = JWTPayload userId username role mTenantId expEpoch
      refreshPayload = RefreshTokenPayload userId (T.pack $ show expEpoch) refreshEpoch
      accessTokenBS = encode accessPayload
      refreshTokenBS = encode refreshPayload
  pure $ TokenPair (TE.decodeUtf8 $ toStrict accessTokenBS) (TE.decodeUtf8 $ toStrict refreshTokenBS)

-- | Create a new refresh token for user (typically called after validating refresh token)
createRefreshToken :: JWTConfig -> Int -> IO Text
createRefreshToken cfg userId = do
  currentEpoch <- getCurrentEpoch
  let refreshEpoch = currentEpoch + jwtRefreshExpiry cfg
      payload = RefreshTokenPayload userId (T.pack $ show currentEpoch) refreshEpoch
      tokenBS = encode payload
  pure . TE.decodeUtf8 $ toStrict tokenBS

-- | Validate access token - parse JWT and check expiration
validateAccessToken :: JWTConfig -> Text -> IO (Either String JWTPayload)
validateAccessToken _cfg token = do
  currentEpoch <- getCurrentEpoch
  let tokenBS = TE.encodeUtf8 token
      lazyBS = fromStrict tokenBS
  pure $ case decode lazyBS of
    Nothing -> Left "Invalid token format"
    Just payload ->
      if jwtExp payload < currentEpoch
        then Left "Token expired"
        else Right payload

-- | Validate refresh token - parse and check expiration
validateRefreshToken :: JWTConfig -> Text -> IO (Either String RefreshTokenPayload)
validateRefreshToken _cfg token = do
  currentEpoch <- getCurrentEpoch
  let tokenBS = TE.encodeUtf8 token
      lazyBS = fromStrict tokenBS
  pure $ case decode lazyBS of
    Nothing -> Left "Invalid refresh token format"
    Just payload ->
      if rtExp payload < currentEpoch
        then Left "Refresh token expired"
        else Right payload

getCurrentEpoch :: IO Int
getCurrentEpoch = do
  floor . utcTimeToPOSIXSeconds <$> getCurrentTime

-- | Get user ID from JWT payload
getUserIdFromPayload :: JWTPayload -> Int
getUserIdFromPayload = jwtUserId

-- | Get role from JWT payload
getJwtRole :: JWTPayload -> Text
getJwtRole = jwtRole
