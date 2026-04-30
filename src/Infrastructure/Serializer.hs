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
serialize (Serializer JSON _) = encode
serialize (Serializer CBOR _) = error "CBOR not implemented"
serialize (Serializer MessagePack _) = error "MessagePack not implemented"

-- | Deserialize value
deserialize :: (FromJSON a) => Serializer -> BSL.ByteString -> Either String a
deserialize (Serializer JSON _) = decode

-- | Auto-detect format
serializeAuto :: (ToJSON a) => SerializationFormat -> a -> BSL.ByteString
serializeAuto fmt val =
  case fmt of
    JSON -> encode val
    CBOR -> error "CBOR not implemented"
    MessagePack -> error "MessagePack not implemented"

-- | Type class for serializable types
class Serializable a where
  toValue :: a -> Value
  fromValue :: Value -> Either String a

instance (ToJSON a, FromJSON a) => Serializable a where
  toValue = encode
  fromValue = decode
