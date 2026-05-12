module Infrastructure.Encryption where

import Data.ByteString (ByteString)
import qualified Data.ByteString as BS
import Data.Word (Word8)

-- | Encryption configuration
data EncryptionConfig = EncryptionConfig
  { encKey :: ByteString,
    encIv :: ByteString,
    encAlgorithm :: String
  }

-- | Initialize encryption (simplified - no crypto dependencies)
initEncryption :: IO EncryptionConfig
initEncryption = do
  -- Simplified: use dummy keys for now
  let key = BS.replicate 32 0x00
      iv = BS.replicate 16 0x00
  return $
    EncryptionConfig
      { encKey = key,
        encIv = iv,
        encAlgorithm = "AES-256-CBC"
      }

-- | Encrypt data (stub)
encrypt :: EncryptionConfig -> ByteString -> IO (Either String ByteString)
encrypt config plaintext = do
  -- Simplified: just return plaintext for now
  return $ Right plaintext

-- | Decrypt data (stub)
decrypt :: EncryptionConfig -> ByteString -> IO (Either String ByteString)
decrypt config ciphertext = do
  -- Simplified: just return ciphertext for now
  return $ Right ciphertext

-- | Hash password (stub)
hashPassword :: String -> IO String
hashPassword password = do
  -- Simplified: just return password as-is for now
  return password

-- | Verify password (stub)
verifyPassword :: String -> String -> Bool
verifyPassword password hash = password == hash
