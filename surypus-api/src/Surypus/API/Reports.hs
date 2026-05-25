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
import qualified Data.ByteString.Lazy as BL
import Data.Text.Encoding (decodeUtf8)
import Data.Aeson (ToJSON, object, (.=))
import qualified Data.Aeson as Aeson
import GHC.Generics (Generic)
import qualified Hasql.Session as Session
import qualified Hasql.Statement as Statement
import qualified Hasql.Decoders as D
import qualified Hasql.Encoders as E
import DAL.Database (Pool, usePool)
import DAL.Types (QueryResult(..))

data Report = Report
  { rptName :: !Text, rptData :: !Text
  } deriving (Show, Eq, Generic)

instance ToJSON Report

data PnLRow = PnLRow
  { pnlRevenue :: !Double, pnlCogs :: !Double, pnlIncome :: !Double, pnlExpenses :: !Double
  } deriving (Show, Eq, Generic)

instance ToJSON PnLRow

data InvItem = InvItem
  { invName :: !Text, invCode :: !Text, invQty :: !Double
  , invUnitCost :: !Double, invTotalValue :: !Double
  } deriving (Show, Eq, Generic)

instance ToJSON InvItem

generateReport :: Pool -> Text -> IO (QueryResult Report)
generateReport pool reportName = case reportName of
  "pnl" -> getPnLReport pool
  "inventory" -> getInventoryReport pool
  _ -> return $ QuerySuccess (Report reportName "{}")

getPnLReport :: Pool -> IO (QueryResult Report)
getPnLReport pool = do
  let stmt = Statement.Statement
        "SELECT \
        \  COALESCE((SELECT SUM(total) FROM bill WHERE doc_date >= date_trunc('month', CURRENT_DATE)), 0)::float8, \
        \  COALESCE((SELECT SUM(qtty * unit_cost) FROM stock_movement \
        \             WHERE movement_date >= date_trunc('month', CURRENT_DATE)), 0)::float8, \
        \  COALESCE((SELECT SUM(total) FROM bill WHERE doc_date >= date_trunc('month', CURRENT_DATE) \
        \             AND total > 0), 0)::float8, \
        \  COALESCE((SELECT SUM(total) FROM bill WHERE doc_date >= date_trunc('month', CURRENT_DATE) \
        \             AND total < 0), 0)::float8"
        E.noParams
        (D.singleRow $ PnLRow
          <$> D.column (D.nonNullable D.float8)
          <*> D.column (D.nonNullable D.float8)
          <*> D.column (D.nonNullable D.float8)
          <*> D.column (D.nonNullable D.float8))
        True
  res <- usePool pool $ Session.statement () stmt
  case res of
    Right (PnLRow revenue cogs income expenses) -> do
      let jsonData = decodeUtf8 . BL.toStrict $ Aeson.encode $ object
            [ "revenue" .= revenue
            , "costOfGoodsSold" .= cogs
            , "grossProfit" .= (revenue - cogs)
            , "totalIncome" .= income
            , "totalExpenses" .= (abs expenses)
            , "netProfit" .= (income - abs expenses)
            , "currency" .= ("RUB" :: Text)
            ]
      return $ QuerySuccess (Report "P&L Statement" jsonData)
    Left err -> return $ QueryError (T.pack $ show err)

getInventoryReport :: Pool -> IO (QueryResult Report)
getInventoryReport pool = do
  let stmt = Statement.Statement
        "SELECT g.name::TEXT, g.code::TEXT, COALESCE(s.qtty, 0)::float8, \
        \  COALESCE(s.unit_cost, 0)::float8, \
        \  COALESCE(s.qtty * s.unit_cost, 0)::float8 \
        \FROM goods g \
        \LEFT JOIN stock s ON s.goods_id = g.id \
        \ORDER BY g.name"
        E.noParams
        (D.rowList $ InvItem
          <$> D.column (D.nonNullable D.text)
          <*> D.column (D.nonNullable D.text)
          <*> D.column (D.nonNullable D.float8)
          <*> D.column (D.nonNullable D.float8)
          <*> D.column (D.nonNullable D.float8))
        True
  res <- usePool pool $ Session.statement () stmt
  case res of
    Right rows -> do
      let totalValue = sum (map invTotalValue rows)
      let jsonData = decodeUtf8 . BL.toStrict $ Aeson.encode $ object
            [ "items" .= rows
            , "totalValue" .= totalValue
            , "itemCount" .= length rows
            , "currency" .= ("RUB" :: Text)
            ]
      return $ QuerySuccess (Report "Inventory Report" jsonData)
    Left err -> return $ QueryError (T.pack $ show err)
