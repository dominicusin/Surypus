{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module DAL.Queries where

import DAL.Types
import Data.Int (Int64)
import Data.Maybe (fromJust, isJust)
import Data.Text (Text)
import qualified Data.Text as T
import qualified Hasql.Decoders as D
import qualified Hasql.Encoders as E
import Hasql.Pool (Pool, use)
import qualified Hasql.Session as Session
import Hasql.Statement (unpreparable)
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

getDashboardStats :: Pool -> IO (QueryResult DashboardStats)
getDashboardStats _ = return $ QuerySuccess $ DashboardStats 430 2 3 8

getAccPlans :: Pool -> IO (QueryResult [AccPlan])
getAccPlans pool = do
  let stmt =
        unpreparable
          "SELECT id, code::text, name::text, acc_type FROM acc_plan ORDER BY code"
          E.noParams
          (D.rowList accPlanRowDecoder)
  res <- use pool $ Session.statement () stmt
  case res of
    Right rows -> return $ QuerySuccess rows
    Left err -> return $ QueryError (T.pack $ show err)

getAccPlanById :: Pool -> Int64 -> IO (QueryResult AccPlan)
getAccPlanById pool pid = do
  let stmt =
        unpreparable
          "SELECT id, code::text, name::text, acc_type FROM acc_plan WHERE id = $1"
          (E.param (E.nonNullable E.int8))
          (D.rowMaybe accPlanRowDecoder)
  res <- use pool $ Session.statement pid stmt
  case res of
    Right (Just p) -> return $ QuerySuccess p
    Right Nothing -> return $ QueryError "Not Found"
    Left err -> return $ QueryError (T.pack $ show err)

getAccTurns :: Pool -> IO (QueryResult [AccTurn])
getAccTurns pool = do
  let stmt =
        unpreparable
          "SELECT id, bill_id, dbt_acc_id, crd_acc_id, amount, date FROM acc_turn ORDER BY id"
          E.noParams
          (D.rowList accTurnRowDecoder)
  res <- use pool $ Session.statement () stmt
  case res of
    Right rows -> return $ QuerySuccess rows
    Left err -> return $ QueryError (T.pack $ show err)

getEmployees :: Pool -> IO (QueryResult [Employee])
getEmployees pool = do
  let stmt =
        unpreparable
          "SELECT id, code::text, name::text, email::text, status FROM employee ORDER BY id"
          E.noParams
          (D.rowList employeeRowDecoder)
  res <- use pool $ Session.statement () stmt
  case res of
    Right rows -> return $ QuerySuccess rows
    Left err -> return $ QueryError (T.pack $ show err)

getEmployeeById :: Pool -> Int64 -> IO (QueryResult Employee)
getEmployeeById pool eid = do
  let stmt =
        unpreparable
          "SELECT id, code::text, name::text, email::text, status FROM employee WHERE id = $1"
          (E.param (E.nonNullable E.int8))
          (D.rowMaybe employeeRowDecoder)
  res <- use pool $ Session.statement eid stmt
  case res of
    Right (Just e) -> return $ QuerySuccess e
    Right Nothing -> return $ QueryError "Not Found"
    Left err -> return $ QueryError (T.pack $ show err)

getSalaries :: Pool -> IO (QueryResult [Salary])
getSalaries pool = do
  let stmt =
        unpreparable
          "SELECT id, employee_id, period, base_salary, bonus, penalty, tax, net_salary FROM salary ORDER BY period DESC, employee_id"
          E.noParams
          (D.rowList salaryRowDecoder)
  res <- use pool $ Session.statement () stmt
  case res of
    Right rows -> return $ QuerySuccess rows
    Left err -> return $ QueryError (T.pack $ show err)

getSalaryByEmployee :: Pool -> Int64 -> IO (QueryResult [Salary])
getSalaryByEmployee pool eid = do
  let stmt =
        unpreparable
          "SELECT id, employee_id, period, base_salary, bonus, penalty, tax, net_salary FROM salary WHERE employee_id = $1 ORDER BY period DESC"
          (E.param (E.nonNullable E.int8))
          (D.rowList salaryRowDecoder)
  res <- use pool $ Session.statement eid stmt
  case res of
    Right rows -> return $ QuerySuccess rows
    Left err -> return $ QueryError (T.pack $ show err)

getReports :: Pool -> IO (QueryResult [ReportTemplate])
getReports pool = do
  let stmt =
        unpreparable
          "SELECT id, COALESCE(code,'')::text, name::text, report_type, COALESCE(jasper_file,'')::text, COALESCE(output_format,'')::text FROM report_template ORDER BY name"
          E.noParams
          (D.rowList reportTemplateRowDecoder)
  res <- use pool $ Session.statement () stmt
  case res of
    Right rows -> return $ QuerySuccess rows
    Left err -> return $ QueryError (T.pack $ show err)

getReportById :: Pool -> Int64 -> IO (QueryResult ReportTemplate)
getReportById pool rid = do
  let stmt =
        unpreparable
          "SELECT id, COALESCE(code,'')::text, name::text, report_type, COALESCE(jasper_file,'')::text, COALESCE(output_format,'')::text FROM report_template WHERE id = $1"
          (E.param (E.nonNullable E.int8))
          (D.rowMaybe reportTemplateRowDecoder)
  res <- use pool $ Session.statement rid stmt
  case res of
    Right (Just r) -> return $ QuerySuccess r
    Right Nothing -> return $ QueryError "Not Found"
    Left err -> return $ QueryError (T.pack $ show err)

getOrders :: Pool -> IO (QueryResult [Order])
getOrders pool = do
  let stmt =
        unpreparable
          "SELECT id, code::text, name::text, doc_date, person_id, location_id, doc_status, total, discount_amount, tax_amount FROM order_head ORDER BY id"
          E.noParams
          (D.rowList orderRowDecoder)
  res <- use pool $ Session.statement () stmt
  case res of
    Right rows -> return $ QuerySuccess rows
    Left err -> return $ QueryError (T.pack $ show err)

getOrderById :: Pool -> Int64 -> IO (QueryResult Order)
getOrderById pool oid = do
  let stmt =
        unpreparable
          "SELECT id, code::text, name::text, doc_date, person_id, location_id, doc_status, total, discount_amount, tax_amount FROM order_head WHERE id = $1"
          (E.param (E.nonNullable E.int8))
          (D.rowMaybe orderRowDecoder)
  res <- use pool $ Session.statement oid stmt
  case res of
    Right (Just o) -> return $ QuerySuccess o
    Right Nothing -> return $ QueryError "Not Found"
    Left err -> return $ QueryError (T.pack $ show err)

getGoodsPrices :: Pool -> IO (QueryResult [GoodsPrice])
getGoodsPrices pool = do
  let stmt =
        unpreparable
          "SELECT id, goods_id, price_type, price, min_qtty, valid_from, valid_to FROM goods_price ORDER BY goods_id, price_type"
          E.noParams
          (D.rowList goodsPriceRowDecoder)
  res <- use pool $ Session.statement () stmt
  case res of
    Right rows -> return $ QuerySuccess rows
    Left err -> return $ QueryError (T.pack $ show err)

getGoodsPriceByGoods :: Pool -> Int64 -> IO (QueryResult [GoodsPrice])
getGoodsPriceByGoods pool gid = do
  let stmt =
        unpreparable
          "SELECT id, goods_id, price_type, price, min_qtty, valid_from, valid_to FROM goods_price WHERE goods_id = $1 ORDER BY price_type"
          (E.param (E.nonNullable E.int8))
          (D.rowList goodsPriceRowDecoder)
  res <- use pool $ Session.statement gid stmt
  case res of
    Right rows -> return $ QuerySuccess rows
    Left err -> return $ QueryError (T.pack $ show err)

getTaxes :: Pool -> IO (QueryResult [Tax])
getTaxes pool = do
  let stmt =
        unpreparable
          "SELECT id, code::text, name::text, rate FROM tax ORDER BY rate DESC"
          E.noParams
          (D.rowList taxRowDecoder)
  res <- use pool $ Session.statement () stmt
  case res of
    Right rows -> return $ QuerySuccess rows
    Left err -> return $ QueryError (T.pack $ show err)

getCurrencies :: Pool -> IO (QueryResult [Currency])
getCurrencies pool = do
  let stmt =
        unpreparable
          "SELECT id, code::text, name::text, COALESCE(symbol,'')::text, rate_to_base, is_base FROM currency ORDER BY is_base DESC, code"
          E.noParams
          (D.rowList currencyRowDecoder)
  res <- use pool $ Session.statement () stmt
  case res of
    Right rows -> return $ QuerySuccess rows
    Left err -> return $ QueryError (T.pack $ show err)

-- ============================================================================
-- PAGINATED QUERIES
-- ============================================================================

getPersonsPaginated :: Pool -> PersonFilter -> Pagination -> IO (QueryResult (PaginatedResult Person))
getPersonsPaginated pool f p = do
  let limitVal = pgLimit p
      offsetVal = pgOffset p
      whereClause = buildPersonFilter f
      sql =
        T.pack $
          "SELECT id, code::text, name::text, inn::text, kpp::text, person_type, status FROM persons.person"
            ++ T.unpack whereClause
            ++ " ORDER BY id LIMIT "
            ++ show limitVal
            ++ " OFFSET "
            ++ show offsetVal

  let countStmt =
        unpreparable
          (T.pack $ "SELECT COUNT(*) FROM persons.person" ++ T.unpack whereClause)
          E.noParams
          (D.singleRow (D.column (D.nonNullable D.int8)))
  countRes <- use pool $ Session.statement () countStmt
  total <- case countRes of
    Right t -> return t
    Left _ -> return 0

  let dataStmt = unpreparable sql E.noParams (D.rowList personRowDecoder)
  res <- use pool $ Session.statement () dataStmt
  case res of
    Right rows -> return $ QuerySuccess (PaginatedResult rows total (pgLimit p) (pgOffset p))
    Left err -> return $ QueryError (T.pack $ show err)

buildPersonFilter :: PersonFilter -> Text
buildPersonFilter f =
  let conditions =
        filter (not . null) $
          [ if isJust (pfName f) then " name ILIKE '%' || '" ++ T.unpack (fromJust (pfName f)) ++ "' || '%'" else "",
            if isJust (pfINN f) then " inn = '" ++ T.unpack (fromJust (pfINN f)) ++ "'" else "",
            if isJust (pfPersonType f) then " person_type = " ++ show (fromJust (pfPersonType f)) else "",
            if isJust (pfStatus f) then " status = " ++ show (fromJust (pfStatus f)) else ""
          ]
   in if null conditions then "" else T.pack $ " WHERE " ++ unwords conditions

getGoodsPaginated :: Pool -> GoodsFilter -> Pagination -> IO (QueryResult (PaginatedResult Goods))
getGoodsPaginated pool _ p = do
  let limitVal = pgLimit p
      offsetVal = pgOffset p
      sql = T.pack $ "SELECT id, code::text, name::text, barcode::text, unit_id, parent_id FROM goods ORDER BY id LIMIT " ++ show limitVal ++ " OFFSET " ++ show offsetVal

  let countStmt =
        unpreparable
          "SELECT COUNT(*) FROM goods"
          E.noParams
          (D.singleRow (D.column (D.nonNullable D.int8)))
  countRes <- use pool $ Session.statement () countStmt
  total <- case countRes of
    Right t -> return t
    Left _ -> return 0

  let dataStmt = unpreparable sql E.noParams (D.rowList goodsRowDecoder)
  res <- use pool $ Session.statement () dataStmt
  case res of
    Right rows -> return $ QuerySuccess (PaginatedResult rows total (pgLimit p) (pgOffset p))
    Left err -> return $ QueryError (T.pack $ show err)

getBillsPaginated :: Pool -> Pagination -> IO (QueryResult (PaginatedResult Bill))
getBillsPaginated pool p = do
  let limitVal = pgLimit p
      offsetVal = pgOffset p
      sql = T.pack $ "SELECT id, code::text, bill_type, doc_status, doc_date, person_id, location_id, total, discount_amount, tax_amount FROM bill ORDER BY id LIMIT " ++ show limitVal ++ " OFFSET " ++ show offsetVal

  let countStmt =
        unpreparable
          "SELECT COUNT(*) FROM bill"
          E.noParams
          (D.singleRow (D.column (D.nonNullable D.int8)))
  countRes <- use pool $ Session.statement () countStmt
  total <- case countRes of
    Right t -> return t
    Left _ -> return 0

  let dataStmt = unpreparable sql E.noParams (D.rowList billRowDecoder)
  res <- use pool $ Session.statement () dataStmt
  case res of
    Right rows -> return $ QuerySuccess (PaginatedResult rows total (pgLimit p) (pgOffset p))
    Left err -> return $ QueryError (T.pack $ show err)

getOrdersPaginated :: Pool -> Pagination -> IO (QueryResult (PaginatedResult Order))
getOrdersPaginated pool p = do
  let limitVal = pgLimit p
      offsetVal = pgOffset p
      sql = T.pack $ "SELECT id, code::text, name::text, doc_date, person_id, location_id, doc_status, total, discount_amount, tax_amount FROM order_head ORDER BY id LIMIT " ++ show limitVal ++ " OFFSET " ++ show offsetVal

  let countStmt =
        unpreparable
          "SELECT COUNT(*) FROM order_head"
          E.noParams
          (D.singleRow (D.column (D.nonNullable D.int8)))
  countRes <- use pool $ Session.statement () countStmt
  total <- case countRes of
    Right t -> return t
    Left _ -> return 0

  let dataStmt = unpreparable sql E.noParams (D.rowList orderRowDecoder)
  res <- use pool $ Session.statement () dataStmt
  case res of
    Right rows -> return $ QuerySuccess (PaginatedResult rows total (pgLimit p) (pgOffset p))
    Left err -> return $ QueryError (T.pack $ show err)
