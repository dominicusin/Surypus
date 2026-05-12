-- | JWT (JSON Web Token) support
{-# LANGUAGE ImportQualifiedPost #-}
{-# LANGUAGE OverloadedStrings #-}
module Surypus.JWT
  ( JWTConfig (..),
    TokenPair (..),
    jwtConfigFromSecret,
    generateTokenPair,
    validateRefreshToken,
    accessToken,
    refreshToken,
    rtUserId,
  )
where

import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (UTCTime, addUTCTime, getCurrentTime)
import Data.Time.Clock (NominalDiffTime)

-- | JWT configuration
data JWTConfig = JWTConfig
  { jwtSecret :: Text,
    jwtExpiry :: NominalDiffTime,
    jwtRefreshExpiry :: NominalDiffTime
  }
  deriving (Show, Eq)

-- | Create JWT config from secret key
jwtConfigFromSecret :: Text -> JWTConfig
jwtConfigFromSecret secret =
  JWTConfig
    { jwtSecret = secret,
      jwtExpiry = 3600,
      jwtRefreshExpiry = 1209600
    }

-- | Token pair (access + refresh)
data TokenPair = TokenPair
  { tpAccessToken :: Text,
    tpRefreshToken :: Text,
    tpExpiresAt :: UTCTime
  }
  deriving (Show, Eq)

-- | Get access token
accessToken :: TokenPair -> Text
accessToken = tpAccessToken

-- | Get refresh token
refreshToken :: TokenPair -> Text
refreshToken = tpRefreshToken

-- | Get user ID from refresh token
rtUserId :: TokenPair -> Int64
rtUserId _ = 1 -- stub

-- | Generate a token pair
generateTokenPair :: JWTConfig -> Int64 -> Text -> Text -> Maybe Int64 -> IO TokenPair
generateTokenPair _cfg userId _username _role _mPersonId = do
  now <- getCurrentTime
  let expiresAt = addUTCTime 3600 now
  pure $
    TokenPair
      { tpAccessToken = "fake-access-token-" <> T.pack (show userId),
        tpRefreshToken = "fake-refresh-token-" <> T.pack (show userId),
        tpExpiresAt = expiresAt
      }

-- | Validate a refresh token
validateRefreshToken :: JWTConfig -> Text -> IO (Either Text TokenPair)
validateRefreshToken _cfg _token = do
  pure $ Left "Refresh token validation not implemented"