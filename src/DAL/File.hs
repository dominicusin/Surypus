-- | File module - Files
module DAL.File  where

import Data.Int (Int64)

-- | File - File
data File = File
  { fId :: Int64,
    fName :: String,
    fPath :: String,
    fSize :: Int64,
    fMimeType :: String
  }
  deriving (Show, Eq)

-- | Get extension
getExtension :: File -> String
getExtension f = reverse (take 3 (reverse (fName f)))
