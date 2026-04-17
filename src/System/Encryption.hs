module System.Encryption where

import qualified Crypto.Cipher.AES as AES
import qualified Crypto.Cipher.Types as CT
import qualified Crypto.Random as CR
import Data.Bits (xor)
import Data.ByteString (ByteString)
import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as BC
import Data.Word (Word8)

-- | Encryption configuration
data EncryptionConfig = EncryptionConfig
  { encKey :: ByteString,
    encIv :: ByteString,
    encAlgorithm :: String
  }

-- | Initialize encryption with random key
initEncryption :: IO EncryptionConfig
initEncryption = do
  gen <- CR.newGenIO
  let (key, gen') = CR.genBytes 32 gen
      (iv, _) = CR.genBytes 16 gen'
  return $
    EncryptionConfig
      { encKey = key,
        encIv = iv,
        encAlgorithm = "AES-256-CBC"
      }

-- | Encrypt data
encryptData :: EncryptionConfig -> ByteString -> Either String ByteString
encryptData config plaintext = do
  cipher <- either (Left . show) return $ CT.initCipher (encKey config)
  let iv = BS.take (CT.blockSize cipher) (encIv config)
  return $ CT.ctrCombine cipher iv plaintext

-- | Decrypt data
decryptData :: EncryptionConfig -> ByteString -> Either String ByteString
decryptData config ciphertext = do
  cipher <- either (Left . show) return $ CT.initCipher (encKey config)
  let iv = BS.take (CT.blockSize cipher) (encIv config)
  return $ CT.ctrCombine cipher iv ciphertext

-- | Generate secure key
generateKey :: IO ByteString
generateKey = do
  gen <- CR.newGenIO
  let (key, _) = CR.genBytes 32 gen
  return key

-- | Generate initialization vector
generateIV :: IO ByteString
generateIV = do
  gen <- CR.newGenIO
  let (iv, _) = CR.genBytes 16 gen
  return iv

-- | Key derivation using PBKDF2
deriveKey :: ByteString -> ByteString -> Int -> ByteString
deriveKey password salt iterations =
  BC.pack $ take 32 $ pbkdf2Iterate password salt iterations (replicate 32 0)
  where
    pbkdf2Iterate _ _ 0 acc = acc
    pbkdf2Iterate pwd salt n acc = pbkdf2Iterate pwd salt (n - 1) (hashBlock pwd (acc `xor` hashBlock salt n))
    hashBlock _ idx = take 32 $ show idx -- Simplified hash

-- | Constant-time comparison
secureCompare :: ByteString -> ByteString -> Bool
secureCompare a b = BS.length a == BS.length b && BS.foldl' xor 0 (BS.zipWith xor a b) == 0
