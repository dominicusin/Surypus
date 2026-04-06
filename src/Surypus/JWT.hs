{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

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
    rtUserId,
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

data JWTPayload = JWTPayload
  { jwtUserId :: Int,
    jwtUsername :: Text,
    jwtRole :: Text,
    jwtExp :: Int -- Expiration timestamp
  }
  deriving (Show, Eq, Generic)

instance ToJSON JWTPayload

instance FromJSON JWTPayload

data RefreshTokenPayload = RefreshTokenPayload
  { rtUserId :: Int,
    rtTokenId :: Text, -- UUID or random string
    rtExp :: Int -- Expiration timestamp
  }
  deriving (Show, Eq, Generic)

instance ToJSON RefreshTokenPayload

instance FromJSON RefreshTokenPayload

data JWTConfig = JWTConfig
  { jwtSecret :: Text,
    jwtExpiry :: Int, -- Access token expiry in seconds
    jwtRefreshExpiry :: Int -- Refresh token expiry in seconds
  }
  deriving (Show, Eq)

data TokenPair = TokenPair
  { accessToken :: Text,
    refreshToken :: Text
  }
  deriving (Show, Eq, Generic)

instance ToJSON TokenPair

instance FromJSON TokenPair

jwtConfigFromSecret :: Text -> JWTConfig
jwtConfigFromSecret secret = JWTConfig secret 1800 1209600 -- 30 min access, 14 day refresh

-- | Generate access and refresh token pair
generateTokenPair :: JWTConfig -> Int -> Text -> Text -> IO TokenPair
generateTokenPair cfg userId username role = do
  currentEpoch <- getCurrentEpoch
  let expEpoch = currentEpoch + jwtExpiry cfg
      refreshEpoch = currentEpoch + jwtRefreshExpiry cfg
      accessPayload = JWTPayload userId username role expEpoch
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
