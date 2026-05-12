module Infrastructure.Serializer where
 
import Data.Aeson (Value, decode, encode)
import qualified Data.ByteString.Lazy as BSL
import Data.Text (Text)
import Data.Time (UTCTime)
import Data.Aeson (FromJSON, ToJSON)
import qualified Codec.CBOR as CBOR
import qualified Data.MessagePack as MP
 
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
serialize (Serializer CBOR _) val = CBOR.encode val
serialize (Serializer MessagePack _) val = MP.encode val
 
-- | Helper for encoding with options
encodeWithOpts :: SerialOptions -> a -> BSL.ByteString
encodeWithOpts opts val =
   let json = encode val
   in  case (optIndent opts, optSortKeys opts) of
        (Just indent, True)  -> decodeUtf8' (encodePretty' (defConfig {confIndent = indent, confSortKeys = True}) val)
        (Just indent, False) -> decodeUtf8' (encodePretty' (defConfig {confIndent = indent}) val)
        (Nothing, True)      -> decodeUtf8' (encodePretty' (defConfig {confSortKeys = True}) val)
        (Nothing, False)     -> json
   where
   decodeUtf8' = either (const json) id . decodeUtf8'
 
-- | Deserialize value
deserialize :: (FromJSON a) => Serializer -> BSL.ByteString -> Either String a
deserialize (Serializer JSON _) bs =
   case decode bs of
     Just val -> Right val
     Nothing -> Left "Failed to decode JSON"
 
deserialize (Serializer CBOR _) bs =
   case CBOR.decode bs of
     Left _  -> Left "Failed to decode CBOR"
     Right val -> Right val
 
deserialize (Serializer MessagePack _) bs =
   case MP.decode bs of
     Left _  -> Left "Failed to decode MessagePack"
     Right val -> Right val
 
-- | Auto-detect format
serializeAuto :: (ToJSON a) => SerializationFormat -> a -> BSL.ByteString
serializeAuto JSON val = encode val
serializeAuto CBOR val = CBOR.encode val
serializeAuto MessagePack val = MP.encode val
 
-- | Type class for serializable types
class Serializable a where
   toValue :: a -> Value
   fromValue :: Value -> Either String a
 
instance (ToJSON a, FromJSON a) => Serializable a where
   toValue = encode
   fromValue = decode
