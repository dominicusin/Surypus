-- | Agent module - Agents
module Core.Agent where

import           Data.Int  (Int64)
import           Data.Text (Text)

-- | Agent - Sales agent
data Agent = Agent
  { agtId         :: Int64
  , agtCode       :: Text
  , agtName       :: Text
  , agtCommission :: Double
  , agtRegion     :: Text
  } deriving (Show, Eq)

-- | Calculate commission
calcCommission :: Agent -> Double -> Double
calcCommission a sales = sales * agtCommission a / 100
