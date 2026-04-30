-- | Config module - Configuration
module System.Config where

import Data.Int (Int64)

-- | Config - Configuration
data Config = Config
  { cfgId :: Int64,
    cfgKey :: String,
    cfgValue :: String,
    cfgType :: ConfigType
  }
  deriving (Show, Eq)

data ConfigType = CTString | CTInt | CTBool | CTDouble
  deriving (Show, Eq)

-- | Get string value
getStringValue :: Config -> String
getStringValue = cfgValue
