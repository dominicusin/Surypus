-- | Terminal module - POS Terminals
module Core.Terminal where

import           Data.Int  (Int64)
import           Data.Text (Text)

-- | Terminal - POS Terminal
data Terminal = Terminal
  { trmId         :: Int64
  , trmCode       :: Text
  , trmLocationId :: Int64
  , trmStatus     :: TerminalStatus
  } deriving (Show, Eq)

data TerminalStatus = TS_Online | TS_Offline | TS_Error
  deriving (Show, Eq)

-- | Is terminal active
isTerminalActive :: Terminal -> Bool
isTerminalActive t = trmStatus t == TS_Online
