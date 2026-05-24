{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE DeriveGeneric #-}

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
import qualified Opaleye as OE
import qualified Opaleye.Internal.HaskellDB.PrimQuery as OPQ
import qualified Opaleye.Internal.PGTypes as OPG
import qualified Opaleye.Internal.Tag as OITag
import DAL.Database (Pool, runQuery, runCommand)
import DAL.Types (QueryResult(..))

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
   let query = OE.sql 
         "SELECT \
         \  COALESCE((SELECT SUM(total_amount) FROM bills WHERE status = 'POSTED'), 0), \
         \  COALESCE((SELECT COUNT(*) FROM bills), 0), \
         \  COALESCE((SELECT COUNT(*) FROM goods WHERE is_active), 0), \
         \  COALESCE((SELECT COUNT(*) FROM persons), 0)"
         (OE.makeColumns (,,,) 
            OE.double
            OE.int8
            OE.int8
            OE.int8
         ) OE.noParams
   result <- runQuery pool query
   case result of
     Left err -> return $ QueryError (T.pack $ show err)
     Right cols -> return $ QuerySuccess $ map (\(revenue, orders, activeGoods, partners) ->
        DashboardKPI revenue (fromIntegral orders) (fromIntegral activeGoods) (fromIntegral partners)) cols

getRevenueTrend :: Pool -> IO (QueryResult [RevenuePoint])
getRevenueTrend pool = do
   let query = OE.sql 
         "SELECT \
         \  TO_CHAR(bill_date, 'YYYY-MM'), \
         \  SUM(total_amount), \
         \  COUNT(*) \
         \FROM bills \
         \WHERE bill_date >= NOW() - INTERVAL '12 months' \
         \GROUP BY TO_CHAR(bill_date, 'YYYY-MM') \
         \ORDER BY 1"
         (OE.makeColumns (,,) 
            OE.text
            OE.double
            OE.int8
         ) OE.noParams
   result <- runQuery pool query
   case result of
     Left err -> return $ QueryError (T.pack $ show err)
     Right cols -> return $ QuerySuccess $ map (\(month, revenue, count) ->
        RevenuePoint month revenue (fromIntegral count)) cols

getOrderStatuses :: Pool -> IO (QueryResult [OrderStatus])
getOrderStatuses pool = do
   let query = OE.sql 
         "SELECT status, COUNT(*), SUM(total_amount) \
         \FROM bills GROUP BY status"
         (OE.makeColumns (,,) 
            OE.text
            OE.int8
            OE.double
         ) OE.noParams
   result <- runQuery pool query
   case result of
     Left err -> return $ QueryError (T.pack $ show err)
     Right cols -> return $ QuerySuccess $ map (\(status, count, total) ->
        OrderStatus status (fromIntegral count) total) cols

getStockSummary :: Pool -> IO (QueryResult StockSummary)
getStockSummary pool = do
   let query = OE.sql 
         "SELECT COUNT(*), SUM(CASE WHEN is_active THEN 1 ELSE 0 END), \
         \  COUNT(DISTINCT category_id) \
         \FROM goods"
         (OE.makeColumns (,,) 
            OE.int8
            OE.int8
            OE.int8
         ) OE.noParams
   result <- runQuery pool query
   case result of
     Left err -> return $ QueryError (T.pack $ show err)
     Right cols -> return $ QuerySuccess $ map (\(totalGoods, activeGoods, categories) ->
        StockSummary (fromIntegral totalGoods) (fromIntegral activeGoods) (fromIntegral categories)) cols
