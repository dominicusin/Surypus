{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module DAL.Queries where

import Core.Document.Types (DocumentRegisterType (..))
import DAL.Types
import Data.Functor.Contravariant ((>$<))
import Data.Int (Int64)
import Data.Maybe (fromJust, isJust)
import Data.Text (Text, splitOn)
import qualified Data.Text as T
import Data.Time (Day)
import qualified Domain.Goods
import qualified Hasql.Decoders as D
import qualified Hasql.Encoders as E
import Hasql.Pool (Pool, use)
import qualified Hasql.Session as Session
import Hasql.Statement (unpreparable)
import Surypus.RBAC (EntityType (..), Permission (..), Role (..), UserWithRole (..), defaultRoles, hasPermission)
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
    Right rows -> pure $ QuerySuccess rows
    Left err -> pure $ QueryError (T.pack $ show err)

searchPersons :: Pool -> Text -> IO (QueryResult [Person])
searchPersons pool query = do
  let stmt =
        unpreparable
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
        unpreparable
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
        unpreparable
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
        unpreparable
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
        unpreparable
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
        unpreparable
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
        unpreparable
          "SELECT id, code::text, name::text, location_type FROM location ORDER BY id"
          E.noParams
          (D.rowList locationRowDecoder)
  res <- use pool $ Session.statement () stmt
  case res of
    Right rows -> pure $ QuerySuccess rows
    Left err -> pure $ QueryError (T.pack $ show err)

getBills :: Pool -> IO (QueryResult [Bill])
getBills pool = do
  let stmt =
        unpreparable
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
        unpreparable
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
        unpreparable
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
        unpreparable
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
        unpreparable
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
        unpreparable
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
          <> "WHERE doc_date >= CURRENT_DATE - ($1 || ' days')::interval "
          <> "GROUP BY doc_date ORDER BY doc_date DESC LIMIT $2"
      stmt = unpreparable sql ((fst >$< E.param (E.nonNullable E.int8)) <> (snd >$< E.param (E.nonNullable E.int8))) (D.rowList dateAmountDecoder)
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
        unpreparable
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
        unpreparable
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
      stmt = unpreparable sql E.noParams (D.rowList stockSummaryDecoder)
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
      stmt = unpreparable sql E.noParams (D.rowList rolesDecoder)
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
        <*> fmap (maybe [] (splitOn ",")) (D.column (D.nullable D.text))

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
      stmt = unpreparable sql E.noParams (D.rowList inventoryDecoder)
  res <- use pool $ Session.statement () stmt
  case res of
    Right rows -> pure $ QuerySuccess rows
    Left err -> pure $ QueryError (T.pack $ show err)
  where
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

-- | Get persons with pagination (simplified implementation)
getPersonsPaginated :: Pool -> PersonFilter -> Maybe PersonSortBy -> Maybe SortDir -> Pagination -> IO (QueryResult (PaginatedResult Person))
getPersonsPaginated pool _ _ _ pagination = do
  result <- getPersons pool
  case result of
    QuerySuccess persons ->
      pure $
        QuerySuccess $
          PaginatedResult
            { prItems = persons,
              prTotal = fromIntegral (length persons),
              prLimit = pgLimit pagination,
              prOffset = pgOffset pagination
            }
    QueryError err -> pure $ QueryError err

-- | Get goods with pagination (simplified implementation)
getGoodsPaginated :: Pool -> GoodsFilter -> Pagination -> Maybe GoodsSortBy -> Maybe SortDir -> IO (QueryResult (PaginatedResult Goods))
getGoodsPaginated pool _ pagination _ _ = do
  result <- getGoods pool
  case result of
    QuerySuccess items ->
      pure $
        QuerySuccess $
          PaginatedResult
            { prItems = items,
              prTotal = fromIntegral (length items),
              prLimit = pgLimit pagination,
              prOffset = pgOffset pagination
            }
    QueryError err -> pure $ QueryError err

-- | Get payments (stub implementation)
getPayments :: Pool -> IO (QueryResult [Text])
getPayments _ = pure $ QuerySuccess []

-- | Get units (stub implementation)
getUnits :: Pool -> IO (QueryResult [Text])
getUnits _ = pure $ QuerySuccess []

-- | Get taxes (stub implementation)
getTaxes :: Pool -> IO (QueryResult [Text])
getTaxes _ = pure $ QuerySuccess []

-- | Get account plans (stub implementation)
getAccPlans :: Pool -> IO (QueryResult [Text])
getAccPlans _ = pure $ QuerySuccess []

-- | Get account turns (stub implementation)
getAccTurns :: Pool -> IO (QueryResult [Text])
getAccTurns _ = pure $ QuerySuccess []

-- | Get employees (stub implementation)
getEmployees :: Pool -> IO (QueryResult [Text])
getEmployees _ = pure $ QuerySuccess []

-- | Get salaries (stub implementation)
getSalaries :: Pool -> IO (QueryResult [Text])
getSalaries _ = pure $ QuerySuccess []

-- | Get reports (stub implementation)
getReports :: Pool -> IO (QueryResult [Text])
getReports _ = pure $ QuerySuccess []

-- | Get bills with pagination (stub implementation)
getBillsPaginated :: Pool -> BillFilter -> Pagination -> Maybe BillSortBy -> Maybe SortDir -> IO (QueryResult (PaginatedResult Bill))
getBillsPaginated pool _ pagination _ _ = do
  result <- getBills pool
  case result of
    QuerySuccess items ->
      pure $
        QuerySuccess $
          PaginatedResult
            { prItems = items,
              prTotal = fromIntegral (length items),
              prLimit = pgLimit pagination,
              prOffset = pgOffset pagination
            }
    QueryError err -> pure $ QueryError err

-- | Get payments by bill (stub implementation)
getPaymentsByBill :: Pool -> Int64 -> IO (QueryResult [Text])
getPaymentsByBill _ _ = pure $ QuerySuccess []

-- | Get low stock goods (stub implementation)
getLowStockGoods :: Pool -> IO (QueryResult [(Int64, Text, Decimal, Decimal)])
getLowStockGoods _ = pure $ QuerySuccess []

-- | Get inventory documents (stub implementation)
getInventoryDocuments :: Pool -> IO (QueryResult [Text])
getInventoryDocuments _ = pure $ QuerySuccess []

-- | Get dashboard stats (stub implementation)
getDashboardStats :: Pool -> IO (QueryResult Text)
getDashboardStats _ = pure $ QuerySuccess ""

-- | Get account plan by ID (stub implementation)
getAccPlanById :: Pool -> Int64 -> IO (QueryResult Text)
getAccPlanById _ _ = pure $ QuerySuccess ""

-- | Get employee by ID (stub implementation)
getEmployeeById :: Pool -> Int64 -> IO (QueryResult Text)
getEmployeeById _ _ = pure $ QuerySuccess ""

-- | Get salary by employee ID (stub implementation)
getSalaryByEmployee :: Pool -> Int64 -> IO (QueryResult [Text])
getSalaryByEmployee _ _ = pure $ QuerySuccess []

-- | Get report by ID (stub implementation)
getReportById :: Pool -> Int64 -> IO (QueryResult Text)
getReportById _ _ = pure $ QuerySuccess ""

-- | Get orders with pagination (stub implementation)
getOrdersPaginated :: Pool -> OrderFilter -> Pagination -> Maybe OrderSortBy -> Maybe SortDir -> IO (QueryResult (PaginatedResult Text))
getOrdersPaginated _ _ pagination _ _ = pure $ QuerySuccess (PaginatedResult [] 0 (pgLimit pagination) (pgOffset pagination))

-- | Get order by ID (stub implementation)
getOrderById :: Pool -> Int64 -> IO (QueryResult Text)
getOrderById _ _ = pure $ QuerySuccess ""

-- | Get order lines (stub implementation)
getOrderLines :: Pool -> Int64 -> IO (QueryResult [Text])
getOrderLines _ _ = pure $ QuerySuccess []

-- | Get goods prices (stub implementation)
getGoodsPrices :: Pool -> IO (QueryResult [Text])
getGoodsPrices _ = pure $ QuerySuccess []

-- | Get goods price by goods ID (stub implementation)
getGoodsPriceByGoods :: Pool -> Int64 -> IO (QueryResult [Text])
getGoodsPriceByGoods _ _ = pure $ QuerySuccess []

-- | Get document operation kinds (stub implementation)
getDocumentOpKinds :: Pool -> IO (QueryResult [Text])
getDocumentOpKinds _ = pure $ QuerySuccess []

-- | Get currencies
getCurrencies :: Pool -> IO (QueryResult [Currency])
getCurrencies pool = do
  let stmt =
        unpreparable
          "SELECT id, code::text, name::text, COALESCE(symbol,'')::text, rate_to_base, is_base FROM currency ORDER BY is_base DESC, code"
          E.noParams
          (D.rowList currencyRowDecoder)
  res <- use pool $ Session.statement () stmt
  case res of
    Right rows -> pure $ QuerySuccess rows
    Left err -> pure $ QueryError (T.pack $ show err)
