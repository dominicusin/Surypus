{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Surypus.API.Reports (
    Report (..),
    generateReport,
    getPnLReport,
    getInventoryReport,
) where

import Control.Monad.IO.Class (liftIO)
import DAL.Types (QueryResult (..))
import Data.Aeson (ToJSON, object, (.=))
import qualified Data.Aeson as Aeson
import qualified Data.ByteString.Lazy as BL
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Text.Encoding (decodeUtf8)
import Database.Persist.Sql (ConnectionPool, rawSql, runSqlPool, Single (..))
import GHC.Generics (Generic)

data Report = Report
    { rptName :: !Text
    , rptData :: !Text
    }
    deriving (Show, Eq, Generic)

instance ToJSON Report

data PnLRow = PnLRow
    { pnlRevenue :: !Double
    , pnlCogs :: !Double
    , pnlIncome :: !Double
    , pnlExpenses :: !Double
    }
    deriving (Show, Eq, Generic)

instance ToJSON PnLRow

data InvItem = InvItem
    { invName :: !Text
    , invCode :: !Text
    , invQty :: !Double
    , invUnitCost :: !Double
    , invTotalValue :: !Double
    }
    deriving (Show, Eq, Generic)

instance ToJSON InvItem

generateReport :: ConnectionPool -> Text -> IO (QueryResult Report)
generateReport pool reportName = case reportName of
    "pnl" -> getPnLReport pool
    "inventory" -> getInventoryReport pool
    _ -> return $ QuerySuccess (Report reportName "{}")

getPnLReport :: ConnectionPool -> IO (QueryResult Report)
getPnLReport pool = do
    result <- liftIO $ runSqlPool
        (rawSql
            "SELECT \
            \  COALESCE((SELECT SUM(total_amount) FROM bill WHERE doc_date >= date_trunc('month', CURRENT_DATE)), 0), \
            \  COALESCE((SELECT SUM(qtty * unit_cost) FROM stock_movement \
            \             WHERE movement_date >= date_trunc('month', CURRENT_DATE)), 0), \
            \  COALESCE((SELECT SUM(total_amount) FROM bill WHERE doc_date >= date_trunc('month', CURRENT_DATE) \
            \             AND total_amount > 0), 0), \
            \  COALESCE((SELECT SUM(total_amount) FROM bill WHERE doc_date >= date_trunc('month', CURRENT_DATE) \
            \             AND total_amount < 0), 0)"
            []) pool
    case result of
        [(Single (revenue :: Double), Single (cogs :: Double), Single (income :: Double), Single (expenses :: Double))] -> do
            let jsonData =
                    decodeUtf8 . BL.toStrict $
                        Aeson.encode $
                            object
                                [ "revenue" .= revenue
                                , "costOfGoodsSold" .= cogs
                                , "grossProfit" .= (revenue - cogs)
                                , "totalIncome" .= income
                                , "totalExpenses" .= (abs expenses)
                                , "netProfit" .= (income - abs expenses)
                                , "currency" .= ("RUB" :: Text)
                                ]
            return $ QuerySuccess (Report "P&L Statement" jsonData)
        _ -> return $ QuerySuccess (Report "P&L Statement" "{}")

getInventoryReport :: ConnectionPool -> IO (QueryResult Report)
getInventoryReport pool = do
    result <- liftIO $ runSqlPool
        (rawSql
            "SELECT g.name, g.code, COALESCE(s.qtty, 0), \
            \  COALESCE(s.unit_cost, 0), \
            \  COALESCE(s.qtty * s.unit_cost, 0) \
            \FROM goods g \
            \LEFT JOIN stock s ON s.goods_id = g.id \
            \ORDER BY g.name"
            []) pool
    let rows = [ InvItem name code qty unitCost totalValue
               | (Single (name :: Text), Single (code :: Text), Single (qty :: Double), Single (unitCost :: Double), Single (totalValue :: Double)) <- result
               ]
    let totalValue = sum (map invTotalValue rows)
    let jsonData =
            decodeUtf8 . BL.toStrict $
                Aeson.encode $
                    object
                        [ "items" .= rows
                        , "totalValue" .= totalValue
                        , "itemCount" .= length rows
                        , "currency" .= ("RUB" :: Text)
                        ]
    return $ QuerySuccess (Report "Inventory Report" jsonData)
