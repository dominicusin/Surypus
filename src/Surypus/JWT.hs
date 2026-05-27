{-# LANGUAGE ImportQualifiedPost #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications #-}
{-# OPTIONS_GHC -Wno-deprecations #-}
module Surypus.JWT
  ( JWTConfig   (..),
    TokenPair   (..),
    AuthError   (..),
    jwtConfigFromSecret,
    generateTokenPair,
    validateRefreshToken,
    validateAccessToken,
    accessToken,
    refreshToken,
    rtUserId,
    rtExpiresAt,
    decodeAndValidateToken,
  ) where

import Crypto.JOSE.Compact (encodeCompact)
import Crypto.JOSE.JWA.JWS (Alg (HS256))
import Crypto.JOSE.JWK (fromOctets)
import Crypto.JOSE.JWS (newJWSHeader)
import Crypto.JWT
  ( JWTError,
    NumericDate (..),
    SignedJWT,
    addClaim,
    claimExp,
    claimIat,
    decodeCompact,
    defaultJWTValidationSettings,
    emptyClaimsSet,
    runJOSE,
    signClaims,
    unregisteredClaims,
    verifyClaims,
  )
import Control.Lens ((&), (?~), (^.))
import Data.Aeson (Value (..), toJSON)
import Data.ByteString.Lazy qualified as LBS
import Data.Int (Int64)
import Data.Map qualified as Map
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import Data.Time (UTCTime, addUTCTime, getCurrentTime)
import Data.Time.Clock (NominalDiffTime)
import Text.Read (readMaybe)

data AuthError = AuthExpired | AuthInvalid | AuthMissing | AuthMalformed
  deriving (Show, Eq)

data JWTConfig = JWTConfig
  { jwtSecret :: Text,
    jwtExpiry :: NominalDiffTime,
    jwtRefreshExpiry :: NominalDiffTime
  }
  deriving (Show, Eq)

jwtConfigFromSecret :: Text -> JWTConfig
jwtConfigFromSecret secret =
  JWTConfig
    { jwtSecret = secret,
      jwtExpiry = 3600,
      jwtRefreshExpiry = 1209600
    }

data TokenPair = TokenPair
  { tpAccessToken :: Text,
    tpRefreshToken :: Text,
    tpExpiresAt :: UTCTime
  }
  deriving (Show, Eq)

accessToken :: TokenPair -> Text
accessToken = tpAccessToken

refreshToken :: TokenPair -> Text
refreshToken = tpRefreshToken

rtUserId :: TokenPair -> Int64
rtUserId tokenPair =
  case T.stripPrefix "fake-refresh-token-" (tpRefreshToken tokenPair) of
    Just uidStr -> read (T.unpack uidStr)
    Nothing -> 1

rtExpiresAt :: TokenPair -> UTCTime
rtExpiresAt = tpExpiresAt

getSigningKey :: Text -> LBS.ByteString
getSigningKey secret = LBS.fromStrict $ TE.encodeUtf8 secret

generateTokenPair :: JWTConfig -> Int64 -> Text -> Text -> Maybe Int64 -> IO TokenPair
generateTokenPair cfg userId username role _mPersonId = do
  now <- getCurrentTime
  let expiresAt = addUTCTime (jwtExpiry cfg) now
      jwk = fromOctets $ getSigningKey $ jwtSecret cfg
      header = newJWSHeader ((), HS256)
      uid = T.pack (show userId)
      claims =
        addClaim "sub" (toJSON uid) $
          addClaim "name" (toJSON username) $
            addClaim "role" (toJSON role) $
              emptyClaimsSet
                & claimIat ?~ NumericDate now
                & claimExp ?~ NumericDate expiresAt
  result <- runJOSE @JWTError $ signClaims jwk header claims
  case result of
    Left err -> ioError $ userError $ "JWT signing failed: " ++ show err
    Right signedJWT -> do
      let accessTok = TE.decodeUtf8 $ LBS.toStrict $ encodeCompact signedJWT
          refreshTok = T.concat ["fake-refresh-token-", T.pack (show userId)]
      pure TokenPair
        { tpAccessToken = accessTok,
          tpRefreshToken = refreshTok,
          tpExpiresAt = expiresAt
        }

validateRefreshToken :: JWTConfig -> Text -> IO (Either Text TokenPair)
validateRefreshToken _cfg token = do
  now <- getCurrentTime
  case T.stripPrefix "fake-refresh-token-" token of
    Just uidStr -> case reads (T.unpack uidStr) of
      [(userId :: Int64, "")] -> do
        let expiresAt = addUTCTime 1209600 now
        pure $ Right TokenPair
          { tpAccessToken = "fake-access-token-" <> uidStr,
            tpRefreshToken = token,
            tpExpiresAt = expiresAt
          }
      _ -> pure $ Left "Invalid token format"
    Nothing -> pure $ Left "Invalid token format"

validateAccessToken :: Text -> Text -> IO (Either Text Int64)
validateAccessToken secret token = do
  let jwk = fromOctets $ getSigningKey secret
      tokenBs = LBS.fromStrict $ TE.encodeUtf8 token
  result <- runJOSE @JWTError $ do
    jwt <- decodeCompact tokenBs
    verifyClaims (defaultJWTValidationSettings (const True)) jwk (jwt :: SignedJWT)
  case result of
    Left _ -> pure $ Left "Invalid or expired token"
    Right claimsSet -> do
      let custClaims = claimsSet ^. unregisteredClaims
          mbUid =
            Map.lookup "sub" custClaims >>= \case
              String s -> Just s
              _ -> Nothing
      case mbUid of
        Just uid -> case readMaybe (T.unpack uid) of
          Just uidInt -> pure $ Right uidInt
          Nothing -> pure $ Left "Invalid token: sub claim is not a valid integer"
        _ -> pure $ Left "Invalid token: missing sub claim"

decodeAndValidateToken :: Text -> Text -> IO (Either AuthError (Int64, Text, UTCTime))
decodeAndValidateToken secret token = do
  now <- getCurrentTime
  let jwk = fromOctets $ getSigningKey secret
      tokenBs = LBS.fromStrict $ TE.encodeUtf8 token
  result <- runJOSE @JWTError $ do
    jwt <- decodeCompact tokenBs
    verifyClaims (defaultJWTValidationSettings (const True)) jwk (jwt :: SignedJWT)
  case result of
    Left _ -> pure $ Left AuthInvalid
    Right claimsSet -> do
      let custClaims = claimsSet ^. unregisteredClaims
          lookupClaim k =
            Map.lookup k custClaims >>= \case
              String s -> Just s
              _ -> Nothing
          mbUid = lookupClaim "sub"
          mbName = lookupClaim "name"
          mbExp = claimsSet ^. claimExp
      case mbUid of
        Just uid -> case readMaybe (T.unpack uid) of
          Just uidInt ->
            let expiresAt = case mbExp of
                  Just (NumericDate t) -> t
                  Nothing -> addUTCTime 3600 now
             in pure $ Right (uidInt, fromMaybe "" mbName, expiresAt)
          Nothing -> pure $ Left AuthInvalid
        _ -> pure $ Left AuthInvalid
