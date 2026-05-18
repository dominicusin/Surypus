{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE OverloadedStrings #-}

module Surypus.API.Dashboard
  ( DashboardKPI(..)
  , RevenuePoint(..)
  , OrderStatus(..)
  , StockSummary(..)
  , PartnerSummary(..)
  , getDashboardKPI
  , getRevenueTrend
  , getOrderStatuses
  , getStockSummary
  ) where

import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Aeson (ToJSON, FromJSON, genericToJSON, genericParseJSON, defaultOptions, fieldLabelModifier)
import GHC.Generics (Generic)
import Control.Exception (try, SomeException)
import qualified Hasql.Session as Session
import qualified Hasql.Statement as Statement
import qualified Hasql.Decoders as D
import qualified Hasql.Encoders as E
import DAL.Database (Pool, usePool)
import Surypus.CoreTypes (QueryResult(..))

data DashboardKPI = DashboardKPI
  { kpiRevenue :: !Double
  , kpiOrders :: !Int64
  , kpiActiveGoods :: !Int64
  , kpiPartners :: !Int64
  } deriving (Show, Eq, Generic)

instance ToJSON DashboardKPI

data RevenuePoint = RevenuePoint
  { rpMonth :: !Text
  , rpRevenue :: !Double
  , rpCount :: !Int64
  } deriving (Show, Eq, Generic)

instance ToJSON RevenuePoint

data OrderStatus = OrderStatus
  { osStatus :: !Text
  , osCount :: !Int64
  , osTotal :: !Double
  } deriving (Show, Eq, Generic)

instance ToJSON OrderStatus

data StockSummary = StockSummary
  { ssTotalGoods :: !Int64
  , ssActiveGoods :: !Int64
  , ssCategories :: !Int64
  } deriving (Show, Eq, Generic)

instance ToJSON StockSummary

data PartnerSummary = PartnerSummary
  { psType :: !Text
  , psCount :: !Int64
  , psActive :: !Int64
  } deriving (Show, Eq, Generic)

instance ToJSON PartnerSummary

getDashboardKPI :: Pool -> IO (QueryResult DashboardKPI)
getDashboardKPI pool = do
  let stmt = Statement.Statement
        "SELECT \
        \  COALESCE((SELECT SUM(total_amount) FROM bills WHERE status = 'POSTED'), 0), \
        \  COALESCE((SELECT COUNT(*) FROM bills), 0), \
        \  COALESCE((SELECT COUNT(*) FROM goods WHERE is_active), 0), \
        \  COALESCE((SELECT COUNT(*) FROM persons), 0)"
        ()
        (D.singleRow $ DashboardKPI
          <$> D.column (D.nonNullable D.float8)
          <*> D.column (D.nonNullable D.int8)
          <*> D.column (D.nonNullable D.int8)
          <*> D.column (D.nonNullable D.int8))
        True
  result <- try $ usePool pool $ Session.statement () stmt
  case result of
    Right kpi -> return $ QuerySuccess kpi
    Left (e :: SomeException) -> return $ QueryError (T.pack $ show e)

getRevenueTrend :: Pool -> IO (QueryResult [RevenuePoint])
getRevenueTrend pool = do
  let stmt = Statement.Statement
        "SELECT \
        \  TO_CHAR(bill_date, 'YYYY-MM'), \
        \  SUM(total_amount), \
        \  COUNT(*) \
        \FROM bills \
        \WHERE bill_date >= NOW() - INTERVAL '12 months' \
        \GROUP BY TO_CHAR(bill_date, 'YYYY-MM') \
        \ORDER BY 1"
        ()
        (D.rowList $ RevenuePoint
          <$> D.column (D.nonNullable D.text)
          <*> D.column (D.nonNullable D.float8)
          <*> D.column (D.nonNullable D.int8))
        True
  result <- try $ usePool pool $ Session.statement () stmt
  case result of
    Right points -> return $ QuerySuccess points
    Left (e :: SomeException) -> return $ QueryError (T.pack $ show e)

getOrderStatuses :: Pool -> IO (QueryResult [OrderStatus])
getOrderStatuses pool = do
  let stmt = Statement.Statement
        "SELECT status, COUNT(*), SUM(total_amount) \
        \FROM bills GROUP BY status"
        ()
        (D.rowList $ OrderStatus
          <$> D.column (D.nonNullable D.text)
          <*> D.column (D.nonNullable D.int8)
          <*> D.column (D.nonNullable D.float8))
        True
  result <- try $ usePool pool $ Session.statement () stmt
  case result of
    Right statuses -> return $ QuerySuccess statuses
    Left (e :: SomeException) -> return $ QueryError (T.pack $ show e)

getStockSummary :: Pool -> IO (QueryResult [StockSummary])
getStockSummary pool = do
  let stmt = Statement.Statement
        "SELECT COUNT(*), SUM(CASE WHEN is_active THEN 1 ELSE 0 END), \
        \  COUNT(DISTINCT category_id) \
        \FROM goods"
        ()
        (D.singleRow $ StockSummary
          <$> D.column (D.nonNullable D.int8)
          <$> D.column (D.nonNullable D.int8)
          <$> D.column (D.nonNullable D.int8))
        True
  result <- try $ usePool pool $ Session.statement () stmt
  case result of
    Right summary -> return $ QuerySuccess summary
    Left (e :: SomeException) -> return $ QueryError (T.pack $ show e)
