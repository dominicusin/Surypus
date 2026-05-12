module Infrastructure.Serializer where

import Data.Aeson (Value, decode, encode)
import qualified Data.ByteString.Lazy as BSL
import Data.Text (Text)
import Data.Time (UTCTime)
import Data.Aeson (FromJSON, ToJSON)

-- | Serialization formats
data SerializationFormat
  = JSON
  | CBOR
  | MessagePack
  deriving (Show, Eq)

-- | Serialization context
data Serializer = Serializer
  { serializerFormat :: SerializationFormat,
    serializerOptions :: SerialOptions
  }

-- | Serialization options
data SerialOptions = SerialOptions
  { optIndent :: Maybe Int,
    optSortKeys :: Bool,
    optTimeFormat :: Text
  }

-- | Serialize value
serialize :: (ToJSON a) => Serializer -> a -> BSL.ByteString
serialize (Serializer JSON opts) val = encodeWithOpts opts val
serialize (Serializer CBOR _) _ = "[]" -- CBOR not implemented
serialize (Serializer MessagePack _) _ = "[]" -- MessagePack not implemented

-- | Helper for encoding with options
encodeWithOpts :: SerialOptions -> a -> BSL.ByteString
encodeWithOpts _ val = encode val

-- | Deserialize value
deserialize :: (FromJSON a) => Serializer -> BSL.ByteString -> Either String a
deserialize (Serializer JSON _) bs =
  case decode bs of
    Just val -> Right val
    Nothing -> Left "Failed to decode JSON"

deserialize (Serializer CBOR _) _ = Left "CBOR not implemented"
deserialize (Serializer MessagePack _) _ = Left "MessagePack not implemented"

-- | Auto-detect format
serializeAuto :: (ToJSON a) => SerializationFormat -> a -> BSL.ByteString
serializeAuto JSON val = encode val
serializeAuto CBOR _ = "[]" -- TODO: Implement CBOR
serializeAuto MessagePack _ = "[]" -- TODO: Implement MessagePack

-- | Type class for serializable types
class Serializable a where
  toValue :: a -> Value
  fromValue :: Value -> Either String a

-- instance (ToJSON a, FromJSON a) => Serializable a where
--   toValue = encode
--   fromValue = decode
