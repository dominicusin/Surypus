-- | Route module - Delivery routes
module Core.Route where

import           Data.Int  (Int64)
import           Data.Time (Day)

-- | Route - Delivery route
data Route = Route
  { rtId        :: Int64
  , rtCode      :: String
  , rtDate      :: Day
  , rtDriverId  :: Int64
  , rtVehicleId :: Int64
  , rtStatus    :: RouteStatus
  } deriving (Show, Eq)

data RouteStatus = RSDraft | RSInProgress | RS_Completed
  deriving (Show, Eq)

-- | Is active
isRouteActive :: Route -> Bool
isRouteActive r = rtStatus r == RSInProgress
