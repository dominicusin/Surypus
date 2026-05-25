{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE OverloadedStrings #-}

module Surypus.API.Orders
  ( Order(..)
  , OrderInput(..)
  , OrderLine(..)
  , listOrders
  , createOrder
  , getOrder
  , updateOrder
  , deleteOrder
  ) where

import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Aeson (ToJSON, FromJSON)
import GHC.Generics (Generic)
import qualified Hasql.Decoders as D
import qualified Hasql.Encoders as E
import qualified Hasql.Session as Session
import qualified Hasql.Statement as Stmt
import Data.Functor.Contravariant ((>$<))
import DAL.Database (Pool, usePool)
import DAL.Types (QueryResult(..))

data Order = Order
  { orderId :: !Text
  , orderType :: !Text
  , orderNumber :: !Text
  , counterpartyId :: !(Maybe Text)
  , orderDate :: !Text
  , totalAmount :: !Double
  , status :: !Text
  , notes :: !(Maybe Text)
  } deriving (Show, Eq, Generic)

instance ToJSON Order

data OrderInput = OrderInput
  { oiType :: !Text
  , oiNumber :: !Text
  , oiCounterpartyId :: !(Maybe Text)
  , oiDate :: !Text
  , oiTotalAmount :: !Double
  , oiStatus :: !Text
  , oiNotes :: !(Maybe Text)
  } deriving (Show, Eq, Generic)

instance ToJSON OrderInput
instance FromJSON OrderInput

data OrderLine = OrderLine
  { olId :: !Text
  , olOrderId :: !Text
  , olGoodsId :: !(Maybe Text)
  , olQuantity :: !Double
  , olUnitPrice :: !Double
  , olLineTotal :: !Double
  } deriving (Show, Eq, Generic)

instance ToJSON OrderLine

orderDecoder :: D.Row Order
orderDecoder = Order
  <$> D.column (D.nonNullable D.text)
  <*> D.column (D.nonNullable D.text)
  <*> D.column (D.nonNullable D.text)
  <*> D.column (D.nullable D.text)
  <*> D.column (D.nonNullable D.text)
  <*> D.column (D.nonNullable D.float8)
  <*> D.column (D.nonNullable D.text)
  <*> D.column (D.nullable D.text)

-- | List all orders
listOrders :: Pool -> IO (QueryResult [Order])
listOrders pool = do
  let stmt = Stmt.Statement
        "SELECT id::TEXT, order_type, order_number, counterparty_id::TEXT, order_date::TEXT, total_amount, status, notes FROM orders ORDER BY created_at DESC"
        E.noParams
        (D.rowList orderDecoder)
        True
  res <- usePool pool $ Session.statement () stmt
  case res of
    Right orders -> return $ QuerySuccess orders
    Left err -> return $ QueryError (T.pack $ show err)

-- | Create a new order
createOrder :: Pool -> OrderInput -> IO (QueryResult Order)
createOrder pool input = do
  let stmt = Stmt.Statement
        "INSERT INTO orders (order_type, order_number, counterparty_id, order_date, total_amount, status, notes) VALUES ($1, $2, $3::UUID, $4::DATE, $5, $6, $7) RETURNING id::TEXT, order_type, order_number, counterparty_id::TEXT, order_date::TEXT, total_amount, status, notes"
        (((\(t, _, _, _, _, _, _) -> t) >$< E.param (E.nonNullable E.text))
         <> ((\(_, n, _, _, _, _, _) -> n) >$< E.param (E.nonNullable E.text))
         <> ((\(_, _, c, _, _, _, _) -> c) >$< E.param (E.nullable E.text))
         <> ((\(_, _, _, d, _, _, _) -> d) >$< E.param (E.nonNullable E.text))
         <> ((\(_, _, _, _, a, _, _) -> a) >$< E.param (E.nonNullable E.float8))
         <> ((\(_, _, _, _, _, s, _) -> s) >$< E.param (E.nonNullable E.text))
         <> ((\(_, _, _, _, _, _, n) -> n) >$< E.param (E.nullable E.text)))
        (D.singleRow orderDecoder)
        True
  let params = (oiType input, oiNumber input, oiCounterpartyId input, oiDate input, oiTotalAmount input, oiStatus input, oiNotes input)
  res <- usePool pool $ Session.statement params stmt
  case res of
    Right order -> return $ QuerySuccess order
    Left err -> return $ QueryError (T.pack $ show err)

-- | Get order by ID
getOrder :: Pool -> Text -> IO (QueryResult Order)
getOrder pool oid = do
  let stmt = Stmt.Statement
        "SELECT id::TEXT, order_type, order_number, counterparty_id::TEXT, order_date::TEXT, total_amount, status, notes FROM orders WHERE id = $1::UUID"
        (E.param (E.nonNullable E.text))
        (D.singleRow orderDecoder)
        True
  res <- usePool pool $ Session.statement oid stmt
  case res of
    Right order -> return $ QuerySuccess order
    Left err -> return $ QueryError (T.pack $ show err)

-- | Update order
updateOrder :: Pool -> Text -> OrderInput -> IO (QueryResult Order)
updateOrder pool oid input = do
  let stmt = Stmt.Statement
        "UPDATE orders SET order_type = $1, order_number = $2, counterparty_id = $3::UUID, order_date = $4::DATE, total_amount = $5, status = $6, notes = $7 WHERE id = $8::UUID RETURNING id::TEXT, order_type, order_number, counterparty_id::TEXT, order_date::TEXT, total_amount, status, notes"
        (((\(a, _, _, _, _, _, _, _) -> a) >$< E.param (E.nonNullable E.text))
         <> ((\(_, b, _, _, _, _, _, _) -> b) >$< E.param (E.nonNullable E.text))
         <> ((\(_, _, c, _, _, _, _, _) -> c) >$< E.param (E.nullable E.text))
         <> ((\(_, _, _, d, _, _, _, _) -> d) >$< E.param (E.nonNullable E.text))
         <> ((\(_, _, _, _, e, _, _, _) -> e) >$< E.param (E.nonNullable E.float8))
         <> ((\(_, _, _, _, _, f, _, _) -> f) >$< E.param (E.nonNullable E.text))
         <> ((\(_, _, _, _, _, _, g, _) -> g) >$< E.param (E.nullable E.text))
         <> ((\(_, _, _, _, _, _, _, h) -> h) >$< E.param (E.nonNullable E.text)))
        (D.singleRow orderDecoder)
        True
  let params = (oiType input, oiNumber input, oiCounterpartyId input, oiDate input, oiTotalAmount input, oiStatus input, oiNotes input, oid)
  res <- usePool pool $ Session.statement params stmt
  case res of
    Right order -> return $ QuerySuccess order
    Left err -> return $ QueryError (T.pack $ show err)

-- | Delete order
deleteOrder :: Pool -> Text -> IO (QueryResult ())
deleteOrder pool oid = do
  let stmt = Stmt.Statement
        "DELETE FROM orders WHERE id = $1::UUID"
        (E.param (E.nonNullable E.text))
        D.noResult
        True
  res <- usePool pool $ Session.statement oid stmt
  case res of
    Right _ -> return $ QuerySuccess ()
    Left err -> return $ QueryError (T.pack $ show err)