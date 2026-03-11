-- | Log module - System logging
module Core.Log where

import           Data.Int  (Int64)
import           Data.Text (Text)
import           Data.Time (UTCTime)

-- | LogEntry - Log entry
data LogEntry = LogEntry
  { leId        :: Int64
  , leLevel     :: LogLevel
  , leModule    :: Text
  , leMessage   :: Text
  , leTimestamp :: UTCTime
  , leUserId    :: Maybe Int64
  } deriving (Show, Eq)

data LogLevel = LL_Debug | LL_Info | LL_Warning | LL_Error | LL_Critical
  deriving (Show, Eq)

-- | LogConfig - Logging configuration
data LogConfig = LogConfig
  { lcLevel  :: LogLevel
  , lcOutput :: LogOutput
  , lcFormat :: Text
  } deriving (Show, Eq)

data LogOutput = LO_Console | LO_File | LO_Database | LO_Syslog
  deriving (Show, Eq)
