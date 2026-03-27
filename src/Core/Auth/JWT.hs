{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

-- | JWT helpers for authentication
module Core.Auth.JWT
  ( JWTConfig (..),
    TokenClaims (..),
    createToken,
    verifyToken,
  )
where

import Crypto.Hash.Algorithms (SHA256)
import Crypto.MAC.HMAC (HMAC, hmac, hmacGetDigest)
import Data.Aeson (FromJSON, ToJSON, Value, eitherDecodeStrict', encode, object, parseJSON, toJSON, (.=))
import Data.Aeson.Types (defaultOptions, fieldLabelModifier, genericParseJSON, genericToJSON)
import Data.Bifunctor (first)
import Data.ByteArray (convert)
import Data.ByteString (ByteString)
import qualified Data.ByteString as BS
import qualified Data.ByteString.Base64.URL as B64
import qualified Data.ByteString.Lazy as LBS
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import Data.Time.Clock.POSIX (getPOSIXTime)
import GHC.Generics (Generic)

-- | JWT configuration
data JWTConfig = JWTConfig
  { jwtSecret :: ByteString,
    jwtIssuer :: Text,
    -- | seconds
    jwtTTL :: Int
  }

-- | Token payload
data TokenClaims = TokenClaims
  { tcUserId :: Int64,
    tcRole :: Text,
    tcIssuedAt :: Int64,
    tcExpiresAt :: Int64,
    tcIssuer :: Text
  }
  deriving (Eq, Show, Generic)

instance ToJSON TokenClaims where
  toJSON = genericToJSON defaultOptions {fieldLabelModifier = drop 2}

instance FromJSON TokenClaims where
  parseJSON = genericParseJSON defaultOptions {fieldLabelModifier = drop 2}

-- | Build a token for a given user
createToken :: JWTConfig -> Int64 -> Text -> IO Text
createToken cfg uid role = do
  now <- round <$> getPOSIXTime
  let expires = now + fromIntegral (jwtTTL cfg)
      claims =
        TokenClaims
          { tcUserId = uid,
            tcRole = role,
            tcIssuedAt = now,
            tcExpiresAt = expires,
            tcIssuer = jwtIssuer cfg
          }
  pure $ signToken cfg claims

signToken :: JWTConfig -> TokenClaims -> Text
signToken cfg claims =
  let headerSeg = encodeSegment objectHeader
      payloadSeg = encodeSegment (toJSON claims)
      signedInput = BS.intercalate "." [headerSeg, payloadSeg]
      sig = makeSignature (jwtSecret cfg) signedInput
   in TE.decodeUtf8 $ BS.intercalate "." [headerSeg, payloadSeg, sig]

objectHeader :: Value
objectHeader = object ["alg" .= ("HS256" :: Text), "typ" .= ("JWT" :: Text)]

encodeSegment :: Value -> ByteString
encodeSegment = B64.encode . LBS.toStrict . encode

makeSignature :: ByteString -> ByteString -> ByteString
makeSignature secret payload =
  let digest = hmac secret payload :: HMAC SHA256
   in B64.encodeUnpadded (convert (hmacGetDigest digest))

-- | Verify token and load claims
verifyToken :: JWTConfig -> Text -> IO (Either Text TokenClaims)
verifyToken cfg token =
  case T.splitOn "." token of
    [hdr, payload, sig] -> do
      let signedInput = TE.encodeUtf8 hdr <> "." <> TE.encodeUtf8 payload
      case (decodeSegment hdr, decodeSegment payload, decodeSegment sig) of
        (Right _, Right payloadBytes, Right sigBytes)
          | guardSignature (jwtSecret cfg) signedInput sigBytes -> do
              let parsed = first T.pack (eitherDecodeStrict' payloadBytes)
              now <- round <$> getPOSIXTime
              pure $
                parsed >>= \tc ->
                  if tcExpiresAt tc < now
                    then Left "token expired"
                    else
                      if tcIssuer tc /= jwtIssuer cfg
                        then Left "invalid issuer"
                        else Right tc
          | otherwise -> pure $ Left "invalid signature"
        (Left err, _, _) -> pure $ Left err
        (_, Left err, _) -> pure $ Left err
        (_, _, Left err) -> pure $ Left err
    _ -> pure $ Left "invalid token format"

decodeSegment :: Text -> Either Text ByteString
decodeSegment txt = first T.pack (B64.decode (TE.encodeUtf8 txt))

guardSignature :: ByteString -> ByteString -> ByteString -> Bool
guardSignature secret payload sig = makeSignature secret payload == sig
