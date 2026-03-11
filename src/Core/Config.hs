-- | Config module - Configuration
module Core.Config where

import           Data.Int (Int64)

-- | Config - Configuration
data Config = Config
  { cfgId    :: Int64
  , cfgKey   :: String
  , cfgValue :: String
  , cfgType  :: ConfigType
  } deriving (Show, Eq)

data ConfigType = CT_String | CT_Int | CT_Bool | CT_Double
  deriving (Show, Eq)

-- | Get string value
getStringValue :: Config -> String
getStringValue c = cfgValue c
