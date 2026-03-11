-- | Widget module - Dashboard widgets
module Core.Widget where

import           Data.Int  (Int64)
import           Data.Text (Text)

-- | Widget - Dashboard widget
data Widget = Widget
  { wgtId       :: Int64
  , wgtName     :: Text
  , wgtType     :: WidgetType
  , wgtConfig   :: Text  -- JSON
  , wgtPosition :: Text  -- JSON {x,y,w,h}
  } deriving (Show, Eq)

data WidgetType = WT_Chart | WT_Table | WT_Stat | WT_Map | WT_Calendar
  deriving (Show, Eq)

-- | WidgetDataSource - Widget data source
data WidgetDataSource = WidgetDataSource
  { wdsId         :: Int64
  , wdsWidgetId   :: Int64
  , wdsQuery      :: Text
  , wdsRefreshSec :: Int
  } deriving (Show, Eq)
