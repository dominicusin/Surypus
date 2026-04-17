-- | Chart module - Charts and graphs
module Core.Chart where

import Data.Int (Int64)
import Data.Text (Text)

-- | Chart - Chart template
data Chart = Chart
  { chId :: Int64,
    chName :: Text,
    chType :: ChartType,
    chDataSource :: Text,
    chConfig :: Text -- JSON
  }
  deriving (Show, Eq)

data ChartType = CTLine | CTBar | CTPie | CTScatter | CTGauge
  deriving (Show, Eq)

-- | Dashboard - Dashboard configuration
data Dashboard = Dashboard
  { dbId :: Int64,
    dbName :: Text,
    dbOwnerId :: Int64,
    dbLayout :: Text -- JSON grid layout
  }
  deriving (Show, Eq)
