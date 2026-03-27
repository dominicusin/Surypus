{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module DAL.Queries where

import Core.Document.Types (DocumentRegisterType (..))
import DAL.Types
import Data.Functor.Contravariant ((>$<))
import Data.Int (Int16, Int64)
import Data.Text (Text, splitOn)
import qualified Data.Text as T
import Data.Time (Day)
import qualified Hasql.Decoders as D
import qualified Hasql.Encoders as E
import Hasql.Pool (Pool, use)
import qualified Hasql.Session as Session
import qualified Hasql.Statement as Statement
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

dashboardStatsRowDecoder :: D.Row DashboardStats
dashboardStatsRowDecoder =
  DashboardStats
    <$> (fromIntegral <$> D.column (D.nonNullable D.int8))
    <*> (fromIntegral <$> D.column (D.nonNullable D.int8))
    <*> (fromIntegral <$> D.column (D.nonNullable D.int8))
    <*> (fromIntegral <$> D.column (D.nonNullable D.int8))

getPersons :: Pool -> IO (QueryResult [Person])
getPersons pool = do
  let stmt =
        Statement.unpreparable
          "SELECT id, code::text, name::text, inn::text, kpp::text, person_type, status FROM persons.person ORDER BY id"
          E.noParams
          (D.rowList personRowDecoder)
  res <- use pool $ Session.statement () stmt
  case res of
    Right rows -> pure $ QuerySuccess rows
    Left err -> pure $ QueryError (T.pack $ show err)

searchPersons :: Pool -> Text -> IO (QueryResult [Person])
searchPersons pool query = do
  let stmt =
        Statement.prepared
          "SELECT id, code::text, name::text, inn::text, kpp::text, person_type, status FROM persons.person WHERE name ILIKE $1 OR code ILIKE $1 OR inn ILIKE $1 ORDER BY id"
          (E.param (E.nonNullable E.text))
          (D.rowList personRowDecoder)
  res <- use pool $ Session.statement (T.pack ("%" <> T.unpack query <> "%")) stmt
  case res of
    Right rows -> pure $ QuerySuccess rows
    Left err -> pure $ QueryError (T.pack $ show err)

getPersonById :: Pool -> Int64 -> IO (QueryResult Person)
getPersonById pool pid = do
  let stmt =
        Statement.prepared
          "SELECT id, code::text, name::text, inn::text, kpp::text, person_type, status FROM persons.person WHERE id = $1"
          (E.param (E.nonNullable E.int8))
          (D.rowMaybe personRowDecoder)
  res <- use pool $ Session.statement pid stmt
  case res of
    Right (Just p) -> pure $ QuerySuccess p
    Right Nothing -> pure $ QueryError "Not Found"
    Left err -> pure $ QueryError (T.pack $ show err)

getGoods :: Pool -> IO (QueryResult [Goods])
getGoods pool = do
  let stmt =
        Statement.prepared
          "SELECT id, code::text, name::text, barcode::text, unit_id, parent_id FROM goods ORDER BY id"
          E.noParams
          (D.rowList goodsRowDecoder)
  res <- use pool $ Session.statement () stmt
  case res of
    Right rows -> pure $ QuerySuccess rows
    Left err -> pure $ QueryError (T.pack $ show err)

searchGoods :: Pool -> Text -> IO (QueryResult [Goods])
searchGoods pool query = do
  let stmt =
        Statement.prepared
          "SELECT id, code::text, name::text, barcode::text, unit_id, parent_id FROM goods WHERE name ILIKE $1 OR code ILIKE $1 OR barcode ILIKE $1 ORDER BY id"
          (E.param (E.nonNullable E.text))
          (D.rowList goodsRowDecoder)
  res <- use pool $ Session.statement (T.pack ("%" <> T.unpack query <> "%")) stmt
  case res of
    Right rows -> pure $ QuerySuccess rows
    Left err -> pure $ QueryError (T.pack $ show err)

getGoodsById :: Pool -> Int64 -> IO (QueryResult Goods)
getGoodsById pool gid = do
  let stmt =
        Statement.prepared
          "SELECT id, code::text, name::text, barcode::text, unit_id, parent_id FROM goods WHERE id = $1"
          (E.param (E.nonNullable E.int8))
          (D.rowMaybe goodsRowDecoder)
  res <- use pool $ Session.statement gid stmt
  case res of
    Right (Just g) -> pure $ QuerySuccess g
    Right Nothing -> pure $ QueryError "Not Found"
    Left err -> pure $ QueryError (T.pack $ show err)

getGoodsByBarcode :: Pool -> Text -> IO (QueryResult Goods)
getGoodsByBarcode pool barcode = do
  let stmt =
        Statement.prepared
          "SELECT id, code::text, name::text, barcode::text, unit_id, parent_id FROM goods WHERE barcode = $1"
          (E.param (E.nonNullable E.text))
          (D.rowMaybe goodsRowDecoder)
  res <- use pool $ Session.statement barcode stmt
  case res of
    Right (Just g) -> pure $ QuerySuccess g
    Right Nothing -> pure $ QueryError "Not Found"
    Left err -> pure $ QueryError (T.pack $ show err)

getLocations :: Pool -> IO (QueryResult [Location])
getLocations pool = do
  let stmt =
        Statement.prepared
          "SELECT id, code::text, name::text, location_type FROM location ORDER BY id"
          E.noParams
          (D.rowList locationRowDecoder)
  res <- use pool $ Session.statement () stmt
  case res of
    Right rows -> pure $ QuerySuccess rows
    Left err -> pure $ QueryError (T.pack $ show err)

getLocationById :: Pool -> Int64 -> IO (QueryResult Location)
getLocationById pool lid = do
  let stmt =
        Statement.prepared
          "SELECT id, code::text, name::text, location_type FROM location WHERE id = $1"
          (E.param (E.nonNullable E.int8))
          (D.rowMaybe locationRowDecoder)
  res <- use pool $ Session.statement lid stmt
  case res of
    Right (Just location) -> pure $ QuerySuccess location
    Right Nothing -> pure $ QueryError "Not Found"
    Left err -> pure $ QueryError (T.pack $ show err)

getBills :: Pool -> IO (QueryResult [Bill])
getBills pool = do
  let stmt =
        Statement.prepared
          "SELECT id, code::text, bill_type, doc_status, doc_date, person_id, location_id, total, discount_amount, tax_amount FROM bill ORDER BY id"
          E.noParams
          (D.rowList billRowDecoder)
  res <- use pool $ Session.statement () stmt
  case res of
    Right rows -> pure $ QuerySuccess rows
    Left err -> pure $ QueryError (T.pack $ show err)

getBillById :: Pool -> Int64 -> IO (QueryResult Bill)
getBillById pool bid = do
  let stmt =
        Statement.prepared
          "SELECT id, code::text, bill_type, doc_status, doc_date, person_id, location_id, total, discount_amount, tax_amount FROM bill WHERE id = $1"
          (E.param (E.nonNullable E.int8))
          (D.rowMaybe billRowDecoder)
  res <- use pool $ Session.statement bid stmt
  case res of
    Right (Just b) -> pure $ QuerySuccess b
    Right Nothing -> pure $ QueryError "Not Found"
    Left err -> pure $ QueryError (T.pack $ show err)

getBillLines :: Pool -> Int64 -> IO (QueryResult [BillLine])
getBillLines pool bid = do
  let stmt =
        Statement.prepared
          "SELECT id, bill_id, goods_id, qtty, price, discount_amount, amount FROM bill_line WHERE bill_id = $1 ORDER BY id"
          (E.param (E.nonNullable E.int8))
          (D.rowList billLineRowDecoder)
  res <- use pool $ Session.statement bid stmt
  case res of
    Right rows -> pure $ QuerySuccess rows
    Left err -> pure $ QueryError (T.pack $ show err)

getStock :: Pool -> Int64 -> Int64 -> IO (QueryResult [Stock])
getStock pool _ _ = getStockAll pool

getStockAll :: Pool -> IO (QueryResult [Stock])
getStockAll pool = do
  let stmt =
        Statement.prepared
          "SELECT id, goods_id, location_id, qtty, resrv_qtty FROM stock ORDER BY id"
          E.noParams
          (D.rowList stockRowDecoder)
  res <- use pool $ Session.statement () stmt
  case res of
    Right rows -> pure $ QuerySuccess rows
    Left err -> pure $ QueryError (T.pack $ show err)

getStockByLocation :: Pool -> Int64 -> IO (QueryResult [Stock])
getStockByLocation pool lid = do
  let stmt =
        Statement.prepared
          "SELECT id, goods_id, location_id, qtty, resrv_qtty FROM stock WHERE location_id = $1"
          (E.param (E.nonNullable E.int8))
          (D.rowList stockRowDecoder)
  res <- use pool $ Session.statement lid stmt
  case res of
    Right rows -> pure $ QuerySuccess rows
    Left err -> pure $ QueryError (T.pack $ show err)

getStockByGoods :: Pool -> Int64 -> IO (QueryResult [Stock])
getStockByGoods pool gid = do
  let stmt =
        Statement.prepared
          "SELECT id, goods_id, location_id, qtty, resrv_qtty FROM stock WHERE goods_id = $1"
          (E.param (E.nonNullable E.int8))
          (D.rowList stockRowDecoder)
  res <- use pool $ Session.statement gid stmt
  case res of
    Right rows -> pure $ QuerySuccess rows
    Left err -> pure $ QueryError (T.pack $ show err)

getSalesSummary :: Pool -> Int64 -> Int64 -> IO (QueryResult [(Day, Decimal)])
getSalesSummary pool daysAgo limit = do
  let sql =
        "SELECT doc_date, SUM(total) as daily_total FROM bill "
          <> "WHERE doc_date >= CURRENT_DATE - make_interval(days => $1) "
          <> "GROUP BY doc_date ORDER BY doc_date DESC LIMIT $2"
      stmt = Statement.prepared sql ((fst >$< E.param (E.nonNullable E.int8)) <> (snd >$< E.param (E.nonNullable E.int8))) (D.rowList dateAmountDecoder)
  res <- use pool $ Session.statement (daysAgo, limit) stmt
  case res of
    Right rows -> pure $ QuerySuccess rows
    Left err -> pure $ QueryError (T.pack $ show err)
  where
    dateAmountDecoder :: D.Row (Day, Decimal)
    dateAmountDecoder = (,) <$> D.column (D.nonNullable D.date) <*> (Decimal . round <$> D.column (D.nonNullable D.numeric))

getUsers :: Pool -> IO (QueryResult [User])
getUsers pool = do
  let stmt =
        Statement.prepared
          "SELECT e.id, e.code::text, e.name::text, e.email::text, ur.role_id, e.status \
          \FROM employee e \
          \LEFT JOIN user_role ur ON e.id = ur.user_id \
          \ORDER BY e.id"
          E.noParams
          (D.rowList userRowDecoder)
  res <- use pool $ Session.statement () stmt
  case res of
    Right rows -> pure $ QuerySuccess rows
    Left err -> pure $ QueryError (T.pack $ show err)

getTopSellingGoods :: Pool -> Int64 -> IO (QueryResult [(Int64, Text, Decimal)])
getTopSellingGoods pool limit = do
  let sql =
        "SELECT g.id, g.name::text, COALESCE(SUM(bl.qtty * bl.price), 0) as total_amount \
        \FROM goods g \
        \LEFT JOIN bill_line bl ON g.id = bl.goods_id \
        \LEFT JOIN bill b ON bl.bill_id = b.id \
        \WHERE b.doc_status = 1 \
        \GROUP BY g.id, g.name \
        \ORDER BY total_amount DESC LIMIT $1"
      stmt = Statement.prepared sql (E.param (E.nonNullable E.int8)) (D.rowList topGoodsDecoder)
  res <- use pool $ Session.statement limit stmt
  case res of
    Right rows -> pure $ QuerySuccess rows
    Left err -> pure $ QueryError (T.pack $ show err)
  where
    topGoodsDecoder :: D.Row (Int64, Text, Decimal)
    topGoodsDecoder =
      (,,)
        <$> D.column (D.nonNullable D.int8)
        <*> D.column (D.nonNullable D.text)
        <*> (Decimal . round <$> D.column (D.nonNullable D.numeric))

inventoryDecoder :: D.Row (Int64, Text, Text, Text, Double, Double, Double)
inventoryDecoder =
  (,,,,,,)
    <$> D.column (D.nonNullable D.int8)
    <*> D.column (D.nonNullable D.text)
    <*> D.column (D.nonNullable D.text)
    <*> D.column (D.nonNullable D.text)
    <*> (realToFrac <$> D.column (D.nonNullable D.numeric))
    <*> (realToFrac <$> D.column (D.nonNullable D.numeric))
    <*> (realToFrac <$> D.column (D.nonNullable D.numeric))

-- | Get document types list
getDocumentTypes :: Pool -> IO (QueryResult [DocumentRegisterType])
getDocumentTypes pool = do
  let stmt =
        Statement.prepared
          "SELECT id, name::text, description::text, flag FROM document_type ORDER BY id"
          E.noParams
          (D.rowList documentTypeRowDecoder)
  res <- use pool $ Session.statement () stmt
  case res of
    Right rows -> pure $ QuerySuccess rows
    Left err -> pure $ QueryError (T.pack $ show err)
  where
    documentTypeRowDecoder :: D.Row DocumentRegisterType
    documentTypeRowDecoder =
      DocumentRegisterType
        <$> D.column (D.nullable D.int8)
        <*> D.column (D.nonNullable D.text)
        <*> D.column (D.nullable D.text)
        <*> (fromIntegral <$> D.column (D.nonNullable D.int4))

-- | Get stock summary (total quantity and value by location/warehouse)
getStockSummary :: Pool -> IO (QueryResult [(Int64, Text, Int, Double, Double)])
getStockSummary pool = do
  let sql =
        "SELECT l.id, l.name::text, COUNT(s.id) as stock_items, "
          <> "COALESCE(SUM(s.quantity), 0) as total_quantity, "
          <> "COALESCE(SUM(s.quantity * s.unit_price), 0) as total_value "
          <> "FROM location l "
          <> "LEFT JOIN stock s ON l.id = s.location_id "
          <> "GROUP BY l.id, l.name "
          <> "ORDER BY l.id"
      stmt = Statement.prepared sql E.noParams (D.rowList stockSummaryDecoder)
  res <- use pool $ Session.statement () stmt
  case res of
    Right rows -> pure $ QuerySuccess rows
    Left err -> pure $ QueryError (T.pack $ show err)
  where
    stockSummaryDecoder :: D.Row (Int64, Text, Int, Double, Double)
    stockSummaryDecoder =
      (,,,,)
        <$> D.column (D.nonNullable D.int8)
        <*> D.column (D.nonNullable D.text)
        <*> (fromIntegral <$> D.column (D.nonNullable D.int4))
        <*> (realToFrac <$> D.column (D.nonNullable D.numeric))
        <*> (realToFrac <$> D.column (D.nonNullable D.numeric))

-- | Get roles list with permissions
getRoles :: Pool -> IO (QueryResult [(Int64, Text, [Text])])
getRoles pool = do
  let sql =
        "SELECT r.id, r.name::text, COALESCE(string_agg(p.name::text, ','), '') as permissions "
          <> "FROM role r "
          <> "LEFT JOIN role_permission rp ON r.id = rp.role_id "
          <> "LEFT JOIN permission p ON rp.permission_id = p.id "
          <> "GROUP BY r.id, r.name "
          <> "ORDER BY r.id"
      stmt = Statement.prepared sql E.noParams (D.rowList rolesDecoder)
  res <- use pool $ Session.statement () stmt
  case res of
    Right rows -> pure $ QuerySuccess rows
    Left err -> pure $ QueryError (T.pack $ show err)
  where
    rolesDecoder :: D.Row (Int64, Text, [Text])
    rolesDecoder =
      (,,)
        <$> D.column (D.nonNullable D.int8)
        <*> D.column (D.nonNullable D.text)
        <*> fmap (maybe [] (splitOn ",")) (D.column (D.nullable D.text)) -- hlint: ignore

-- | Get inventory summary (goods with stock levels)
getInventory :: Pool -> IO (QueryResult [(Int64, Text, Text, Text, Double, Double, Double)])
getInventory pool = do
  let sql =
        "SELECT g.id, g.code::text, g.name::text, u.code::text as unit_code, "
          <> "COALESCE(s.quantity, 0) as quantity, "
          <> "COALESCE(s.average_cost, 0) as average_cost, "
          <> "COALESCE(g.price, 0) as price "
          <> "FROM goods g "
          <> "LEFT JOIN unit u ON g.unit_id = u.id "
          <> "LEFT JOIN (SELECT goods_id, SUM(quantity) as quantity, "
          <> "AVG(unit_cost) as average_cost FROM stock GROUP BY goods_id) s "
          <> "ON g.id = s.goods_id "
          <> "ORDER BY g.id"
      stmt = Statement.prepared sql E.noParams (D.rowList inventoryDecoder)
  res <- use pool $ Session.statement () stmt
  case res of
    Right rows -> pure $ QuerySuccess rows
    Left err -> pure $ QueryError (T.pack $ show err)

-- | Get persons with server-side SQL pagination
getPersonsPaginated :: Pool -> PersonFilter -> Maybe PersonSortBy -> Maybe SortDir -> Pagination -> IO (QueryResult (PaginatedResult Person))
getPersonsPaginated pool filter' mSortBy mSortDir pagination = do
  let sortCol = case mSortBy of
        Just PersonSortByName -> "name"
        Just PersonSortByINN -> "inn"
        _ -> "id"
      sortDir = case mSortDir of
        Just Desc -> "DESC"
        _ -> "ASC"
      limitVal = fromIntegral (pgLimit pagination) :: Int64
      offsetVal = fromIntegral (pgOffset pagination) :: Int64
      nameFilter = pfName filter'
      innFilter = pfINN filter'
      typeFilter = fmap fromIntegral (pfPersonType filter') :: Maybe Int16
      statusFilter = fmap fromIntegral (pfStatus filter') :: Maybe Int16
      whereClause =
        " WHERE ($1 IS NULL OR name ILIKE '%' || $1 || '%')"
          <> " AND ($2 IS NULL OR inn = $2)"
          <> " AND ($3 IS NULL OR person_type = $3)"
          <> " AND ($4 IS NULL OR status = $4)"
      listSql =
        "SELECT id, code::text, name::text, inn::text, kpp::text, person_type, status FROM persons.person"
          <> whereClause
          <> " ORDER BY "
          <> sortCol
          <> " "
          <> sortDir
          <> " LIMIT $5 OFFSET $6"
      countSql = "SELECT COUNT(*) FROM persons.person" <> whereClause
      filterParams =
        ((nameFilter, innFilter, typeFilter, statusFilter, limitVal, offsetVal))
      countFilterParams :: (Maybe Text, Maybe Text, Maybe Int16, Maybe Int16)
      countFilterParams = (nameFilter, innFilter, typeFilter, statusFilter)
      listStmt =
        Statement.prepared
          listSql
          ( ((\(_, _, _, _, _, _) -> Nothing) >$< E.param (E.nullable E.text))
              <> ((\(_, b, _, _, _, _) -> b) >$< E.param (E.nullable E.text))
              <> ((\(_, _, c, _, _, _) -> c) >$< E.param (E.nullable E.int2))
              <> ((\(_, _, _, d, _, _) -> d) >$< E.param (E.nullable E.int2))
              <> ((\(_, _, _, _, e, _) -> e) >$< E.param (E.nonNullable E.int8))
              <> ((\(_, _, _, _, _, f) -> f) >$< E.param (E.nonNullable E.int8))
          )
          (D.rowList personRowDecoder)
      countStmt =
        Statement.prepared
          countSql
          ( ((\(a, _, _, _) -> a) >$< E.param (E.nullable E.text))
              <> ((\(_, b, _, _) -> b) >$< E.param (E.nullable E.text))
              <> ((\(_, _, c, _) -> c) >$< E.param (E.nullable E.int2))
              <> ((\(_, _, _, d) -> d) >$< E.param (E.nullable E.int2))
          )
          (D.singleRow (D.column (D.nonNullable D.int8)))
  listRes <- use pool $ Session.statement filterParams listStmt
  countRes <- use pool $ Session.statement countFilterParams countStmt
  case (listRes, countRes) of
    (Right items, Right totalCount) ->
      pure . QuerySuccess $
        PaginatedResult
          { prItems = items,
            prTotal = totalCount,
            prLimit = pgLimit pagination,
            prOffset = pgOffset pagination
          }
    (Left err, _) -> pure $ QueryError (T.pack $ show err)
    (_, Left err) -> pure $ QueryError (T.pack $ show err)

-- | Get goods with server-side SQL pagination
getGoodsPaginated :: Pool -> GoodsFilter -> Pagination -> Maybe GoodsSortBy -> Maybe SortDir -> IO (QueryResult (PaginatedResult Goods))
getGoodsPaginated pool filter' pagination mSortBy mSortDir = do
  let sortCol = case mSortBy of
        Just GoodsSortByName -> "name"
        Just GoodsSortByCode -> "code"
        _ -> "id"
      sortDir = case mSortDir of
        Just Desc -> "DESC"
        _ -> "ASC"
      limitVal = fromIntegral (pgLimit pagination) :: Int64
      offsetVal = fromIntegral (pgOffset pagination) :: Int64
      nameFilter = gfName filter'
      barcodeFilter = gfBarcode filter'
      codeFilter = gfCode filter'
      whereClause =
        " WHERE ($1 IS NULL OR name ILIKE '%' || $1 || '%')"
          <> " AND ($2 IS NULL OR barcode = $2)"
          <> " AND ($3 IS NULL OR code = $3)"
      listSql =
        "SELECT id, code::text, name::text, barcode::text, unit_id, parent_id FROM goods"
          <> whereClause
          <> " ORDER BY "
          <> sortCol
          <> " "
          <> sortDir
          <> " LIMIT $4 OFFSET $5"
      countSql = "SELECT COUNT(*) FROM goods" <> whereClause
      listParams :: (Maybe Text, Maybe Text, Maybe Text, Int64, Int64)
      listParams = (nameFilter, barcodeFilter, codeFilter, limitVal, offsetVal)
      countParams :: (Maybe Text, Maybe Text, Maybe Text)
      countParams = (nameFilter, barcodeFilter, codeFilter)
      listStmt =
        Statement.prepared
          listSql
          ( ((\(_, _, _, _, _) -> Nothing) >$< E.param (E.nullable E.text))
              <> ((\(_, b, _, _, _) -> b) >$< E.param (E.nullable E.text))
              <> ((\(_, _, c, _, _) -> c) >$< E.param (E.nullable E.text))
              <> ((\(_, _, _, d, _) -> d) >$< E.param (E.nonNullable E.int8))
              <> ((\(_, _, _, _, e) -> e) >$< E.param (E.nonNullable E.int8))
          )
          (D.rowList goodsRowDecoder)
      countStmt =
        Statement.prepared
          countSql
          ( ((\(a, _, _) -> a) >$< E.param (E.nullable E.text))
              <> ((\(_, b, _) -> b) >$< E.param (E.nullable E.text))
              <> ((\(_, _, c) -> c) >$< E.param (E.nullable E.text))
          )
          (D.singleRow (D.column (D.nonNullable D.int8)))
  listRes <- use pool $ Session.statement listParams listStmt
  countRes <- use pool $ Session.statement countParams countStmt
  case (listRes, countRes) of
    (Right items, Right totalCount) ->
      pure . QuerySuccess $
        PaginatedResult
          { prItems = items,
            prTotal = totalCount,
            prLimit = pgLimit pagination,
            prOffset = pgOffset pagination
          }
    (Left err, _) -> pure $ QueryError (T.pack $ show err)
    (_, Left err) -> pure $ QueryError (T.pack $ show err)

-- | Get payments
getPayments :: Pool -> IO (QueryResult [Payment])
getPayments pool = do
  let stmt =
        Statement.prepared
          "SELECT id, bill_id, date, amount, payment_method, payment_status FROM payment ORDER BY date DESC, id DESC"
          E.noParams
          (D.rowList paymentRowDecoder)
  res <- use pool $ Session.statement () stmt
  case res of
    Right rows -> pure $ QuerySuccess rows
    Left err -> pure $ QueryError (T.pack $ show err)

getPaymentById :: Pool -> Int64 -> IO (QueryResult Payment)
getPaymentById pool paymentId = do
  let stmt =
        Statement.prepared
          "SELECT id, bill_id, date, amount, payment_method, payment_status FROM payment WHERE id = $1"
          (E.param (E.nonNullable E.int8))
          (D.rowMaybe paymentRowDecoder)
  res <- use pool $ Session.statement paymentId stmt
  case res of
    Right (Just payment) -> pure $ QuerySuccess payment
    Right Nothing -> pure $ QueryError "Not Found"
    Left err -> pure $ QueryError (T.pack $ show err)

-- | Get units
getUnits :: Pool -> IO (QueryResult [Unit])
getUnits pool = do
  let stmt =
        Statement.prepared
          "SELECT id, code::text, name::text, short_name::text FROM unit ORDER BY id"
          E.noParams
          (D.rowList unitRowDecoder)
  res <- use pool $ Session.statement () stmt
  case res of
    Right rows -> pure $ QuerySuccess rows
    Left err -> pure $ QueryError (T.pack $ show err)

-- | Get taxes
getTaxes :: Pool -> IO (QueryResult [Tax])
getTaxes pool = do
  let stmt =
        Statement.prepared
          "SELECT id, COALESCE(code,'')::text, name::text, rate FROM tax ORDER BY id"
          E.noParams
          (D.rowList taxRowDecoder)
  res <- use pool $ Session.statement () stmt
  case res of
    Right rows -> pure $ QuerySuccess rows
    Left err -> pure $ QueryError (T.pack $ show err)

getTaxById :: Pool -> Int64 -> IO (QueryResult Tax)
getTaxById pool tid = do
  let stmt =
        Statement.prepared
          "SELECT id, COALESCE(code,'')::text, name::text, rate FROM tax WHERE id = $1"
          (E.param (E.nonNullable E.int8))
          (D.rowMaybe taxRowDecoder)
  res <- use pool $ Session.statement tid stmt
  case res of
    Right (Just taxVal) -> pure $ QuerySuccess taxVal
    Right Nothing -> pure $ QueryError "Not Found"
    Left err -> pure $ QueryError (T.pack $ show err)

-- | Get account plans
getAccPlans :: Pool -> IO (QueryResult [AccPlan])
getAccPlans pool = do
  let stmt =
        Statement.prepared
          "SELECT id, code::text, name::text, acc_type FROM acc_plan ORDER BY code"
          E.noParams
          (D.rowList accPlanRowDecoder)
  res <- use pool $ Session.statement () stmt
  case res of
    Right rows -> pure $ QuerySuccess rows
    Left err -> pure $ QueryError (T.pack $ show err)

-- | Get account turns
getAccTurns :: Pool -> IO (QueryResult [AccTurn])
getAccTurns pool = do
  let stmt =
        Statement.prepared
          "SELECT id, bill_id, dbt_acc_id, crd_acc_id, amount, date FROM acc_turn ORDER BY date DESC, id DESC"
          E.noParams
          (D.rowList accTurnRowDecoder)
  res <- use pool $ Session.statement () stmt
  case res of
    Right rows -> pure $ QuerySuccess rows
    Left err -> pure $ QueryError (T.pack $ show err)

-- | Get employees
getEmployees :: Pool -> IO (QueryResult [Employee])
getEmployees pool = do
  let stmt =
        Statement.prepared
          "SELECT id, COALESCE(code,'')::text, COALESCE(name,'')::text, email::text, status FROM employee ORDER BY id"
          E.noParams
          (D.rowList employeeRowDecoder)
  res <- use pool $ Session.statement () stmt
  case res of
    Right rows -> pure $ QuerySuccess rows
    Left err -> pure $ QueryError (T.pack $ show err)

-- | Get salaries
getSalaries :: Pool -> IO (QueryResult [Salary])
getSalaries pool = do
  let stmt =
        Statement.prepared
          "SELECT id, employee_id, period, base_salary, bonus, penalty, tax, net_salary FROM salary ORDER BY period DESC, id DESC"
          E.noParams
          (D.rowList salaryRowDecoder)
  res <- use pool $ Session.statement () stmt
  case res of
    Right rows -> pure $ QuerySuccess rows
    Left err -> pure $ QueryError (T.pack $ show err)

-- | Get report templates
getReports :: Pool -> IO (QueryResult [ReportTemplate])
getReports pool = do
  let stmt =
        Statement.prepared
          "SELECT id, COALESCE(code,'')::text, COALESCE(name,'')::text, report_type, COALESCE(jasper_file,'')::text, COALESCE(output_format,'PDF')::text FROM report_template ORDER BY id"
          E.noParams
          (D.rowList reportTemplateRowDecoder)
  res <- use pool $ Session.statement () stmt
  case res of
    Right rows -> pure $ QuerySuccess rows
    Left err -> pure $ QueryError (T.pack $ show err)

-- | Get bills with server-side SQL pagination
getBillsPaginated :: Pool -> BillFilter -> Pagination -> Maybe BillSortBy -> Maybe SortDir -> IO (QueryResult (PaginatedResult Bill))
getBillsPaginated pool filter' pagination mSortBy mSortDir = do
  let sortCol = case mSortBy of
        Just BillSortByDate -> "doc_date"
        Just BillSortByTotal -> "total"
        _ -> "id"
      sortDir = case mSortDir of
        Just Desc -> "DESC"
        _ -> "ASC"
      limitVal = fromIntegral (pgLimit pagination) :: Int64
      offsetVal = fromIntegral (pgOffset pagination) :: Int64
      typeFilter = fmap fromIntegral (bfBillType filter') :: Maybe Int16
      statusFilter = fmap fromIntegral (bfStatus filter') :: Maybe Int16
      personFilter = bfPersonId filter'
      dateFromFilter = bfDateFrom filter'
      dateToFilter = bfDateTo filter'
      whereClause =
        " WHERE ($1 IS NULL OR bill_type = $1)"
          <> " AND ($2 IS NULL OR doc_status = $2)"
          <> " AND ($3 IS NULL OR person_id = $3)"
          <> " AND ($4 IS NULL OR doc_date >= $4)"
          <> " AND ($5 IS NULL OR doc_date <= $5)"
      listSql =
        "SELECT id, code::text, bill_type, doc_status, doc_date, person_id, location_id, total, discount_amount, tax_amount FROM bill"
          <> whereClause
          <> " ORDER BY "
          <> sortCol
          <> " "
          <> sortDir
          <> " LIMIT $6 OFFSET $7"
      countSql = "SELECT COUNT(*) FROM bill" <> whereClause
      listParams :: (Maybe Int16, Maybe Int16, Maybe Int64, Maybe Day, Maybe Day, Int64, Int64)
      listParams = (typeFilter, statusFilter, personFilter, dateFromFilter, dateToFilter, limitVal, offsetVal)
      countParams :: (Maybe Int16, Maybe Int16, Maybe Int64, Maybe Day, Maybe Day)
      countParams = (typeFilter, statusFilter, personFilter, dateFromFilter, dateToFilter)
      listStmt =
        Statement.prepared
          listSql
          ( ((\(_, _, _, _, _, _, _) -> Nothing) >$< E.param (E.nullable E.int2))
              <> ((\(_, b, _, _, _, _, _) -> b) >$< E.param (E.nullable E.int2))
              <> ((\(_, _, c, _, _, _, _) -> c) >$< E.param (E.nullable E.int8))
              <> ((\(_, _, _, d, _, _, _) -> d) >$< E.param (E.nullable E.date))
              <> ((\(_, _, _, _, e, _, _) -> e) >$< E.param (E.nullable E.date))
              <> ((\(_, _, _, _, _, f, _) -> f) >$< E.param (E.nonNullable E.int8))
              <> ((\(_, _, _, _, _, _, g) -> g) >$< E.param (E.nonNullable E.int8))
          )
          (D.rowList billRowDecoder)
      countStmt =
        Statement.prepared
          countSql
          ( ((\(a, _, _, _, _) -> a) >$< E.param (E.nullable E.int2))
              <> ((\(_, b, _, _, _) -> b) >$< E.param (E.nullable E.int2))
              <> ((\(_, _, c, _, _) -> c) >$< E.param (E.nullable E.int8))
              <> ((\(_, _, _, d, _) -> d) >$< E.param (E.nullable E.date))
              <> ((\(_, _, _, _, e) -> e) >$< E.param (E.nullable E.date))
          )
          (D.singleRow (D.column (D.nonNullable D.int8)))
  listRes <- use pool $ Session.statement listParams listStmt
  countRes <- use pool $ Session.statement countParams countStmt
  case (listRes, countRes) of
    (Right items, Right totalCount) ->
      pure . QuerySuccess $
        PaginatedResult
          { prItems = items,
            prTotal = totalCount,
            prLimit = pgLimit pagination,
            prOffset = pgOffset pagination
          }
    (Left err, _) -> pure $ QueryError (T.pack $ show err)
    (_, Left err) -> pure $ QueryError (T.pack $ show err)

-- | Get payments by bill
getPaymentsByBill :: Pool -> Int64 -> IO (QueryResult [Payment])
getPaymentsByBill pool billId = do
  let stmt =
        Statement.prepared
          "SELECT id, bill_id, date, amount, payment_method, payment_status FROM payment WHERE bill_id = $1 ORDER BY date DESC, id DESC"
          (E.param (E.nonNullable E.int8))
          (D.rowList paymentRowDecoder)
  res <- use pool $ Session.statement billId stmt
  case res of
    Right rows -> pure $ QuerySuccess rows
    Left err -> pure $ QueryError (T.pack $ show err)

-- | Get low stock goods
getLowStockGoods :: Pool -> IO (QueryResult [(Int64, Text, Decimal, Decimal)])
getLowStockGoods pool = do
  let stmt =
        Statement.prepared
          "SELECT g.id, g.name::text, COALESCE(SUM(s.qtty), 0), COALESCE(g.min_stock, 0) FROM goods g LEFT JOIN stock s ON s.goods_id = g.id GROUP BY g.id, g.name, g.min_stock HAVING COALESCE(SUM(s.qtty), 0) <= COALESCE(g.min_stock, 0) ORDER BY g.id"
          E.noParams
          (D.rowList lowStockDecoder)
  res <- use pool $ Session.statement () stmt
  case res of
    Right rows -> pure $ QuerySuccess rows
    Left err -> pure $ QueryError (T.pack $ show err)
  where
    lowStockDecoder :: D.Row (Int64, Text, Decimal, Decimal)
    lowStockDecoder =
      (,,,)
        <$> D.column (D.nonNullable D.int8)
        <*> D.column (D.nonNullable D.text)
        <*> (Decimal . round <$> D.column (D.nonNullable D.numeric))
        <*> (Decimal . round <$> D.column (D.nonNullable D.numeric))

-- | Get inventory documents
getInventoryDocuments :: Pool -> IO (QueryResult [Bill])
getInventoryDocuments = getBills

-- | Get dashboard stats
getDashboardStats :: Pool -> IO (QueryResult DashboardStats)
getDashboardStats pool = do
  let stmt =
        Statement.prepared
          "SELECT COALESCE((SELECT SUM(total)::bigint FROM bill WHERE doc_date = CURRENT_DATE), 0)::bigint, COALESCE((SELECT COUNT(*) FROM order_head WHERE doc_date = CURRENT_DATE), 0)::bigint, COALESCE((SELECT COUNT(*) FROM goods), 0)::bigint, COALESCE((SELECT COUNT(*) FROM persons.person), 0)::bigint"
          E.noParams
          (D.singleRow dashboardStatsRowDecoder)
  res <- use pool $ Session.statement () stmt
  case res of
    Right stats -> pure $ QuerySuccess stats
    Left err -> pure $ QueryError (T.pack $ show err)

-- | Get account plan by ID
getAccPlanById :: Pool -> Int64 -> IO (QueryResult AccPlan)
getAccPlanById pool planId = do
  let stmt =
        Statement.prepared
          "SELECT id, code::text, name::text, acc_type FROM acc_plan WHERE id = $1"
          (E.param (E.nonNullable E.int8))
          (D.rowMaybe accPlanRowDecoder)
  res <- use pool $ Session.statement planId stmt
  case res of
    Right (Just accPlan) -> pure $ QuerySuccess accPlan
    Right Nothing -> pure $ QueryError "Not Found"
    Left err -> pure $ QueryError (T.pack $ show err)

-- | Get employee by ID
getEmployeeById :: Pool -> Int64 -> IO (QueryResult Employee)
getEmployeeById pool employeeId = do
  let stmt =
        Statement.prepared
          "SELECT id, COALESCE(code,'')::text, COALESCE(name,'')::text, email::text, status FROM employee WHERE id = $1"
          (E.param (E.nonNullable E.int8))
          (D.rowMaybe employeeRowDecoder)
  res <- use pool $ Session.statement employeeId stmt
  case res of
    Right (Just employee) -> pure $ QuerySuccess employee
    Right Nothing -> pure $ QueryError "Not Found"
    Left err -> pure $ QueryError (T.pack $ show err)

-- | Get salary by employee ID
getSalaryByEmployee :: Pool -> Int64 -> IO (QueryResult [Salary])
getSalaryByEmployee pool employeeId = do
  let stmt =
        Statement.prepared
          "SELECT id, employee_id, period, base_salary, bonus, penalty, tax, net_salary FROM salary WHERE employee_id = $1 ORDER BY period DESC, id DESC"
          (E.param (E.nonNullable E.int8))
          (D.rowList salaryRowDecoder)
  res <- use pool $ Session.statement employeeId stmt
  case res of
    Right rows -> pure $ QuerySuccess rows
    Left err -> pure $ QueryError (T.pack $ show err)

-- | Get report template by ID
getReportById :: Pool -> Int64 -> IO (QueryResult ReportTemplate)
getReportById pool reportId = do
  let stmt =
        Statement.prepared
          "SELECT id, COALESCE(code,'')::text, COALESCE(name,'')::text, report_type, COALESCE(jasper_file,'')::text, COALESCE(output_format,'PDF')::text FROM report_template WHERE id = $1"
          (E.param (E.nonNullable E.int8))
          (D.rowMaybe reportTemplateRowDecoder)
  res <- use pool $ Session.statement reportId stmt
  case res of
    Right (Just reportTemplate) -> pure $ QuerySuccess reportTemplate
    Right Nothing -> pure $ QueryError "Not Found"
    Left err -> pure $ QueryError (T.pack $ show err)

-- | Get all orders
getOrders :: Pool -> IO (QueryResult [Order])
getOrders pool = do
  let stmt =
        Statement.prepared
          "SELECT id, code::text, name::text, doc_date, person_id, location_id, doc_status, total, discount_amount, tax_amount FROM order_head ORDER BY doc_date DESC, id DESC"
          E.noParams
          (D.rowList orderRowDecoder)
  res <- use pool $ Session.statement () stmt
  case res of
    Right rows -> pure $ QuerySuccess rows
    Left err -> pure $ QueryError (T.pack (show err))

-- | Get orders with pagination
getOrdersPaginated :: Pool -> OrderFilter -> Pagination -> Maybe OrderSortBy -> Maybe SortDir -> IO (QueryResult (PaginatedResult Order))
getOrdersPaginated pool orderFilter pagination _ _ = do
  let params =
        ( fmap (fromIntegral :: Int -> Int16) (ofStatus orderFilter),
          ofPersonId orderFilter,
          ofDateFrom orderFilter,
          ofDateTo orderFilter,
          fromIntegral (pgLimit pagination) :: Int64,
          fromIntegral (pgOffset pagination) :: Int64
        )
      listStmt =
        Statement.prepared
          "SELECT id, code::text, name::text, doc_date, person_id, location_id, doc_status, total, discount_amount, tax_amount FROM order_head WHERE ($1 IS NULL OR doc_status = $1) AND ($2 IS NULL OR person_id = $2) AND ($3 IS NULL OR doc_date >= $3) AND ($4 IS NULL OR doc_date <= $4) ORDER BY doc_date DESC, id DESC LIMIT $5 OFFSET $6"
          ( ((\(status, _, _, _, _, _) -> status) >$< E.param (E.nullable E.int2))
              <> ((\(_, personId, _, _, _, _) -> personId) >$< E.param (E.nullable E.int8))
              <> ((\(_, _, dateFrom, _, _, _) -> dateFrom) >$< E.param (E.nullable E.date))
              <> ((\(_, _, _, dateTo, _, _) -> dateTo) >$< E.param (E.nullable E.date))
              <> ((\(_, _, _, _, limit, _) -> limit) >$< E.param (E.nonNullable E.int8))
              <> ((\(_, _, _, _, _, offset) -> offset) >$< E.param (E.nonNullable E.int8))
          )
          (D.rowList orderRowDecoder)
      countStmt =
        Statement.prepared
          "SELECT COUNT(*) FROM order_head WHERE ($1 IS NULL OR doc_status = $1) AND ($2 IS NULL OR person_id = $2) AND ($3 IS NULL OR doc_date >= $3) AND ($4 IS NULL OR doc_date <= $4)"
          ( ((\(status, _, _, _) -> status) >$< E.param (E.nullable E.int2))
              <> ((\(_, personId, _, _) -> personId) >$< E.param (E.nullable E.int8))
              <> ((\(_, _, dateFrom, _) -> dateFrom) >$< E.param (E.nullable E.date))
              <> ((\(_, _, _, dateTo) -> dateTo) >$< E.param (E.nullable E.date))
          )
          (D.singleRow (D.column (D.nonNullable D.int8)))
  listRes <- use pool $ Session.statement params listStmt
  countRes <-
    use pool $ Session.statement (fmap (fromIntegral :: Int -> Int16) (ofStatus orderFilter), ofPersonId orderFilter, ofDateFrom orderFilter, ofDateTo orderFilter) countStmt
  case (listRes, countRes) of
    (Right items, Right totalCount) ->
      pure . QuerySuccess $
        PaginatedResult
          { prItems = items,
            prTotal = totalCount,
            prLimit = pgLimit pagination,
            prOffset = pgOffset pagination
          }
    (Left err, _) -> pure $ QueryError (T.pack (show err))
    (_, Left err) -> pure $ QueryError (T.pack (show err))

-- | Get order by ID
getOrderById :: Pool -> Int64 -> IO (QueryResult Order)
getOrderById pool orderId = do
  let stmt =
        Statement.prepared
          "SELECT id, code::text, name::text, doc_date, person_id, location_id, doc_status, total, discount_amount, tax_amount FROM order_head WHERE id = $1"
          (E.param (E.nonNullable E.int8))
          (D.rowMaybe orderRowDecoder)
  res <- use pool $ Session.statement orderId stmt
  case res of
    Right (Just orderVal) -> pure $ QuerySuccess orderVal
    Right Nothing -> pure $ QueryError "Not Found"
    Left err -> pure $ QueryError (T.pack (show err))

-- | Get order lines
getOrderLines :: Pool -> Int64 -> IO (QueryResult [Text])
getOrderLines pool orderId = do
  let stmt =
        Statement.prepared
          "SELECT id::text FROM order_line WHERE order_id = $1 ORDER BY id"
          (E.param (E.nonNullable E.int8))
          (D.rowList (D.column (D.nonNullable D.text)))
  res <- use pool $ Session.statement orderId stmt
  case res of
    Right rows -> pure $ QuerySuccess rows
    Left err -> pure $ QueryError (T.pack $ show err)

-- | Get goods prices
getGoodsPrices :: Pool -> IO (QueryResult [GoodsPrice])
getGoodsPrices pool = do
  let stmt =
        Statement.prepared
          "SELECT id, goods_id, price_type, price, min_qtty, valid_from, valid_to FROM goods_price ORDER BY id"
          E.noParams
          (D.rowList goodsPriceRowDecoder)
  res <- use pool $ Session.statement () stmt
  case res of
    Right rows -> pure $ QuerySuccess rows
    Left err -> pure $ QueryError (T.pack $ show err)

-- | Get goods price by goods ID
getGoodsPriceByGoods :: Pool -> Int64 -> IO (QueryResult [GoodsPrice])
getGoodsPriceByGoods pool goodsId = do
  let stmt =
        Statement.prepared
          "SELECT id, goods_id, price_type, price, min_qtty, valid_from, valid_to FROM goods_price WHERE goods_id = $1 ORDER BY id"
          (E.param (E.nonNullable E.int8))
          (D.rowList goodsPriceRowDecoder)
  res <- use pool $ Session.statement goodsId stmt
  case res of
    Right rows -> pure $ QuerySuccess rows
    Left err -> pure $ QueryError (T.pack $ show err)

getGoodsPriceById :: Pool -> Int64 -> IO (QueryResult GoodsPrice)
getGoodsPriceById pool priceId = do
  let stmt =
        Statement.prepared
          "SELECT id, goods_id, price_type, price, min_qtty, valid_from, valid_to FROM goods_price WHERE id = $1"
          (E.param (E.nonNullable E.int8))
          (D.rowMaybe goodsPriceRowDecoder)
  res <- use pool $ Session.statement priceId stmt
  case res of
    Right (Just priceVal) -> pure $ QuerySuccess priceVal
    Right Nothing -> pure $ QueryError "Not Found"
    Left err -> pure $ QueryError (T.pack $ show err)

-- | Get document operation kinds
getDocumentOpKinds :: Pool -> IO (QueryResult [DocumentRegisterType])
getDocumentOpKinds = getDocumentTypes

-- | Get currencies
getCurrencies :: Pool -> IO (QueryResult [Currency])
getCurrencies pool = do
  let stmt =
        Statement.prepared
          "SELECT id, code::text, name::text, COALESCE(symbol,'')::text, rate_to_base, is_base FROM currency ORDER BY is_base DESC, code"
          E.noParams
          (D.rowList currencyRowDecoder)
  res <- use pool $ Session.statement () stmt
  case res of
    Right rows -> pure $ QuerySuccess rows
    Left err -> pure $ QueryError (T.pack $ show err)

getCurrencyById :: Pool -> Int64 -> IO (QueryResult Currency)
getCurrencyById pool currencyId = do
  let stmt =
        Statement.prepared
          "SELECT id, code::text, name::text, COALESCE(symbol,'')::text, rate_to_base, is_base FROM currency WHERE id = $1"
          (E.param (E.nonNullable E.int8))
          (D.rowMaybe currencyRowDecoder)
  res <- use pool $ Session.statement currencyId stmt
  case res of
    Right (Just currency) -> pure $ QuerySuccess currency
    Right Nothing -> pure $ QueryError "Not Found"
    Left err -> pure $ QueryError (T.pack $ show err)

-- | Get accounting turn by id
getAccTurnById :: Pool -> Int64 -> IO (QueryResult AccTurn)
getAccTurnById pool turnId = do
  let stmt =
        Statement.prepared
          "SELECT id, bill_id, dbt_acc_id, crd_acc_id, amount, date FROM acc_turn WHERE id = $1"
          (E.param (E.nonNullable E.int8))
          (D.rowMaybe accTurnRowDecoder)
  res <- use pool $ Session.statement turnId stmt
  case res of
    Right (Just turn) -> pure $ QuerySuccess turn
    Right Nothing -> pure $ QueryError "Not Found"
    Left err -> pure $ QueryError (T.pack $ show err)
