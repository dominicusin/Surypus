{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE Arrows #-}

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
import Data.Functor.Contravariant ((>$<))
import qualified Opaleye as OE
import qualified Opaleye.Internal.HaskellDB.PrimQuery as OPQ
import qualified Opaleye.Internal.PGTypes as OPG
import qualified Opaleye.Internal.Tag as OITag
import DAL.Database (Pool, runQuery, runCommand)
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

-- Table definition for orders table
ordersTable :: OE.Table (OE.OEText, OE.OEText, OE.OEText, OE.OEMaybe (OE.OEText), OE.OEText, OE.OEDouble, OE.OEText, OE.OEMaybe (OE.OEText)) (OE.OEText, OE.OEText, OE.OEText, OE.OEMaybe (OE.OEText), OE.OEText, OE.OEDouble, OE.OEText, OE.OEMaybe (OE.OEText))
ordersTable = OE.table "orders" (OITag.tag "orders")
   \(orderId, orderType, orderNumber, counterpartyId, orderDate, totalAmount, status, notes) ->
      ( orderId
      , orderType
      , orderNumber
      , counterpartyId
      , orderDate
      , totalAmount
      , status
      , notes
      )
   \(orderId, orderType, orderNumber, counterpartyId, orderDate, totalAmount, status, notes) ->
      ( OE.required orderId
      , OE.required orderType
      , OE.required orderNumber
      , OE.required counterpartyId
      , OE.required orderDate
      , OE.required totalAmount
      , OE.required status
      , OE.required notes
      )

-- | List all orders
listOrders :: Pool -> IO (QueryResult [Order])
listOrders pool = do
   let query = OE.sql 
         "SELECT id::TEXT, order_type, order_number, counterparty_id::TEXT, order_date::TEXT, total_amount, status, notes FROM orders ORDER BY created_at DESC"
         (OE.makeColumns (,,,,,,,) 
            OE.text
            OE.text
            OE.text
            (OE.maybe OE.text)
            OE.text
            OE.double
            OE.text
            (OE.maybe OE.text)
         ) OE.noParams
   result <- runQuery pool query
   case result of
     Left err -> return $ QueryError (T.pack $ show err)
     Right cols -> return $ QuerySuccess $ map (\(orderId, orderType, orderNumber, counterpartyId, orderDate, totalAmount, status, notes) ->
        Order orderId orderType orderNumber counterpartyId orderDate totalAmount status notes) cols

-- | Create a new order
createOrder :: Pool -> OrderInput -> IO (QueryResult Order)
createOrder pool input = do
   let insert = OE.insert ordersTable
         OE.constNothing
         ( oiType input                                 -- order_type
         , oiNumber input                               -- order_number
         , (read <$> oiCounterpartyId input)            -- counterparty_id (UUID)
         , (read <$> oiDate input)                      -- order_date (Date)
         , oiTotalAmount input                          -- total_amount
         , oiStatus input                               -- status
         , oiNotes input                                -- notes
         )
   result <- runCommand pool insert
   case result of
     Left err -> return $ QueryError (T.pack $ show err)
     Right count -> if count > 0
                    then getOrder pool ""  -- TODO: Get the actual ID from the insert
                    else return $ QueryError "Failed to create order"

-- | Get order by ID
getOrder :: Pool -> Text -> IO (QueryResult Order)
getOrder pool oid = do
   let query = OE.sql 
         "SELECT id::TEXT, order_type, order_number, counterparty_id::TEXT, order_date::TEXT, total_amount, status, notes FROM orders WHERE id = $1::UUID"
         (OE.makeColumns (,,,,,,,) 
            OE.text
            OE.text
            OE.text
            (OE.maybe OE.text)
            OE.text
            OE.double
            OE.text
            (OE.maybe OE.text)
         ) (OE.required . fst)
   result <- runQuery pool query oid
   case result of
     Left err -> return $ QueryError (T.pack $ show err)
     Right cols -> return $ QuerySuccess $ map (\(orderId, orderType, orderNumber, counterpartyId, orderDate, totalAmount, status, notes) ->
        Order orderId orderType orderNumber counterpartyId orderDate totalAmount status notes) cols

-- | Update order
updateOrder :: Pool -> Text -> OrderInput -> IO (QueryResult Order)
updateOrder pool oid input = do
   let update = OE.update ordersTable
         ( \(_orderId, _orderType, _orderNumber, _counterpartyId, _orderDate, _totalAmount, _status, _notes) ->
           ( oiType input                                 -- order_type
           , oiNumber input                               -- order_number
           , (read <$> oiCounterpartyId input)            -- counterparty_id (UUID)
           , (read <$> oiDate input)                      -- order_date (Date)
           , oiTotalAmount input                          -- total_amount
           , oiStatus input                               -- status
           , oiNotes input                                -- notes
           )
         )
         ( \(_orderId, _orderType, _orderNumber, _counterpartyId, _orderDate, _totalAmount, _status, _notes) ->
           OE.required (OE.sql "id = $1::UUID") (OE.required . fst)
         )
   result <- runCommand pool update (oid)
   case result of
     Left err -> return $ QueryError (T.pack $ show err)
     Right count -> if count > 0
                    then getOrder pool oid
                    else return $ QueryError "Failed to update order"

-- | Delete order
deleteOrder :: Pool -> Text -> IO (QueryResult ())
deleteOrder pool oid = do
   let query = OE.sql 
         "DELETE FROM orders WHERE id = $1::UUID"
         OE.noCols
         (OE.required . fst)
   result <- runCommand pool query oid
   case result of
     Left err -> return $ QueryError (T.pack $ show err)
     Right count -> if count > 0
                    then QuerySuccess ()
                    else QueryError "Failed to delete order"