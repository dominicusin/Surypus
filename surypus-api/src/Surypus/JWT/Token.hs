{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE ImportQualifiedPost #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE TypeApplications #-}

-- | JWT token generation and verification using jose-0.10
-- Provides cryptographically signed JWTs using HS256 (HMAC-SHA256)
module Surypus.JWT.Token
  ( generateToken
  , verifyToken
  , UserClaims (..)
  ) where

import Crypto.JOSE.Compact (encodeCompact)
import Crypto.JOSE.JWA.JWS (Alg (..))
import Crypto.JOSE.JWS (newJWSHeader)
import Crypto.JOSE.JWK (fromOctets)
import Crypto.JWT
       ( runJOSE,
         signClaims,
         verifyClaims,
         emptyClaimsSet,
         addClaim,
         claimIat,
         claimExp,
         defaultJWTValidationSettings,
         decodeCompact,
         NumericDate (..),
         ClaimsSet,
         SignedJWT,
         JWTValidationSettings,
         unregisteredClaims,
         JWTError,
       )
import Data.Aeson (Value (..), toJSON)
import Data.Int (Int64)
import Data.Map qualified as Map
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import Data.Text qualified as T
import Data.Text.Encoding qualified as TE
import Data.ByteString.Lazy qualified as LBS
import Data.Time.Clock (addUTCTime, getCurrentTime)
import Control.Lens ((&), (?~), (^.))
import System.Environment (lookupEnv)
import Surypus (Pool, User (..))

-- | User claims extracted from a valid JWT
data UserClaims = UserClaims
  { ucUserId :: !Int64
  , ucUsername :: !Text
  , ucRoles :: ![Text]
  }
  deriving (Show, Eq)

-- | Get the JWT signing key from SURYPUS_JWT_SECRET env var or use dev default
getSigningKey :: IO LBS.ByteString
getSigningKey = do
  mbSecret <- lookupEnv "SURYPUS_JWT_SECRET"
  pure $ LBS.fromStrict $ TE.encodeUtf8 $ T.pack $ fromMaybe "dev-secret-change-in-production" mbSecret

-- | Generate a signed JWT token for the given user
-- The Pool parameter is reserved for future use (e.g., token revocation DB checks)
generateToken :: Pool -> User -> IO Text
generateToken _pool user = do
  now <- getCurrentTime
  let uid = T.pack $ show $ userId user
  secret <- getSigningKey
  result <- runJOSE @JWTError $ do
    let jwk = fromOctets secret
        header = newJWSHeader ((), HS256)
        claims =
          addClaim "sub" (toJSON uid) $
            addClaim "name" (toJSON $ userName user) $
              addClaim "role" (toJSON ([] :: [Text])) $
                emptyClaimsSet
                  & claimIat ?~ NumericDate now
                  & claimExp ?~ NumericDate (addUTCTime 3600 now)
    signClaims jwk header claims
  case result of
    Left jwtErr -> pure $ T.pack $ show jwtErr
    Right signedJWT ->
      pure $ TE.decodeUtf8 $ LBS.toStrict $ encodeCompact signedJWT

-- | Verify and decode a JWT token, returning user claims on success
verifyToken :: Text -> IO (Either String UserClaims)
verifyToken tokenStr = do
  let tokenBs = LBS.fromStrict $ TE.encodeUtf8 tokenStr
  secret <- getSigningKey
  result <- runJOSE @JWTError $ do
    let jwk = fromOctets secret
        config = defaultJWTValidationSettings (const True)
    jwt <- decodeCompact tokenBs
    verifyClaims config jwk (jwt :: SignedJWT)
  case result of
    Left jwtErr -> pure $ Left $ show jwtErr
    Right claimsSet -> do
      let custClaims = claimsSet ^. unregisteredClaims
          lookupClaim :: Text -> Maybe Value
          lookupClaim key = Map.lookup key custClaims
          mbUid = lookupClaim "sub" >>= \case
            String s -> Just s
            _ -> Nothing
          mbName = lookupClaim "name" >>= \case
            String s -> Just s
            _ -> Nothing
          mbRole = lookupClaim "role" >>= \case
            String s -> Just $ T.splitOn "," s
            _ -> Nothing
      case mbUid of
        Just uid ->
          pure $
            Right $
              UserClaims
                { ucUserId = read $ T.unpack uid
                , ucUsername = fromMaybe "" mbName
                , ucRoles = fromMaybe [] mbRole
                }
        _ -> pure $ Left "Invalid token: missing or invalid sub claim"
