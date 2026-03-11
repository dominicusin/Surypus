-- | EDI module - Electronic data interchange
module Core.EDI where

import           Data.Int  (Int64)
import           Data.Text (Text)
import           Data.Time (Day)

-- | EDIExchange - EDI exchange
data EDIExchange = EDIExchange
  { ediId         :: Int64
  , ediProviderId :: Int64
  , ediType       :: EDIType
  , ediDirection  :: EDIDirection
  , ediStatus     :: EDIStatus
  , ediDate       :: Day
  , ediDocId      :: Int64
  } deriving (Show, Eq)

data EDIType = EDI_Order | EDI_Invoice | EDI_Desadv | EDI_Recadv
  deriving (Show, Eq)

data EDIDirection = EDID_Incoming | EDID_Outgoing
  deriving (Show, Eq)

data EDIStatus = EDIS_Pending | EDIS_Sent | EDIS_Received | EDIS_Accepted | EDIS_Rejected
  deriving (Show, Eq)
