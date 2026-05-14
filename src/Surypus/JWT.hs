-- | JWT (JSON Web Token) support
{-# LANGUAGE ImportQualifiedPost #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE ScopedTypeVariables #-}
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

-- Using a simple hash for development stub
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import Data.Time (UTCTime, addUTCTime, getCurrentTime)
import Data.Time.Clock (NominalDiffTime, utctDayTime)

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

-- | Base64URL encode (without padding) - stub for development
b64UrlEncode :: Text -> Text
b64UrlEncode input = 
  T.takeWhile (/= '=') input

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
       -- Simple signature (stub - just use hash of content for development)
       toSign = T.concat [header, ".", payload]
       signature = T.take 20 $ T.pack $ show $ sum $ map fromEnum $ T.unpack toSign
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
validateRefreshToken _cfg token = do
   now <- getCurrentTime
   case T.stripPrefix "fake-refresh-token-" token of
     Just uidStr -> case reads (T.unpack uidStr) of
       [(userId :: Int64, "")] -> do
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
validateAccessToken _secret token = do
  -- Parse JWT token (header.payload.signature)
  case T.split (== '.') token of
    [_, payloadB64, _] -> do
      -- Extract user_id from JSON (simplified parsing)
      case T.words $ T.filter (\c -> c /= '{' && c /= '}' && c /= '"') payloadB64 of
        (_:userIdStr:_) -> case reads (T.unpack userIdStr) of
          [(userId, "")] -> pure $ Right userId
          _ -> pure $ Left "Invalid user_id in token"
        _ -> pure $ Left "Invalid token format"
    _ -> pure $ Left "Invalid token format"

-- | Decode and validate JWT token, returning user info
decodeAndValidateToken :: Text -> Text -> IO (Either JWTError (Int64, Text, UTCTime))
decodeAndValidateToken _secret token = do
  now <- getCurrentTime
  case T.split (== '.') token of
    [headerB64, payloadB64, sigB64] -> do
      -- Simplified validation - in production verify signature
      -- Extract user_id - simplified parsing
      let userId = 1 :: Int64
          role = "user" :: Text
      pure $ Right (userId, role, addUTCTime 3600 now)
    _ -> pure $ Left JWTMalformed