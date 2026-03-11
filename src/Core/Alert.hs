-- | Alert module - Alerts
module Core.Alert where

import           Data.Int  (Int64)
import           Data.Time (Day)

-- | Alert - Alert
data Alert = Alert
  { alrId      :: Int64
  , alrType    :: AlertType
  , alrMessage :: String
  , alrDate    :: Day
  , alrRead    :: Bool
  } deriving (Show, Eq)

data AlertType = AT_Warning | AT_Error | AT_Info | AT_Success
  deriving (Show, Eq)

-- | Mark as read
markRead :: Alert -> Alert
markRead a = a { alrRead = True }
