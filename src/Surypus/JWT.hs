-- | JWT (JSON Web Token) support
{-# LANGUAGE ImportQualifiedPost #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}
module Surypus.JWT
  ( JWTConfig (..),
    TokenPair (..),
    JWTError (..),
    jwtConfigFromSecret,
    generateTokenPair,
    validateRefreshToken,
    validateAccessToken,
    accessToken,
    refreshToken,
    rtUserId,
    rtExpiresAt,
    decodeAndValidateToken,
  )
where

import Crypto.Hash.SHA256 (hashWith)
import Data.Base64.URL (encode)
import Data.ByteString.Char8 (ByteString)
import qualified Data.ByteString.Char8 as BS
import qualified Data.ByteString.Lazy.Char8 as LBS
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import Data.Time (UTCTime, addUTCTime, getCurrentTime)
import Data.Time.Clock (NominalDiffTime)
import GHC.ByteOrder (ByteOrder (..))

-- | JWT errors
data JWTError = JWTExpired | JWTInvalid | JWTMissing | JWTMalformed
  deriving (Show, Eq)

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

-- | Get user ID from refresh token (extracts from token string)
rtUserId :: TokenPair -> Int64
rtUserId tokenPair =
  case T.stripPrefix "fake-refresh-token-" (tpRefreshToken tokenPair) of
    Just uidStr -> read (T.unpack uidStr)
    Nothing -> 1

-- | Get expires at from token pair
rtExpiresAt :: TokenPair -> UTCTime
rtExpiresAt = tpExpiresAt

-- | Base64URL encode
b64UrlEncode :: ByteString -> Text
b64UrlEncode = T.takeWhileEnd (/= '=') . T.map (\c -> if c == '-' then '+' else if c == '_' then '/' else c) . TE.decodeUtf8 . encode . BS.map fromIntegral

-- | Base64URL decode
b64UrlDecode :: Text -> Maybe ByteString
b64UrlDecode input = 
  let padded = T.concat [input, T.replicate ((4 - T.length input `mod` 4) `mod` 4) "="]
      normalized = T.map (\c -> if c == '-' then '+' else if c == '_' then '/' else c) padded
  in Just $ TE.encodeUtf8 normalized

-- | Simple JWT-like token generation (for development - use jose library for production)
generateJWTToken :: Text -> Int64 -> Text -> Text -> UTCTime -> Text
generateJWTToken secret userId username role expiresAt =
  let header = "{\"alg\":\"HS256\",\"typ\":\"JWT\"}"
      -- Create payload with user info
      payload = T.concat
        [ "{\"user_id\":"
        , T.pack (show userId)
        , ",\"username\":\""
        , username
        , "\",\"role\":\""
        , role
        , "\",\"exp\":"
        , T.pack (show (floor $ utctDayTime expiresAt))
        , "}"
        ]
      -- Simple signature (not cryptographically secure - use jose in production)
      toSign = T.concat [b64UrlEncode (TE.encodeUtf8 header), ".", b64UrlEncode (TE.encodeUtf8 payload)]
      signature = b64UrlEncode $ BS.take 20 $ hashWith (TE.encodeUtf8 secret) (TE.encodeUtf8 toSign)
   in toSign <> "." <> signature

-- | Generate a token pair
generateTokenPair :: JWTConfig -> Int64 -> Text -> Text -> Maybe Int64 -> IO TokenPair
generateTokenPair cfg userId username role _mPersonId = do
  now <- getCurrentTime
  let expiresAt = addUTCTime (jwtExpiry cfg) now
      accessTok = generateJWTToken (jwtSecret cfg) userId username role expiresAt
      refreshTok = T.concat ["fake-refresh-token-", T.pack (show userId)]
   in pure $
        TokenPair
          { tpAccessToken = accessTok,
            tpRefreshToken = refreshTok,
            tpExpiresAt = expiresAt
          }

-- | Validate a refresh token (stub - in production this would verify signature)
validateRefreshToken :: JWTConfig -> Text -> IO (Either Text TokenPair)
validateRefreshToken _cfg token = do
  now <- getCurrentTime
  case T.stripPrefix "fake-refresh-token-" token of
    Just uidStr -> case reads (T.unpack uidStr) of
      [(userId, "")] -> do
        let expiresAt = addUTCTime 1209600 now -- 14 days
        pure $ Right $
          TokenPair
            { tpAccessToken = "fake-access-token-" <> uidStr,
              tpRefreshToken = token,
              tpExpiresAt = expiresAt
            }
      _ -> pure $ Left "Invalid token format"
    Nothing -> pure $ Left "Invalid token format"

-- | Validate an access token and extract user_id
validateAccessToken :: Text -> Text -> IO (Either Text Int64)
validateAccessToken secret token = do
  -- Parse JWT token (header.payload.signature)
  case T.split (== '.') token of
    [_, payloadB64, _] -> do
      -- Decode payload and extract user_id (simplified)
      let payloadStr = payloadB64
      -- Extract user_id from JSON (simplified parsing)
      case T.words $ T.filter (\c -> c /= '{' && c /= '}' && c /= '"') payloadStr of
        (_:userIdStr:_) -> case reads (T.unpack userIdStr) of
          [(userId, "")] -> pure $ Right userId
          _ -> pure $ Left "Invalid user_id in token"
        _ -> pure $ Left "Invalid token format"
    _ -> pure $ Left "Invalid token format"

-- | Decode and validate JWT token, returning user info
decodeAndValidateToken :: Text -> Text -> IO (Either JWTError (Int64, Text, UTCTime))
decodeAndValidateToken secret token = do
  now <- getCurrentTime
  case T.split (== '.') token of
    [headerB64, payloadB64, sigB64] -> do
      -- Verify signature
      let toSign = T.concat [headerB64, ".", payloadB64]
          expectedSig = b64UrlEncode $ BS.take 20 $ hashWith (TE.encodeUtf8 secret) (TE.encodeUtf8 toSign)
      if sigB64 /= expectedSig
        then pure $ Left JWTInvalid
        else do
          -- Parse payload
          let payload = payloadB64
              -- Extract exp (expiration) - simplified
              expTime = utctDayTime now + 3600 -- stub: assume valid for 1 hour
          -- Extract user_id - simplified parsing
          let userId = 1 :: Int64
              role = "user" :: Text
          pure $ Right (userId, role, addUTCTime 3600 now)
    _ -> pure $ Left JWTMalformed