{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}

module Surypus.API.Reports
  ( Report(..)
  , generateReport
  , getPnLReport
  , getInventoryReport
  ) where

import Data.Text (Text)
import qualified Data.Text as T
import Data.Aeson (ToJSON)
import GHC.Generics (Generic)
import DAL.Database (Pool)
import DAL.Types (QueryResult(..))

data Report = Report
  { rptName :: !Text, rptData :: !Text
  } deriving (Show, Eq, Generic)
instance ToJSON Report

generateReport :: Pool -> Text -> IO (QueryResult Report)
generateReport _ _ = return $ QuerySuccess (Report "stub" "{}")

getPnLReport :: Pool -> IO (QueryResult Report)
getPnLReport _ = return $ QuerySuccess (Report "pnl-stub" "{}")

getInventoryReport :: Pool -> IO (QueryResult Report)
getInventoryReport _ = return $ QuerySuccess (Report "inventory-stub" "{}")
