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

data AlertType = ATWarning | ATError | ATInfo | ATSuccess
  deriving (Show, Eq)

-- | Mark as read
markRead :: Alert -> Alert
markRead a = a { alrRead = True }
