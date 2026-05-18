{-# LANGUAGE OverloadedStrings #-}

module Surypus.API.Reports
  ( Report(..)
  , generateReport
  ) where

import Data.Text (Text)
import qualified Data.Text as T
import Data.Aeson (ToJSON)
import GHC.Generics (Generic)
import DAL.Database (Pool)
import Surypus.CoreTypes (QueryResult(..))

data Report = Report
  { rptName :: !Text, rptData :: !Text
  } deriving (Show, Eq, Generic)
instance ToJSON Report

generateReport :: Pool -> Text -> IO (QueryResult Report)
generateReport _ _ = return $ QuerySuccess (Report "stub" "{}")
