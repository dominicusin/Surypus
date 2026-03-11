-- | ExtCode module - External codes
module Core.ExtCode where

import           Data.Int (Int64)

-- | ExtCode - External system code
data ExtCode = ExtCode
  { ecId         :: Int64
  , ecObjectType :: Int64
  , ecObjectId   :: Int64
  , ecSystem     :: String
  , ecCode       :: String
  } deriving (Show, Eq)

-- | Get code
getCode :: ExtCode -> String
getCode ec = ecCode ec
