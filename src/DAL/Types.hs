-- | DAL.Types module
module DAL.Types where

import Data.Aeson (FromJSON, ToJSON)
import GHC.Generics (Generic)

-- | Dashboard statistics
data DashboardStats = DashboardStats
  { dsBills :: Int,
    dsOrders :: Int,
    dsGoods :: Int,
    dsPersons :: Int
  }
  deriving (Show, Eq, Generic)

instance ToJSON DashboardStats
instance FromJSON DashboardStats
