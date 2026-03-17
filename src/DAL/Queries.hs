{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module DAL.Queries where

import Core.Document.Types (DocumentRegisterType (..))
import Core.Inventory.Types (Location (..), Stock (..))
import DAL.Types hiding (Location, Stock)
import Data.Int (Int64)
import Data.Maybe (fromJust, isJust)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (Day)
import Domain.Goods (Goods (..))
import qualified Hasql.Decoders as D
import qualified Hasql.Encoders as E
import Hasql.Pool (Pool, use)
import qualified Hasql.Session as Session
import Hasql.Statement (unpreparable)
import Surypus.RBAC (EntityType (..), Permission (..), Role (..), defaultRoles, hasPermission)
import Surypus.Types (Decimal (..))

personRowDecoder :: D.Row Person
personRowDecoder =
  Person
    <$> D.column (D.nonNullable D.int8)
    <*> D.column (D.nullable D.text)
    <*> D.column (D.nonNullable D.text)
    <*> D.column (D.nullable D.text)
    <*> D.column (D.nullable D.text)
    <*> D.column (D.nonNullable D.int2)
    <*> D.column (D.nonNullable D.int2)

goodsRowDecoder :: D.Row Goods
goodsRowDecoder =
  Goods
    <$> D.column (D.nonNullable D.int8)
    <*> D.column (D.nullable D.text)
    <*> D.column (D.nonNullable D.text)
    <*> D.column (D.nullable D.text)
    <*> D.column (D.nonNullable D.int8)
    <*> D.column (D.nullable D.int8)

locationRowDecoder :: D.Row Location
locationRowDecoder =
  Location
    <$> D.column (D.nonNullable D.int8)
    <*> D.column (D.nullable D.text)
    <*> D.column (D.nonNullable D.text)
    <*> (fromIntegral <$> D.column (D.nonNullable D.int2))

billRowDecoder :: D.Row Bill
billRowDecoder =
  Bill
    <$> D.column (D.nonNullable D.int8)
    <*> D.column (D.nullable D.text)
    <*> (fromIntegral <$> D.column (D.nonNullable D.int2))
    <*> (fromIntegral <$> D.column (D.nonNullable D.int2))
    <*> D.column (D.nonNullable D.date)
    <*> D.column (D.nullable D.int8)
    <*> D.column (D.nullable D.int8)
    <*> (Decimal . round <$> D.column (D.nonNullable D.numeric))
    <*> (Decimal . round <$> D.column (D.nonNullable D.numeric))
    <*> (Decimal . round <$> D.column (D.nonNullable D.numeric))

billLineRowDecoder :: D.Row BillLine
billLineRowDecoder =
  BillLine
    <$> D.column (D.nonNullable D.int8)
    <*> D.column (D.nonNullable D.int8)
    <*> D.column (D.nonNullable D.int8)
    <*> (Decimal . round <$> D.column (D.nonNullable D.numeric))
    <*> (Decimal . round <$> D.column (D.nonNullable D.numeric))
    <*> (Decimal . round <$> D.column (D.nonNullable D.numeric))
    <*> (Decimal . round <$> D.column (D.nonNullable D.numeric))

stockRowDecoder :: D.Row Stock
stockRowDecoder =
  Stock
    <$> D.column (D.nonNullable D.int8)
    <*> D.column (D.nonNullable D.int8)
    <*> D.column (D.nonNullable D.int8)
    <*> (Decimal . round <$> D.column (D.nonNullable D.numeric))
    <*> (Decimal . round <$> D.column (D.nonNullable D.numeric))

userRowDecoder :: D.Row User
userRowDecoder =
  User
    <$> D.column (D.nonNullable D.int8)
    <*> D.column (D.nonNullable D.text)
    <*> pure Nothing
    <*> D.column (D.nullable D.text)
    <*> D.column (D.nullable D.text)
    <*> D.column (D.nullable D.int8)
    <*> (fromIntegral <$> D.column (D.nonNullable D.int2))

accPlanRowDecoder :: D.Row AccPlan
accPlanRowDecoder =
  AccPlan
    <$> D.column (D.nonNullable D.int8)
    <*> D.column (D.nonNullable D.text)
    <*> D.column (D.nonNullable D.text)
    <*> (fromIntegral <$> D.column (D.nonNullable D.int2))

accTurnRowDecoder :: D.Row AccTurn
accTurnRowDecoder =
  AccTurn
    <$> D.column (D.nonNullable D.int8)
    <*> D.column (D.nullable D.int8)
    <*> D.column (D.nonNullable D.int8)
    <*> D.column (D.nonNullable D.int8)
    <*> (Decimal . round <$> D.column (D.nonNullable D.numeric))
    <*> D.column (D.nonNullable D.date)

salaryRowDecoder :: D.Row Salary
salaryRowDecoder =
  Salary
    <$> D.column (D.nonNullable D.int8)
    <*> D.column (D.nonNullable D.int8)
    <*> D.column (D.nonNullable D.date)
    <*> (Decimal . round <$> D.column (D.nonNullable D.numeric))
    <*> (Decimal . round <$> D.column (D.nonNullable D.numeric))
    <*> (Decimal . round <$> D.column (D.nonNullable D.numeric))
    <*> (Decimal . round <$> D.column (D.nonNullable D.numeric))
    <*> (Decimal . round <$> D.column (D.nonNullable D.numeric))

employeeRowDecoder :: D.Row Employee
employeeRowDecoder =
  Employee
    <$> D.column (D.nonNullable D.int8)
    <*> D.column (D.nonNullable D.text)
    <*> D.column (D.nonNullable D.text)
    <*> D.column (D.nullable D.text)
    <*> pure Nothing
    <*> (fromIntegral <$> D.column (D.nonNullable D.int2))

reportTemplateRowDecoder :: D.Row ReportTemplate
reportTemplateRowDecoder =
  ReportTemplate
    <$> D.column (D.nonNullable D.int8)
    <*> D.column (D.nonNullable D.text)
    <*> D.column (D.nonNullable D.text)
    <*> (fromIntegral <$> D.column (D.nonNullable D.int2))
    <*> D.column (D.nonNullable D.text)
    <*> D.column (D.nonNullable D.text)

orderRowDecoder :: D.Row Order
orderRowDecoder =
  Order
    <$> D.column (D.nonNullable D.int8)
    <*> D.column (D.nullable D.text)
    <*> D.column (D.nullable D.text)
    <*> D.column (D.nonNullable D.date)
    <*> D.column (D.nullable D.int8)
    <*> D.column (D.nullable D.int8)
    <*> (fromIntegral <$> D.column (D.nonNullable D.int2))
    <*> (Decimal . round <$> D.column (D.nonNullable D.numeric))
    <*> (Decimal . round <$> D.column (D.nonNullable D.numeric))
    <*> (Decimal . round <$> D.column (D.nonNullable D.numeric))

paymentRowDecoder :: D.Row Payment
paymentRowDecoder =
  Payment
    <$> D.column (D.nonNullable D.int8)
    <*> D.column (D.nonNullable D.int8)
    <*> D.column (D.nonNullable D.date)
    <*> (Decimal . round <$> D.column (D.nonNullable D.numeric))
    <*> (fromIntegral <$> D.column (D.nonNullable D.int2))
    <*> (fromIntegral <$> D.column (D.nonNullable D.int2))

goodsPriceRowDecoder :: D.Row GoodsPrice
goodsPriceRowDecoder =
  GoodsPrice
    <$> D.column (D.nonNullable D.int8)
    <*> D.column (D.nonNullable D.int8)
    <*> (fromIntegral <$> D.column (D.nonNullable D.int2))
    <*> (Decimal . round <$> D.column (D.nonNullable D.numeric))
    <*> (Decimal . round <$> D.column (D.nonNullable D.numeric))
    <*> D.column (D.nullable D.date)
    <*> D.column (D.nullable D.date)

unitRowDecoder :: D.Row Unit
unitRowDecoder =
  Unit
    <$> D.column (D.nonNullable D.int8)
    <*> D.column (D.nonNullable D.text)
    <*> D.column (D.nonNullable D.text)
    <*> D.column (D.nullable D.text)

taxRowDecoder :: D.Row Tax
taxRowDecoder =
  Tax
    <$> D.column (D.nonNullable D.int8)
    <*> D.column (D.nonNullable D.text)
    <*> D.column (D.nonNullable D.text)
    <*> (Decimal . round <$> D.column (D.nonNullable D.numeric))

currencyRowDecoder :: D.Row Currency
currencyRowDecoder =
  Currency
    <$> D.column (D.nonNullable D.int8)
    <*> D.column (D.nonNullable D.text)
    <*> D.column (D.nonNullable D.text)
    <*> D.column (D.nonNullable D.text)
    <*> (Decimal . round <$> D.column (D.nonNullable D.numeric))
    <*> D.column (D.nonNullable D.bool)

getPersons :: Pool -> IO (QueryResult [Person])
getPersons pool = do
  let stmt =
        unpreparable
          "SELECT id, code::text, name::text, inn::text, kpp::text, person_type, status FROM persons.person ORDER BY id"
          E.noParams
          (D.rowList personRowDecoder)
  res <- use pool $ Session.statement () stmt
  case res of
    Right rows -> return $ QuerySuccess rows
    Left err -> return $ QueryError (T.pack $ show err)

searchPersons :: Pool -> Text -> IO (QueryResult [Person])
searchPersons pool query = do
  let stmt =
        unpreparable
          "SELECT id, code::text, name::text, inn::text, kpp::text, person_type, status FROM persons.person WHERE name ILIKE $1 OR code ILIKE $1 OR inn ILIKE $1 ORDER BY id"
          (E.param (E.nonNullable E.text))
          (D.rowList personRowDecoder)
  res <- use pool $ Session.statement (T.pack ("%" <> T.unpack query <> "%")) stmt
  case res of
    Right rows -> return $ QuerySuccess rows
    Left err -> return $ QueryError (T.pack $ show err)

getPersonById :: Pool -> Int64 -> IO (QueryResult Person)
getPersonById pool pid = do
  let stmt =
        unpreparable
          "SELECT id, code::text, name::text, inn::text, kpp::text, person_type, status FROM persons.person WHERE id = $1"
          (E.param (E.nonNullable E.int8))
          (D.rowMaybe personRowDecoder)
  res <- use pool $ Session.statement pid stmt
  case res of
    Right (Just p) -> return $ QuerySuccess p
    Right Nothing -> return $ QueryError "Not Found"
    Left err -> return $ QueryError (T.pack $ show err)

getGoods :: Pool -> IO (QueryResult [Goods])
getGoods pool = do
  let stmt =
        unpreparable
          "SELECT id, code::text, name::text, barcode::text, unit_id, parent_id FROM goods ORDER BY id"
          E.noParams
          (D.rowList goodsRowDecoder)
  res <- use pool $ Session.statement () stmt
  case res of
    Right rows -> return $ QuerySuccess rows
    Left err -> return $ QueryError (T.pack $ show err)

searchGoods :: Pool -> Text -> IO (QueryResult [Goods])
searchGoods pool query = do
  let stmt =
        unpreparable
          "SELECT id, code::text, name::text, barcode::text, unit_id, parent_id FROM goods WHERE name ILIKE $1 OR code ILIKE $1 OR barcode ILIKE $1 ORDER BY id"
          (E.param (E.nonNullable E.text))
          (D.rowList goodsRowDecoder)
  res <- use pool $ Session.statement (T.pack ("%" <> T.unpack query <> "%")) stmt
  case res of
    Right rows -> return $ QuerySuccess rows
    Left err -> return $ QueryError (T.pack $ show err)

getGoodsById :: Pool -> Int64 -> IO (QueryResult Goods)
getGoodsById pool gid = do
  let stmt =
        unpreparable
          "SELECT id, code::text, name::text, barcode::text, unit_id, parent_id FROM goods WHERE id = $1"
          (E.param (E.nonNullable E.int8))
          (D.rowMaybe goodsRowDecoder)
  res <- use pool $ Session.statement gid stmt
  case res of
    Right (Just g) -> return $ QuerySuccess g
    Right Nothing -> return $ QueryError "Not Found"
    Left err -> return $ QueryError (T.pack $ show err)

getGoodsByBarcode :: Pool -> Text -> IO (QueryResult Goods)
getGoodsByBarcode pool barcode = do
  let stmt =
        unpreparable
          "SELECT id, code::text, name::text, barcode::text, unit_id, parent_id FROM goods WHERE barcode = $1"
          (E.param (E.nonNullable E.text))
          (D.rowMaybe goodsRowDecoder)
  res <- use pool $ Session.statement barcode stmt
  case res of
    Right (Just g) -> return $ QuerySuccess g
    Right Nothing -> return $ QueryError "Not Found"
    Left err -> return $ QueryError (T.pack $ show err)

getLocations :: Pool -> IO (QueryResult [Location])
getLocations pool = do
  let stmt =
        unpreparable
          "SELECT id, code::text, name::text, location_type FROM location ORDER BY id"
          E.noParams
          (D.rowList locationRowDecoder)
  res <- use pool $ Session.statement () stmt
  case res of
    Right rows -> return $ QuerySuccess rows
    Left err -> return $ QueryError (T.pack $ show err)

getBills :: Pool -> IO (QueryResult [Bill])
getBills pool = do
  let stmt =
        unpreparable
          "SELECT id, code::text, bill_type, doc_status, doc_date, person_id, location_id, total, discount_amount, tax_amount FROM bill ORDER BY id"
          E.noParams
          (D.rowList billRowDecoder)
  res <- use pool $ Session.statement () stmt
  case res of
    Right rows -> return $ QuerySuccess rows
    Left err -> return $ QueryError (T.pack $ show err)

getBillById :: Pool -> Int64 -> IO (QueryResult Bill)
getBillById pool bid = do
  let stmt =
        unpreparable
          "SELECT id, code::text, bill_type, doc_status, doc_date, person_id, location_id, total, discount_amount, tax_amount FROM bill WHERE id = $1"
          (E.param (E.nonNullable E.int8))
          (D.rowMaybe billRowDecoder)
  res <- use pool $ Session.statement bid stmt
  case res of
    Right (Just b) -> return $ QuerySuccess b
    Right Nothing -> return $ QueryError "Not Found"
    Left err -> return $ QueryError (T.pack $ show err)

getBillLines :: Pool -> Int64 -> IO (QueryResult [BillLine])
getBillLines pool bid = do
  let stmt =
        unpreparable
          "SELECT id, bill_id, goods_id, qtty, price, discount_amount, amount FROM bill_line WHERE bill_id = $1 ORDER BY id"
          (E.param (E.nonNullable E.int8))
          (D.rowList billLineRowDecoder)
  res <- use pool $ Session.statement bid stmt
  case res of
    Right rows -> return $ QuerySuccess rows
    Left err -> return $ QueryError (T.pack $ show err)

getStock :: Pool -> Int64 -> Int64 -> IO (QueryResult [Stock])
getStock pool _ _ = getStockAll pool

getStockAll :: Pool -> IO (QueryResult [Stock])
getStockAll pool = do
  let stmt =
        unpreparable
          "SELECT id, goods_id, location_id, qtty, resrv_qtty FROM stock ORDER BY id"
          E.noParams
          (D.rowList stockRowDecoder)
  res <- use pool $ Session.statement () stmt
  case res of
    Right rows -> return $ QuerySuccess rows
    Left err -> return $ QueryError (T.pack $ show err)

getStockByLocation :: Pool -> Int64 -> IO (QueryResult [Stock])
getStockByLocation pool lid = do
  let stmt =
        unpreparable
          "SELECT id, goods_id, location_id, qtty, resrv_qtty FROM stock WHERE location_id = $1"
          (E.param (E.nonNullable E.int8))
          (D.rowList stockRowDecoder)
  res <- use pool $ Session.statement lid stmt
  case res of
    Right rows -> return $ QuerySuccess rows
    Left err -> return $ QueryError (T.pack $ show err)

getStockByGoods :: Pool -> Int64 -> IO (QueryResult [Stock])
getStockByGoods pool gid = do
  let stmt =
        unpreparable
          "SELECT id, goods_id, location_id, qtty, resrv_qtty FROM stock WHERE goods_id = $1"
          (E.param (E.nonNullable E.int8))
          (D.rowList stockRowDecoder)
  res <- use pool $ Session.statement gid stmt
  case res of
    Right rows -> return $ QuerySuccess rows
    Left err -> return $ QueryError (T.pack $ show err)

getSalesSummary :: Pool -> Int64 -> Int64 -> IO (QueryResult [(Day, Decimal)])
getSalesSummary pool daysAgo limit = do
  let sql =
        T.concat
          [ "SELECT doc_date, SUM(total) as daily_total FROM bill ",
            "WHERE doc_date >= CURRENT_DATE - ('",
            T.pack (show daysAgo),
            " days')::interval ",
            "GROUP BY doc_date ORDER BY doc_date DESC LIMIT ",
            T.pack (show limit)
          ]
      stmt = unpreparable sql E.noParams (D.rowList dateAmountDecoder)
  res <- use pool $ Session.statement () stmt
  case res of
    Right rows -> return $ QuerySuccess rows
    Left err -> return $ QueryError (T.pack $ show err)
  where
    dateAmountDecoder :: D.Row (Day, Decimal)
    dateAmountDecoder = (,) <$> D.column (D.nonNullable D.date) <*> (Decimal . round <$> D.column (D.nonNullable D.numeric))

getUsers :: Pool -> IO (QueryResult [User])
getUsers pool = do
  let stmt =
        unpreparable
          "SELECT e.id, e.code::text, e.name::text, e.email::text, ur.role_id, e.status \
          \FROM employee e \
          \LEFT JOIN user_role ur ON e.id = ur.user_id \
          \ORDER BY e.id"
          E.noParams
          (D.rowList userRowDecoder)
  res <- use pool $ Session.statement () stmt
  case res of
    Right rows -> return $ QuerySuccess rows
    Left err -> return $ QueryError (T.pack $ show err)

getTopSellingGoods :: Pool -> Int64 -> IO (QueryResult [(Int64, Text, Decimal)])
getTopSellingGoods pool limit = do
  let sql =
        T.concat
          [ "SELECT g.id, g.name::text, COALESCE(SUM(bl.qtty * bl.price), 0) as total_amount ",
            "FROM goods g ",
            "LEFT JOIN bill_line bl ON g.id = bl.goods_id ",
            "LEFT JOIN bill b ON bl.bill_id = b.id ",
            "WHERE b.doc_status = 1 ",
            "GROUP BY g.id, g.name ",
            "ORDER BY total_amount DESC LIMIT ",
            T.pack (show limit)
          ]
      stmt = unpreparable sql E.noParams (D.rowList topGoodsDecoder)
  res <- use pool $ Session.statement () stmt
  case res of
    Right rows -> return $ QuerySuccess rows
    Left err -> return $ QueryError (T.pack $ show err)
  where
    rolesDecoder :: D.Row (Int64, Text, [Text])
    rolesDecoder =
      (,,)
        <$> D.column (D.nonNullable D.int8)
        <*> D.column (D.nullable D.text)
        <*> (fmap (T.splitOn ",") . D.column (D.nullable D.text))

inventoryDecoder :: D.Row (Int64, Text, Text, Int, Double, Double, Double)
inventoryDecoder =
  (,,,,,,)
    <$> D.column (D.nonNullable D.int8)
    <*> D.column (D.nullable D.text)
    <*> D.column (D.nullable D.text)
    <*> D.column (D.nullable D.text)
    <*> (fromIntegral <$> D.column (D.nonNullable D.int4))
    <*> D.column (D.nonNullable D.numeric)
    <*> D.column (D.nonNullable D.numeric)

-- | Get document types list
getDocumentTypes :: Pool -> IO (QueryResult [DocumentRegisterType])
getDocumentTypes pool = do
  let stmt =
        unpreparable
          "SELECT id, name::text, description::text, flag FROM document_type ORDER BY id"
          E.noParams
          (D.rowList documentTypeRowDecoder)
  res <- use pool $ Session.statement () stmt
  case res of
    Right rows -> return $ QuerySuccess rows
    Left err -> return $ QueryError (T.pack $ show err)
  where
    documentTypeRowDecoder :: D.Row DocumentRegisterType
    documentTypeRowDecoder =
      DocumentRegisterType
        <$> D.column (D.nonNullable D.int8)
        <*> D.column (D.nullable D.text)
        <*> D.column (D.nullable D.text)
        <*> D.column (D.nullable D.int4)

-- | Get stock summary (total quantity and value by location/warehouse)
getStockSummary :: Pool -> IO (QueryResult [(Int64, Text, Int, Double, Double)])
getStockSummary pool = do
  let stmt =
        unpreparable
          "SELECT l.id, l.name::text, COUNT(s.id) as stock_items, "
          ++ "COALESCE(SUM(s.quantity), 0) as total_quantity, "
          ++ "COALESCE(SUM(s.quantity * s.unit_price), 0) as total_value "
          ++ "FROM location l "
          ++ "LEFT JOIN stock s ON l.id = s.location_id "
          ++ "GROUP BY l.id, l.name "
          ++ "ORDER BY l.id"
            E.noParams
            (D.rowList stockSummaryDecoder)
  res <- use pool $ Session.statement () stmt
  case res of
    Right rows -> return $ QuerySuccess rows
    Left err -> return $ QueryError (T.pack $ show err)
  where
    stockSummaryDecoder :: D.Row (Int64, Text, Int, Double, Double)
    stockSummaryDecoder =
      (,,,,)
        <$> D.column (D.nonNullable D.int8)
        <*> D.column (D.nullable D.text)
        <*> (fromIntegral <$> D.column (D.nonNullable D.int4))
        <*> (D.column (D.nonNullable D.numeric))
        <*> (D.column (D.nonNullable D.numeric))

-- | Get roles list with permissions
getRoles :: Pool -> IO (QueryResult [(Int64, Text, [Text])])
getRoles pool = do
  let stmt =
        unpreparable
          "SELECT r.id, r.name::text, COALESCE(string_agg(p.name::text, ','), '') as permissions "
          ++ "FROM role r "
          ++ "LEFT JOIN role_permission rp ON r.id = rp.role_id "
          ++ "LEFT JOIN permission p ON rp.permission_id = p.id "
          ++ "GROUP BY r.id, r.name "
          ++ "ORDER BY r.id"
            E.noParams
            (D.rowList rolesDecoder)
  res <- use pool $ Session.statement () stmt
  case res of
    Right rows -> return $ QueryResult rows
    Left err -> return $ QueryError (T.pack $ show err)
  where
    rolesDecoder :: D.Row (Int64, Text, [Text])
    rolesDecoder =
      (,,)
        <$> D.column (D.nonNullable D.int8)
        <*> D.column (D.nullable D.text)
        <*> (fmap (splitOn ",") . D.column (D.nullable D.text))

-- | Get inventory summary (goods with stock levels)
getInventory :: Pool -> IO (QueryResult [(Int64, Text, Text, Int, Double, Double, Double)])
getInventory pool = do
  let stmt =
        unpreparable
          "SELECT g.id, g.code::text, g.name::text, u.code::text as unit_code, "
          ++ "COALESCE(s.quantity, 0) as quantity, "
          ++ "COALESCE(s.average_cost, 0) as average_cost, "
          ++ "COALESCE(g.price, 0) as price "
          ++ "FROM goods g "
          ++ "LEFT JOIN unit u ON g.unit_id = u.id "
          ++ "LEFT JOIN (SELECT goods_id, SUM(quantity) as quantity, "
          ++ "AVG(unit_cost) as average_cost FROM stock GROUP BY goods_id) s "
          ++ "ON g.id = s.goods_id "
          ++ "ORDER BY g.id"
            E.noParams
            (D.rowList inventoryDecoder)
  res <- use pool $ Session.statement () stmt
  case res of
    Right rows -> return $ QuerySuccess rows
    Left err -> return $ QueryError (T.pack $ show err)
  where
    inventoryDecoder :: D.Row (Int64, Text, Text, Int, Double, Double, Double)
    inventoryDecoder =
      (,,,,,,)
        <$> D.column (D.nonNullable D.int8)
        <*> D.column (D.nullable D.text)
        <*> D.column (D.nullable D.text)
        <*> D.column (D.nullable D.text)
        <*> (fromIntegral <$> D.column (D.nonNullable D.int4))
        <*> (D.column (D.nonNullable D.numeric))
        <*> (D.column (D.nonNullable D.numeric))
