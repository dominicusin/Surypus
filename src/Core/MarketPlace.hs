-- | MarketPlace module - Online marketplace
module Core.MarketPlace where

import           Data.Int  (Int64)
import           Data.Text (Text)
import           Data.Time (Day)

-- | MarketPlace - Marketplace account
data MarketPlace = MarketPlace
  { mpId     :: Int64
  , mpName   :: Text
  , mpCode   :: Text
  , mpAPIKey :: Text
  , mpSecret :: Text
  , mpStatus :: MarketPlaceStatus
  } deriving (Show, Eq)

data MarketPlaceStatus = MPS_Active | MPS_Inactive | MPS_Error
  deriving (Show, Eq)

-- | MarketOrder - Order from marketplace
data MarketOrder = MarketOrder
  { moId         :: Int64
  , moMarketId   :: Int64
  , moExternalId :: Text
  , moDate       :: Day
  , moStatus     :: MarketOrderStatus
  , moTotal      :: Double
  } deriving (Show, Eq)

data MarketOrderStatus = MOS_New | MOS_Processing | MOS_Shipped | MOS_Delivered | MOS_Cancelled
  deriving (Show, Eq)
