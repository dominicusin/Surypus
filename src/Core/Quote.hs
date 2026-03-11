-- | Quote module - Quotes
module Core.Quote where

import           Data.Int  (Int64)
import           Data.Text (Text)
import           Data.Time (Day)

-- | Quote - Sales quote
data Quote = Quote
  { qteId         :: Int64
  , qteCode       :: Text
  , qteDate       :: Day
  , qteValidUntil :: Day
  , qteCustomerId :: Int64
  , qteTotal      :: Double
  , qteStatus     :: QuoteStatus
  } deriving (Show, Eq)

data QuoteStatus = QS_Draft | QS_Sent | QS_Accepted | QS_Rejected | QS_Expired
  deriving (Show, Eq)

-- | Is quote expired
isQuoteExpired :: Quote -> Day -> Bool
isQuoteExpired q today = today > qteValidUntil q
