{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE Arrows #-}
{-# LANGUAGE TypeOperators #-}

-- | Database Queries (Read operations)
-- NOTE: This module is being converted to use Opaleye instead of Hasql
-- as part of the migration to use only Opaleye for PostgreSQL access
-- This module provides all read operations for the database layer.
-- It includes row decoders, query builders, and pagination helpers.
--
-- = Design
--
-- The query layer uses:
--
-- * Opaleye for type-safe queries
-- * Row decoders for mapping SQL results to Haskell types
-- * Pagination helpers for server-side paging
--
-- = Decoders
--
-- Each entity has a corresponding row decoder (e.g., 'personRowDecoder').
-- These are composed using Applicative style for clarity.
module DAL.Queries where

import DAL.Types
import Data.Functor.Contravariant ((>$<))
import Data.Int (Int16, Int64)
import Data.Profunctor.Product.Default (Default)
import Data.Text (Text, splitOn)
import qualified Data.Text as T
import Data.Time (Day, UTCTime)
import Data.Time.Calendar (fromGregorian)
import Database.PostgreSQL.Simple (Connection)
import qualified Opaleye as OE
import qualified Opaleye.Internal.HaskellDB.PrimQuery as OPQ
import qualified Opaleye.Internal.PGTypes as OPG
import qualified Opaleye.Internal.Tag as OITag
import Surypus.CoreTypes (Decimal (..))
import Data.Time.Clock (getCurrentTime, diffUTCTime, NominalDiffTime)
import DAL.Database (Pool, usePool, runQuery, runCommand)

-- | Helper to create prepared statements (old hasql API compatibility)
preparable :: T.Text -> E.Params params -> D.Result result -> Statement params result
preparable sql encoder decoder = Statement (TE.encodeUtf8 sql) encoder decoder True

-- | Execute a query with timing for logging
-- Returns (result, duration in seconds)
timedQuery :: Pool -> Text -> Statement params result -> params -> IO (Either Text result, Double)
timedQuery pool sql stmt params = do
  start <- getCurrentTime
  res <- use pool $ Session.statement params stmt
  end <- getCurrentTime
  let duration = realToFrac (end `diffUTCTime` start) :: Double
  return (case res of Right v -> Right v; Left e -> Left (T.pack (show e)), duration)

-- | Execute a query by name (for logging purposes)
runQueryTimed :: Pool -> Text -> Statement params result -> params -> IO (Either Text result)
runQueryTimed pool queryName stmt params = do
  (result, duration) <- timedQuery pool queryName stmt params
  -- Could log here if logger was passed through
  return result

personSortKeyText :: Maybe PersonSortBy -> Text
personSortKeyText (Just PersonSortByName) = "name"
personSortKeyText (Just PersonSortByINN) = "inn"
personSortKeyText _ = "id"

goodsSortKeyText :: Maybe GoodsSortBy -> Text
goodsSortKeyText (Just GoodsSortByName) = "name"
goodsSortKeyText (Just GoodsSortByCode) = "code"
goodsSortKeyText _ = "id"

billSortKeyText :: Maybe BillSortBy -> Text
billSortKeyText (Just BillSortByDate) = "doc_date"
billSortKeyText (Just BillSortByTotal) = "total"
billSortKeyText _ = "id"

sortDirDescending :: Maybe SortDir -> Bool
sortDirDescending (Just Desc) = True
sortDirDescending _ = False

personRowDecoder :: D.Row Person
personRowDecoder =
  Person
    <$> D.column (D.nonNullable D.int8)
    <*> D.column (D.nullable D.text)
    <*> D.column (D.nonNullable D.text)
    <*> D.column (D.nullable D.text)
    <*> D.column (D.nullable D.text)
    <*> (fromIntegral <$> D.column (D.nonNullable D.int2))
    <*> (fmap fromIntegral <$> D.column (D.nullable D.int2))

goodsRowDecoder :: D.Row Goods
goodsRowDecoder =
  Goods
    <$> D.column (D.nonNullable D.int8)
    <*> D.column (D.nullable D.text)
    <*> D.column (D.nonNullable D.text)
    <*> D.column (D.nullable D.text)
    <*> D.column (D.nullable D.text)
    <*> D.column (D.nullable D.int8)
    <*> D.column (D.nullable D.int8)
    <*> (fmap fromIntegral <$> D.column (D.nullable D.int2))
    <*> (fmap fromIntegral <$> D.column (D.nullable D.int2))
    <*> D.column (D.nullable D.float8)
    <*> D.column (D.nullable D.float8)
    <*> D.column (D.nullable D.float8)
    <*> D.column (D.nullable D.float8)
    <*> D.column (D.nullable D.timestamptz)
    <*> D.column (D.nullable D.timestamptz)

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
    <*> D.column (D.nonNullable D.float8)
    <*> D.column (D.nonNullable D.float8)
    <*> D.column (D.nonNullable D.float8)
billLineRowDecoder =
  BillLine
    <$> D.column (D.nonNullable D.int8)
    <*> D.column (D.nonNullable D.int8)
    <*> D.column (D.nonNullable D.int8)
    <*> D.column (D.nonNullable D.float8)
    <*> D.column (D.nonNullable D.float8)
    <*> D.column (D.nonNullable D.float8)
    <*> D.column (D.nonNullable D.float8)

stockRowDecoder :: D.Row Stock
stockRowDecoder =
  Stock
    <$> D.column (D.nonNullable D.int8)
    <*> D.column (D.nonNullable D.int8)
    <*> D.column (D.nonNullable D.int8)
    <*> D.column (D.nonNullable D.float8)
    <*> D.column (D.nonNullable D.float8)

userRowDecoder :: D.Row User
userRowDecoder =
  User
    <$> D.column (D.nonNullable D.int8)
    <*> D.column (D.nonNullable D.text)
    <*> pure Nothing
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
    <*> (realToFrac <$> D.column (D.nonNullable D.numeric))
    <*> D.column (D.nonNullable D.date)

salaryRowDecoder :: D.Row Salary
salaryRowDecoder =
  Salary
    <$> D.column (D.nonNullable D.int8)
    <*> D.column (D.nonNullable D.int8)
    <*> D.column (D.nonNullable D.date)
    <*> (realToFrac <$> D.column (D.nonNullable D.numeric))
    <*> (realToFrac <$> D.column (D.nonNullable D.numeric))
    <*> (realToFrac <$> D.column (D.nonNullable D.numeric))
    <*> (realToFrac <$> D.column (D.nonNullable D.numeric))
    <*> (realToFrac <$> D.column (D.nonNullable D.numeric))

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
    <*> (realToFrac <$> D.column (D.nonNullable D.numeric))
    <*> (realToFrac <$> D.column (D.nonNullable D.numeric))
    <*> (realToFrac <$> D.column (D.nonNullable D.numeric))

paymentRowDecoder :: D.Row Payment
paymentRowDecoder =
  Payment
    <$> D.column (D.nonNullable D.int8)
    <*> D.column (D.nonNullable D.int8)
    <*> (realToFrac <$> D.column (D.nonNullable D.numeric))
    <*> D.column (D.nonNullable D.date)

goodsPriceRowDecoder :: D.Row GoodsPrice
goodsPriceRowDecoder =
  GoodsPrice
    <$> D.column (D.nonNullable D.int8)
    <*> D.column (D.nonNullable D.int8)
    <*> (fromIntegral <$> D.column (D.nonNullable D.int2))
    <*> (realToFrac <$> D.column (D.nonNullable D.numeric))
    <*> (realToFrac <$> D.column (D.nonNullable D.numeric))
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
    <*> (realToFrac <$> D.column (D.nonNullable D.numeric))

currencyRowDecoder :: D.Row Currency
currencyRowDecoder =
  Currency
    <$> D.column (D.nonNullable D.int8)
    <*> D.column (D.nullable D.text)
    <*> D.column (D.nullable D.text)
    <*> D.column (D.nullable D.text)
    <*> (realToFrac <$> D.column (D.nonNullable D.numeric))
    <*> D.column (D.nonNullable D.bool)

techCardRowDecoder =
  TechCard
    <$> D.column (D.nullable D.int8)
    <*> D.column (D.nonNullable D.int8)
    <*> D.column (D.nonNullable D.text)
    <*> D.column (D.nonNullable D.text)
    <*> (fromIntegral <$> D.column (D.nonNullable D.int2))
    <*> D.column (D.nonNullable D.timestamptz)
    <*> D.column (D.nonNullable D.timestamptz)
    <*> D.column (D.nullable D.text)

workOrderRowDecoder =
  WorkOrder
    <$> D.column (D.nullable D.int8)
    <*> D.column (D.nonNullable D.text)
    <*> D.column (D.nonNullable D.int8)
    <*> D.column (D.nullable D.int8)
    <*> (realToFrac <$> D.column (D.nonNullable D.numeric))
    <*> (realToFrac <$> D.column (D.nonNullable D.numeric))
    <*> (fromIntegral <$> D.column (D.nonNullable D.int2))
    <*> D.column (D.nullable D.date)
    <*> D.column (D.nullable D.date)
    <*> D.column (D.nullable D.int8)
    <*> D.column (D.nullable D.text)
    <*> D.column (D.nonNullable D.timestamptz)
    <*> D.column (D.nonNullable D.timestamptz)
    <*> D.column (D.nullable D.text)

dashboardStatsRowDecoder :: D.Row DashboardStats
dashboardStatsRowDecoder =
  (\r o g c -> DashboardStats (fromIntegral r) (fromIntegral o) (fromIntegral g) (fromIntegral c))
    <$> D.column (D.nonNullable D.int8)
    <*> D.column (D.nonNullable D.int8)
    <*> D.column (D.nonNullable D.int8)
    <*> D.column (D.nonNullable D.int8)

getPersons :: Pool -> IO (QueryResult [Person])
getPersons pool = do
   res <- runQuery pool personQuery
   case res of
     Left err -> return $ QueryError err
     Right cols -> return $ QuerySuccess $ map personFromCols cols

personQuery :: OE.Query () (OE.Int8, OE.Maybe OE.Text, OE.Text, OE.Maybe OE.Text, OE.Maybe OE.Text, OE.Int2, OE.Maybe OE.Int2)
personQuery = OE.sql 
   "SELECT id, code::text, name::text, inn::text, kpp::text, person_type, status FROM persons.person ORDER BY id"
   (OE.makeColumns (,,,,,,) 
      OE.int8
      (OE.maybe OE.text)
      OE.text
      (OE.maybe OE.text)
      (OE.maybe OE.text)
      OE.int2
      (OE.maybe OE.int2)
   )

personFromCols :: (OE.Int8, OE.Maybe OE.Text, OE.Text, OE.Maybe OE.Text, OE.Maybe OE.Text, OE.Int2, OE.Maybe OE.Int2) -> Person
personFromCols (id, code, name, inn, kpp, personType, status) =
   Person id code name inn kpp (fromIntegral personType) (fmap fromIntegral status)

searchPersons :: Pool -> Text -> IO (QueryResult [Person])
searchPersons pool query = do
   res <- runQuery pool (searchPersonsQuery query)
   case res of
     Left err -> return $ QueryError err
     Right cols -> return $ QuerySuccess $ map personFromCols cols

searchPersonsQuery :: Text -> OE.Query (OE.Text) (OE.Int8, OE.Maybe OE.Text, OE.Text, OE.Maybe OE.Text, OE.Maybe OE.Text, OE.Int2, OE.Maybe OE.Int2)
searchPersonsQuery query = OE.sql 
   "SELECT id, code::text, name::text, inn::text, kpp::text, person_type, status FROM persons.person WHERE name ILIKE $1 OR code ILIKE $1 OR inn ILIKE $1 ORDER BY id"
   (OE.makeColumns (,,,,,,) 
      OE.int8
      (OE.maybe OE.text)
      OE.text
      (OE.maybe OE.text)
      (OE.maybe OE.text)
      OE.int2
      (OE.maybe OE.int2)
   ) (OE.literal $ "%" <> query <> "%")

personFromCols :: (OE.Int8, OE.Maybe OE.Text, OE.Text, OE.Maybe OE.Text, OE.Maybe OE.Text, OE.Int2, OE.Maybe OE.Int2) -> Person
personFromCols (id, code, name, inn, kpp, personType, status) =
   Person id code name inn kpp (fromIntegral personType) (fmap fromIntegral status)

getPersonById :: Pool -> Int64 -> IO (QueryResult Person)
getPersonById pool pid = do
  let stmt =
        preparable
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
   res <- runQuery pool goodsQuery
   case res of
     Left err -> return $ QueryError err
     Right cols -> return $ QuerySuccess $ map goodsFromCols cols

goodsQuery :: OE.Query () (OE.Int8, OE.Maybe OE.Text, OE.Text, OE.Maybe OE.Text, OE.Maybe OE.Text, OE.Int8, OE.Int8)
goodsQuery = OE.sql 
   "SELECT id, code::text, name::text, barcode::text, unit_id, parent_id FROM goods ORDER BY id"
   (OE.makeColumns (,,,,,,,) 
      OE.int8
      (OE.maybe OE.text)
      OE.text
      (OE.maybe OE.text)
      (OE.maybe OE.text)
      OE.int8
      OE.int8
   )

goodsFromCols :: (OE.Int8, OE.Maybe OE.Text, OE.Text, OE.Maybe OE.Text, OE.Maybe OE.Text, OE.Int8, OE.Int8) -> Goods
goodsFromCols (id, code, name, barcode, unitId, parentId) =
   Goods id code name barcode unitId parentId

searchGoods :: Pool -> Text -> IO (QueryResult [Goods])
searchGoods pool query = do
  let stmt =
        preparable
          "SELECT id, code::text, name::text, barcode::text, unit_id, parent_id FROM goods WHERE name ILIKE $1 OR code ILIKE $1 OR barcode ILIKE $1 ORDER BY id"
          (E.param (E.nonNullable E.text))
          (D.rowList goodsRowDecoder)
  res <- use pool $ Session.statement ("%" <> query <> "%") stmt
  case res of
    Right rows -> pure $ QuerySuccess rows
    Left err -> pure $ QueryError (T.pack $ show err)

getGoodsById :: Pool -> Int64 -> IO (QueryResult Goods)
getGoodsById pool gid = do
   res <- runQuery pool (goodsByIdQuery gid)
   case res of
     Left err -> return $ QueryError err
     Right [] -> return $ QueryError "Not Found"
     Right (col:_) -> return $ QuerySuccess $ goodsFromCols col

goodsByIdQuery :: Int64 -> OE.Query (OE.Int8) (OE.Int8, OE.Maybe OE.Text, OE.Text, OE.Maybe OE.Text, OE.Maybe OE.Text, OE.Int8, OE.Int8)
goodsByIdQuery gid = OE.sql 
   "SELECT id, code::text, name::text, barcode::text, unit_id, parent_id FROM goods WHERE id = $1"
   (OE.makeColumns (,,,,,,,) 
      OE.int8
      (OE.maybe OE.text)
      OE.text
      (OE.maybe OE.text)
      (OE.maybe OE.text)
      OE.int8
      OE.int8
   ) (OE.literal gid)

goodsFromCols :: (OE.Int8, OE.Maybe OE.Text, OE.Text, OE.Maybe OE.Text, OE.Maybe OE.Text, OE.Int8, OE.Int8) -> Goods
goodsFromCols (id, code, name, barcode, unitId, parentId) =
   Goods id code name barcode unitId parentId

getGoodsByBarcode :: Pool -> Text -> IO (QueryResult Goods)
getGoodsByBarcode pool barcode = do
   res <- runQuery pool (goodsByBarcodeQuery barcode)
   case res of
     Left err -> return $ QueryError err
     Right [] -> return $ QueryError "Not Found"
     Right (col:_) -> return $ QuerySuccess $ goodsFromCols col

goodsByBarcodeQuery :: Text -> OE.Query (OE.Text) (OE.Int8, OE.Maybe OE.Text, OE.Text, OE.Maybe OE.Text, OE.Maybe OE.Text, OE.Int8, OE.Int8)
goodsByBarcodeQuery barcode = OE.sql 
   "SELECT id, code::text, name::text, barcode::text, unit_id, parent_id FROM goods WHERE barcode = $1"
   (OE.makeColumns (,,,,,,,) 
      OE.int8
      (OE.maybe OE.text)
      OE.text
      (OE.maybe OE.text)
      (OE.maybe OE.text)
      OE.int8
      OE.int8
   ) (OE.literal barcode)

goodsFromCols :: (OE.Int8, OE.Maybe OE.Text, OE.Text, OE.Maybe OE.Text, OE.Maybe OE.Text, OE.Int8, OE.Int8) -> Goods
goodsFromCols (id, code, name, barcode, unitId, parentId) =
   Goods id code name barcode unitId parentId

getLocations :: Pool -> IO (QueryResult [Location])
getLocations pool = do
   res <- runQuery pool locationQuery
   case res of
     Left err -> return $ QueryError err
     Right cols -> return $ QuerySuccess $ map locationFromCols cols

locationQuery :: OE.Query () (OE.Int8, OE.Maybe OE.Text, OE.Text)
locationQuery = OE.sql 
   "SELECT id, code::text, name::text, location_type FROM location ORDER BY id"
   (OE.makeColumns (,,,) 
      OE.int8
      (OE.maybe OE.text)
      OE.text
   )

locationFromCols :: (OE.Int8, OE.Maybe OE.Text, OE.Text) -> Location
locationFromCols (id, code, name) =
   Location id code name

getLocationById :: Pool -> Int64 -> IO (QueryResult Location)
getLocationById pool lid = do
   res <- runQuery pool (locationByIdQuery lid)
   case res of
     Left err -> return $ QueryError err
     Right [] -> return $ QueryError "Not Found"
     Right (col:_) -> return $ QuerySuccess $ locationFromCols col

locationByIdQuery :: Int64 -> OE.Query (OE.Int8) (OE.Int8, OE.Maybe OE.Text, OE.Text)
locationByIdQuery lid = OE.sql 
   "SELECT id, code::text, name::text, location_type FROM location WHERE id = $1"
   (OE.makeColumns (,,,) 
      OE.int8
      (OE.maybe OE.text)
      OE.text
   ) (OE.literal lid)

locationFromCols :: (OE.Int8, OE.Maybe OE.Text, OE.Text) -> Location
locationFromCols (id, code, name) =
   Location id code name

getBills :: Pool -> IO (QueryResult [Bill])
getBills pool = do
   res <- runQuery pool billsQuery
   case res of
     Left err -> return $ QueryError err
     Right cols -> return $ QuerySuccess $ map billFromCols cols

billsQuery :: OE.Query () (OE.Int8, OE.Maybe OE.Text, OE.Int2, OE.Int2, OE.Date, OE.Int8, OE.Int8, OE.Double, OE.Double, OE.Double)
billsQuery = OE.sql 
   "SELECT id, code::text, bill_type, doc_status, doc_date, person_id, location_id, total, discount_amount, tax_amount FROM bill ORDER BY id"
   (OE.makeColumns (,,,,,,,,,) 
      OE.int8
      (OE.maybe OE.text)
      OE.int2
      OE.int2
      OE.date
      OE.int8
      OE.int8
      OE.double
      OE.double
      OE.double
   )

billFromCols :: (OE.Int8, OE.Maybe OE.Text, OE.Int2, OE.Int2, OE.Date, OE.Int8, OE.Int8, OE.Double, OE.Double, OE.Double) -> Bill
billFromCols (id, code, billType, docStatus, docDate, personId, locationId, total, discountAmount, taxAmount) =
   Bill id code billType docStatus docDate personId locationId total discountAmount taxAmount

getBillById :: Pool -> Int64 -> IO (QueryResult Bill)
getBillById pool bid = do
   res <- runQuery pool (billByIdQuery bid)
   case res of
     Left err -> return $ QueryError err
     Right [] -> return $ QueryError "Not Found"
     Right (col:_) -> return $ QuerySuccess $ billFromCols col

billByIdQuery :: Int64 -> OE.Query (OE.Int8) (OE.Int8, OE.Maybe OE.Text, OE.Int2, OE.Int2, OE.Date, OE.Int8, OE.Int8, OE.Double, OE.Double, OE.Double)
billByIdQuery bid = OE.sql 
   "SELECT id, code::text, bill_type, doc_status, doc_date, person_id, location_id, total, discount_amount, tax_amount FROM bill WHERE id = $1"
   (OE.makeColumns (,,,,,,,,,) 
      OE.int8
      (OE.maybe OE.text)
      OE.int2
      OE.int2
      OE.date
      OE.int8
      OE.int8
      OE.double
      OE.double
      OE.double
   ) (OE.literal bid)

billFromCols :: (OE.Int8, OE.Maybe OE.Text, OE.Int2, OE.Int2, OE.Date, OE.Int8, OE.Int8, OE.Double, OE.Double, OE.Double) -> Bill
billFromCols (id, code, billType, docStatus, docDate, personId, locationId, total, discountAmount, taxAmount) =
   Bill id code billType docStatus docDate personId locationId total discountAmount taxAmount

getBillLines :: Pool -> Int64 -> IO (QueryResult [BillLine])
getBillLines pool bid = do
   res <- runQuery pool (billLinesQuery bid)
   case res of
     Left err -> return $ QueryError err
     Right cols -> return $ QuerySuccess $ map billLineFromCols cols

billLinesQuery :: Int64 -> OE.Query (OE.Int8) (OE.Int8, OE.Int8, OE.Int8, OE.Double, OE.Double, OE.Double, OE.Double)
billLinesQuery bid = OE.sql 
   "SELECT id, bill_id, goods_id, qtty, price, discount_amount, amount FROM bill_line WHERE bill_id = $1 ORDER BY id"
   (OE.makeColumns (,,,,,,,) 
      OE.int8
      OE.int8
      OE.int8
      OE.double
      OE.double
      OE.double
      OE.double
   ) (OE.literal bid)

billLineFromCols :: (OE.Int8, OE.Int8, OE.Int8, OE.Double, OE.Double, OE.Double, OE.Double) -> BillLine
billLineFromCols (id, billId, goodsId, qtty, price, discountAmount, amount) =
   BillLine id billId goodsId qtty price discountAmount amount

getStock :: Pool -> Int64 -> Int64 -> IO (QueryResult [Stock])
getStock pool _ _ = getStockAll pool

getStockAll :: Pool -> IO (QueryResult [Stock])
getStockAll pool = do
   res <- runQuery pool stockAllQuery
   case res of
     Left err -> return $ QueryError err
     Right cols -> return $ QuerySuccess $ map stockFromCols cols

stockAllQuery :: OE.Query () (OE.Int8, OE.Int8, OE.Int8, OE.Double, OE.Double)
stockAllQuery = OE.sql 
   "SELECT id, goods_id, location_id, qtty, resrv_qtty FROM stock ORDER BY id"
   (OE.makeColumns (,,,,,) 
      OE.int8
      OE.int8
      OE.int8
      OE.double
      OE.double
   )

stockFromCols :: (OE.Int8, OE.Int8, OE.Int8, OE.Double, OE.Double) -> Stock
stockFromCols (id, goodsId, locationId, qtty, resrvQtty) =
   Stock id goodsId locationId qtty resrvQtty

getStockByLocation :: Pool -> Int64 -> IO (QueryResult [Stock])
getStockByLocation pool lid = do
   res <- runQuery pool (stockByLocationQuery lid)
   case res of
     Left err -> return $ QueryError err
     Right cols -> return $ QuerySuccess $ map stockFromCols cols

stockByLocationQuery :: Int64 -> OE.Query (OE.Int8) (OE.Int8, OE.Int8, OE.Int8, OE.Double, OE.Double)
stockByLocationQuery lid = OE.sql 
   "SELECT id, goods_id, location_id, qtty, resrv_qtty FROM stock WHERE location_id = $1"
   (OE.makeColumns (,,,,,) 
      OE.int8
      OE.int8
      OE.int8
      OE.double
      OE.double
   ) (OE.literal lid)

stockFromCols :: (OE.Int8, OE.Int8, OE.Int8, OE.Double, OE.Double) -> Stock
stockFromCols (id, goodsId, locationId, qtty, resrvQtty) =
   Stock id goodsId locationId qtty resrvQtty

getStockByGoods :: Pool -> Int64 -> IO (QueryResult [Stock])
getStockByGoods pool gid = do
  let stmt =
        preparable
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
      stmt = preparable sql ((fst >$< E.param (E.nonNullable E.int8)) <> (snd >$< E.param (E.nonNullable E.int8))) (D.rowList dateAmountDecoder)
  res <- use pool $ Session.statement (daysAgo, limit) stmt
  case res of
    Right rows -> pure $ QuerySuccess rows
    Left err -> pure $ QueryError (T.pack $ show err)
  where
    dateAmountDecoder :: D.Row (Day, Decimal)
    dateAmountDecoder = (,) <$> D.column (D.nonNullable D.date) <*> (realToFrac <$> D.column (D.nonNullable D.numeric))

getUsers :: Pool -> IO (QueryResult [User])
getUsers pool = do
  let stmt =
        preparable
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
      stmt = preparable sql (E.param (E.nonNullable E.int8)) (D.rowList topGoodsDecoder)
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
        <*> (realToFrac <$> D.column (D.nonNullable D.numeric))

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
        preparable
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
        <$> D.column (D.nonNullable D.int8)
        <*> D.column (D.nonNullable D.text)
        <*> D.column (D.nonNullable D.text)
        <*> D.column (D.nullable D.text)

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
      stmt = preparable sql E.noParams (D.rowList stockSummaryDecoder)
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
      stmt = preparable sql E.noParams (D.rowList rolesDecoder)
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
      stmt = preparable sql E.noParams (D.rowList inventoryDecoder)
  res <- use pool $ Session.statement () stmt
  case res of
    Right rows -> pure $ QuerySuccess rows
    Left err -> pure $ QueryError (T.pack $ show err)

-- | Get persons with server-side SQL pagination
getPersonsPaginated :: Pool -> PersonFilter -> Maybe PersonSortBy -> Maybe SortDir -> Pagination -> IO (QueryResult (PaginatedResult Person))
getPersonsPaginated pool filter' mSortBy mSortDir pagination = do
  let limitVal = fromIntegral (pgLimit pagination) :: Int64
      offsetVal = fromIntegral (pgOffset pagination) :: Int64
      nameFilter = pfName filter'
      innFilter = pfINN filter'
      typeFilter = fmap fromIntegral (pfPersonType filter') :: Maybe Int16
      statusFilter = fmap fromIntegral (pfStatus filter') :: Maybe Int16
      sortKey = personSortKeyText mSortBy
      sortDesc = sortDirDescending mSortDir
      whereClause =
        " WHERE ($1 IS NULL OR name ILIKE '%' || $1 || '%')"
          <> " AND ($2 IS NULL OR inn = $2)"
          <> " AND ($3 IS NULL OR person_type = $3)"
          <> " AND ($4 IS NULL OR status = $4)"
      listSql =
        "SELECT id, code::text, name::text, inn::text, kpp::text, person_type, status FROM persons.person"
          <> whereClause
          <> " ORDER BY "
          <> "CASE WHEN $5 = 'name' AND NOT $6 THEN name END ASC, "
          <> "CASE WHEN $5 = 'name' AND $6 THEN name END DESC, "
          <> "CASE WHEN $5 = 'inn' AND NOT $6 THEN inn END ASC, "
          <> "CASE WHEN $5 = 'inn' AND $6 THEN inn END DESC, "
          <> "CASE WHEN $5 = 'id' AND NOT $6 THEN id END ASC, "
          <> "CASE WHEN $5 = 'id' AND $6 THEN id END DESC, "
          <> "id ASC LIMIT $7 OFFSET $8"
      countSql = "SELECT COUNT(*) FROM persons.person" <> whereClause
      filterParams =
        (nameFilter, innFilter, typeFilter, statusFilter, sortKey, sortDesc, limitVal, offsetVal)
      countFilterParams :: (Maybe Text, Maybe Text, Maybe Int16, Maybe Int16)
      countFilterParams = (nameFilter, innFilter, typeFilter, statusFilter)
      listStmt =
        preparable
          listSql
          ( ((\(a, _, _, _, _, _, _, _) -> a) >$< E.param (E.nullable E.text))
              <> ((\(_, b, _, _, _, _, _, _) -> b) >$< E.param (E.nullable E.text))
              <> ((\(_, _, c, _, _, _, _, _) -> c) >$< E.param (E.nullable E.int2))
              <> ((\(_, _, _, d, _, _, _, _) -> d) >$< E.param (E.nullable E.int2))
              <> ((\(_, _, _, _, e, _, _, _) -> e) >$< E.param (E.nonNullable E.text))
              <> ((\(_, _, _, _, _, f, _, _) -> f) >$< E.param (E.nonNullable E.bool))
              <> ((\(_, _, _, _, _, _, g, _) -> g) >$< E.param (E.nonNullable E.int8))
              <> ((\(_, _, _, _, _, _, _, h) -> h) >$< E.param (E.nonNullable E.int8))
          )
          (D.rowList personRowDecoder)
      countStmt =
        preparable
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
            prTotal = fromIntegral totalCount,
            prLimit = pgLimit pagination,
            prOffset = pgOffset pagination
          }
    (Left err, _) -> pure $ QueryError (T.pack $ show err)
    (_, Left err) -> pure $ QueryError (T.pack $ show err)

-- | Get goods with server-side SQL pagination
getGoodsPaginated :: Pool -> GoodsFilter -> Pagination -> Maybe GoodsSortBy -> Maybe SortDir -> IO (QueryResult (PaginatedResult Goods))
getGoodsPaginated pool filter' pagination mSortBy mSortDir = do
  let limitVal = fromIntegral (pgLimit pagination) :: Int64
      offsetVal = fromIntegral (pgOffset pagination) :: Int64
      nameFilter = gfName filter'
      barcodeFilter = gfBarcode filter'
      codeFilter = gfCode filter'
      sortKey = goodsSortKeyText mSortBy
      sortDesc = sortDirDescending mSortDir
      whereClause =
        " WHERE ($1 IS NULL OR name ILIKE '%' || $1 || '%')"
          <> " AND ($2 IS NULL OR barcode = $2)"
          <> " AND ($3 IS NULL OR code = $3)"
      listSql =
        "SELECT id, code::text, name::text, barcode::text, unit_id, parent_id FROM goods"
          <> whereClause
          <> " ORDER BY "
          <> "CASE WHEN $4 = 'name' AND NOT $5 THEN name END ASC, "
          <> "CASE WHEN $4 = 'name' AND $5 THEN name END DESC, "
          <> "CASE WHEN $4 = 'code' AND NOT $5 THEN code END ASC, "
          <> "CASE WHEN $4 = 'code' AND $5 THEN code END DESC, "
          <> "CASE WHEN $4 = 'id' AND NOT $5 THEN id END ASC, "
          <> "CASE WHEN $4 = 'id' AND $5 THEN id END DESC, "
          <> "id ASC LIMIT $6 OFFSET $7"
      countSql = "SELECT COUNT(*) FROM goods" <> whereClause
      listParams :: (Maybe Text, Maybe Text, Maybe Text, Text, Bool, Int64, Int64)
      listParams = (nameFilter, barcodeFilter, codeFilter, sortKey, sortDesc, limitVal, offsetVal)
      countParams :: (Maybe Text, Maybe Text, Maybe Text)
      countParams = (nameFilter, barcodeFilter, codeFilter)
      listStmt =
        preparable
          listSql
          ( ((\(a, _, _, _, _, _, _) -> a) >$< E.param (E.nullable E.text))
              <> ((\(_, b, _, _, _, _, _) -> b) >$< E.param (E.nullable E.text))
              <> ((\(_, _, c, _, _, _, _) -> c) >$< E.param (E.nullable E.text))
              <> ((\(_, _, _, d, _, _, _) -> d) >$< E.param (E.nonNullable E.text))
              <> ((\(_, _, _, _, e, _, _) -> e) >$< E.param (E.nonNullable E.bool))
              <> ((\(_, _, _, _, _, f, _) -> f) >$< E.param (E.nonNullable E.int8))
              <> ((\(_, _, _, _, _, _, g) -> g) >$< E.param (E.nonNullable E.int8))
          )
          (D.rowList goodsRowDecoder)
      countStmt =
        preparable
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
            prTotal = fromIntegral totalCount,
            prLimit = pgLimit pagination,
            prOffset = pgOffset pagination
          }
    (Left err, _) -> pure $ QueryError (T.pack $ show err)
    (_, Left err) -> pure $ QueryError (T.pack $ show err)

-- | Get payments
getPayments :: Pool -> IO (QueryResult [Payment])
getPayments pool = do
  let stmt =
        preparable
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
        preparable
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
        preparable
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
        preparable
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
        preparable
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
        preparable
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
        preparable
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
        preparable
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
        preparable
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
        preparable
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
  let limitVal = fromIntegral (pgLimit pagination) :: Int64
      offsetVal = fromIntegral (pgOffset pagination) :: Int64
      typeFilter = fmap fromIntegral (bfBillType filter') :: Maybe Int16
      statusFilter = fmap fromIntegral (bfStatus filter') :: Maybe Int16
      personFilter = bfPersonId filter'
      dateFromFilter = bfDateFrom filter'
      dateToFilter = bfDateTo filter'
      sortKey = billSortKeyText mSortBy
      sortDesc = sortDirDescending mSortDir
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
          <> "CASE WHEN $6 = 'doc_date' AND NOT $7 THEN doc_date END ASC, "
          <> "CASE WHEN $6 = 'doc_date' AND $7 THEN doc_date END DESC, "
          <> "CASE WHEN $6 = 'total' AND NOT $7 THEN total END ASC, "
          <> "CASE WHEN $6 = 'total' AND $7 THEN total END DESC, "
          <> "CASE WHEN $6 = 'id' AND NOT $7 THEN id END ASC, "
          <> "CASE WHEN $6 = 'id' AND $7 THEN id END DESC, "
          <> "id ASC LIMIT $8 OFFSET $9"
      countSql = "SELECT COUNT(*) FROM bill" <> whereClause
      listParams :: (Maybe Int16, Maybe Int16, Maybe Int64, Maybe Day, Maybe Day, Text, Bool, Int64, Int64)
      listParams = (typeFilter, statusFilter, personFilter, dateFromFilter, dateToFilter, sortKey, sortDesc, limitVal, offsetVal)
      countParams :: (Maybe Int16, Maybe Int16, Maybe Int64, Maybe Day, Maybe Day)
      countParams = (typeFilter, statusFilter, personFilter, dateFromFilter, dateToFilter)
      listStmt =
        preparable
          listSql
          ( ((\(a, _, _, _, _, _, _, _, _) -> a) >$< E.param (E.nullable E.int2))
              <> ((\(_, b, _, _, _, _, _, _, _) -> b) >$< E.param (E.nullable E.int2))
              <> ((\(_, _, c, _, _, _, _, _, _) -> c) >$< E.param (E.nullable E.int8))
              <> ((\(_, _, _, d, _, _, _, _, _) -> d) >$< E.param (E.nullable E.date))
              <> ((\(_, _, _, _, e, _, _, _, _) -> e) >$< E.param (E.nullable E.date))
              <> ((\(_, _, _, _, _, f, _, _, _) -> f) >$< E.param (E.nonNullable E.text))
              <> ((\(_, _, _, _, _, _, g, _, _) -> g) >$< E.param (E.nonNullable E.bool))
              <> ((\(_, _, _, _, _, _, _, h, _) -> h) >$< E.param (E.nonNullable E.int8))
              <> ((\(_, _, _, _, _, _, _, _, i) -> i) >$< E.param (E.nonNullable E.int8))
          )
          (D.rowList billRowDecoder)
      countStmt =
        preparable
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
            prTotal = fromIntegral totalCount,
            prLimit = pgLimit pagination,
            prOffset = pgOffset pagination
          }
    (Left err, _) -> pure $ QueryError (T.pack $ show err)
    (_, Left err) -> pure $ QueryError (T.pack $ show err)

-- | Get payments by bill
getPaymentsByBill :: Pool -> Int64 -> IO (QueryResult [Payment])
getPaymentsByBill pool billId = do
  let stmt =
        preparable
          "SELECT id, bill_id, date, amount, payment_method, payment_status FROM payment WHERE bill_id = $1 ORDER BY date DESC, id DESC"
          (E.param (E.nonNullable E.int8))
          (D.rowList paymentRowDecoder)
  res <- use pool $ Session.statement billId stmt
  case res of
    Right rows -> pure $ QuerySuccess rows
    Left err -> pure $ QueryError (T.pack $ show err)

-- | Get payments by status (e.g., pending, completed)
getPaymentsByStatus :: Pool -> Int16 -> IO (QueryResult [Payment])
getPaymentsByStatus pool statusVal = do
  let stmt =
        preparable
          "SELECT id, bill_id, date, amount, payment_method, payment_status FROM payment WHERE payment_status = $1 ORDER BY date DESC, id DESC"
          (E.param (E.nonNullable E.int2))
          (D.rowList paymentRowDecoder)
  res <- use pool $ Session.statement statusVal stmt
  case res of
    Right rows -> pure $ QuerySuccess rows
    Left err -> pure $ QueryError (T.pack $ show err)

-- | Get total payments amount for a bill
getPaymentTotalByBill :: Pool -> Int64 -> IO (QueryResult Decimal)
getPaymentTotalByBill pool billId = do
  let stmt =
        preparable
          "SELECT COALESCE(SUM(amount), 0) FROM payment WHERE bill_id = $1 AND payment_status = 1"
          (E.param (E.nonNullable E.int8))
          (D.singleRow (realToFrac <$> D.column (D.nonNullable D.numeric)))
  res <- use pool $ Session.statement billId stmt
  case res of
    Right total -> pure $ QuerySuccess total
    Left err -> pure $ QueryError (T.pack $ show err)

-- | Get bills with pending payments (accounts receivable)
getUnpaidBills :: Pool -> IO (QueryResult [Bill])
getUnpaidBills pool = do
  let stmt =
        preparable
          "SELECT b.id, b.code, b.bill_type, b.status, b.date, b.person_id, b.location_id, b.total, b.discount, b.tax \
          \FROM bill b \
          \WHERE b.status = 1 \
          \  AND EXISTS (SELECT 1 FROM payment p WHERE p.bill_id = b.id AND p.payment_status = 0) \
          \ORDER BY b.date DESC, b.id DESC"
          E.noParams
          (D.rowList billRowDecoder)
  res <- use pool $ Session.statement () stmt
  case res of
    Right rows -> pure $ QuerySuccess rows
    Left err -> pure $ QueryError (T.pack $ show err)

-- | Get low stock goods
getLowStockGoods :: Pool -> IO (QueryResult [(Int64, Text, Decimal, Decimal)])
getLowStockGoods pool = do
  let stmt =
        preparable
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
        <*> (realToFrac <$> D.column (D.nonNullable D.numeric))
        <*> (realToFrac <$> D.column (D.nonNullable D.numeric))

-- | Get inventory documents
getInventoryDocuments :: Pool -> IO (QueryResult [Bill])
getInventoryDocuments = getBills

-- | Get dashboard stats
getDashboardStats :: Pool -> IO (QueryResult DashboardStats)
getDashboardStats pool = do
  let stmt =
        preparable
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
        preparable
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
        preparable
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
        preparable
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
        preparable
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
        preparable
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
        preparable
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
        preparable
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
            prTotal = fromIntegral totalCount,
            prLimit = pgLimit pagination,
            prOffset = pgOffset pagination
          }
    (Left err, _) -> pure $ QueryError (T.pack (show err))
    (_, Left err) -> pure $ QueryError (T.pack (show err))

-- | Get order by ID
getOrderById :: Pool -> Int64 -> IO (QueryResult Order)
getOrderById pool orderId = do
  let stmt =
        preparable
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
        preparable
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
        preparable
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
        preparable
          "SELECT id, goods_id, price_type, price, min_qtty, valid_from, valid_to FROM goods_price WHERE goods_id = $1 ORDER BY id"
          (E.param (E.nonNullable E.int8))
          (D.rowList goodsPriceRowDecoder)
  res <- use pool $ Session.statement goodsId stmt
  case res of
    Right rows -> pure $ QuerySuccess rows
    Left err -> pure $ QueryError (T.pack $ show err)

-- | Get goods price effective on a specific date
getGoodsPriceEffective :: Pool -> Int64 -> Day -> IO (QueryResult GoodsPrice)
getGoodsPriceEffective pool goodsId effectiveDate = do
  let stmt =
        preparable
          "SELECT id, goods_id, price_type, price, min_qtty, valid_from, valid_to \
          \FROM goods_price \
          \WHERE goods_id = $1 \
          \  AND (valid_from IS NULL OR valid_from <= $2) \
          \  AND (valid_to IS NULL OR valid_to >= $2) \
          \ORDER BY price_type, min_qtty \
          \LIMIT 1"
          ((fst >$< E.param (E.nonNullable E.int8)) <> (snd >$< E.param (E.nonNullable E.date)))
          (D.rowMaybe goodsPriceRowDecoder)
  res <- use pool $ Session.statement (goodsId, effectiveDate) stmt
  case res of
    Right (Just priceVal) -> pure $ QuerySuccess priceVal
    Right Nothing -> pure $ QueryError "No effective price found for given date"
    Left err -> pure $ QueryError (T.pack $ show err)

getGoodsPriceById :: Pool -> Int64 -> IO (QueryResult GoodsPrice)
getGoodsPriceById pool priceId = do
  let stmt =
        preparable
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
        preparable
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
        preparable
          "SELECT id, code::text, name::text, COALESCE(symbol,'')::text, rate_to_base, is_base FROM currency WHERE id = $1"
          (E.param (E.nonNullable E.int8))
          (D.rowMaybe currencyRowDecoder)
  res <- use pool $ Session.statement currencyId stmt
  case res of
    Right (Just currency) -> pure $ QuerySuccess currency
    Right Nothing -> pure $ QueryError "Not Found"
    Left err -> pure $ QueryError (T.pack $ show err)

-- | Get tech cards with optional filtering by goods_id and pagination
getTechCards :: Pool -> Maybe Int64 -> Int -> Int -> IO (QueryResult [TechCard])
getTechCards pool mGoodsId limit offset = do
  let stmt =
        preparable
          "SELECT id, goods_id, name, version, status, created_at, updated_at, created_by FROM tech_card WHERE (? IS NULL OR goods_id = ?) ORDER BY id LIMIT ? OFFSET ?"
          (((\(gid, _, _, _) -> gid) >$< E.param (E.nullable E.int8)) <>
           ((\(_, gid', _, _) -> gid') >$< E.param (E.nullable E.int8)) <>
           ((\(_, _, limit', _) -> fromIntegral limit') >$< E.param (E.nonNullable E.int4)) <>
           ((\(_, _, _, offset') -> fromIntegral offset') >$< E.param (E.nonNullable E.int4)))
          (D.rowList techCardRowDecoder)
  res <- use pool $ Session.statement (mGoodsId, mGoodsId, limit, offset) stmt
  case res of
    Right cards -> pure $ QuerySuccess cards
    Left err -> pure $ QueryError (T.pack $ show err)

-- | Get a tech card by id
getTechCard :: Pool -> Int64 -> IO (QueryResult TechCard)
getTechCard pool tcId = do
  let stmt =
        preparable
          "SELECT id, goods_id, name, version, status, created_at, updated_at, created_by FROM tech_card WHERE id = $1"
          (E.param (E.nonNullable E.int8))
          (D.singleRow techCardRowDecoder)
  res <- use pool $ Session.statement tcId stmt
  case res of
    Right card -> pure $ QuerySuccess card
    Left err -> pure $ QueryError (T.pack $ show err)

-- | Create a new tech card
createTechCard :: Pool -> TechCard -> UTCTime -> Text -> IO (QueryResult TechCard)
createTechCard pool input createTime userId = do
  let stmt =
        preparable
          "INSERT INTO tech_card (goods_id, name, version, status, created_at, updated_at, created_by) VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING id, goods_id, name, version, status, created_at, updated_at, created_by"
          (((\(gid, _, _, _, _, _, _) -> gid) >$< E.param (E.nonNullable E.int8)) <>
           ((\(_, name, _, _, _, _, _) -> name) >$< E.param (E.nonNullable E.text)) <>
           ((\(_, _, version, _, _, _, _) -> version) >$< E.param (E.nonNullable E.text)) <>
           ((\(_, _, _, status, _, _, _) -> (fromIntegral status :: Int16)) >$< E.param (E.nonNullable E.int2)) <>
           ((\(_, _, _, _, createdAt, _, _) -> createdAt) >$< E.param (E.nonNullable E.timestamptz)) <>
           ((\(_, _, _, _, _, updatedAt, _) -> updatedAt) >$< E.param (E.nonNullable E.timestamptz)) <>
           ((\(_, _, _, _, _, _, createdBy) -> createdBy) >$< E.param (E.nullable E.text)))
          (D.singleRow techCardRowDecoder)
  res <- use pool $ Session.statement (tgGoodsId input, tgName input, tgVersion input, fromIntegral (tgStatus input), createTime, createTime, Just userId) stmt
  case res of
    Right card -> pure $ QuerySuccess card
    Left err -> pure $ QueryError (T.pack $ show err)

-- | Update an existing tech card
updateTechCard :: Pool -> Int64 -> TechCard -> UTCTime -> Text -> IO (QueryResult TechCard)
updateTechCard pool tcId input updateTime userId = do
  let stmt =
        preparable
          "UPDATE tech_card SET name = $1, version = $2, status = $3, updated_at = $4, created_by = $5 WHERE id = $6 RETURNING id, goods_id, name, version, status, created_at, updated_at, created_by"
          (((\(name, _, _, _, _, _) -> name) >$< E.param (E.nonNullable E.text)) <>
           ((\(_, version, _, _, _, _) -> version) >$< E.param (E.nonNullable E.text)) <>
           ((\(_, _, status, _, _, _) -> (fromIntegral status :: Int16)) >$< E.param (E.nonNullable E.int2)) <>
           ((\(_, _, _, updatedAt, _, _) -> updatedAt) >$< E.param (E.nonNullable E.timestamptz)) <>
           ((\(_, _, _, _, createdBy, _) -> createdBy) >$< E.param (E.nullable E.text)) <>
           ((\(_, _, _, _, _, tcId) -> tcId) >$< E.param (E.nonNullable E.int8)))
          (D.singleRow techCardRowDecoder)
  res <- use pool $ Session.statement (tgName input, tgVersion input, fromIntegral (tgStatus input), updateTime, Just userId, tcId) stmt
  case res of
    Right card -> pure $ QuerySuccess card
    Left err -> pure $ QueryError (T.pack $ show err)

-- | Delete a tech card
deleteTechCard :: Pool -> Int64 -> IO (QueryResult ())
deleteTechCard pool tcId = do
  let stmt =
        preparable
          "DELETE FROM tech_card WHERE id = $1"
          (E.param (E.nonNullable E.int8))
          (D.noResult)
  res <- use pool $ Session.statement tcId stmt
  case res of
    Right () -> pure $ QuerySuccess ()
    Left err -> pure $ QueryError (T.pack $ show err)

-- | Get work orders with optional filtering by goods_id and pagination
getWorkOrders :: Pool -> Maybe Int64 -> Int -> Int -> IO (QueryResult [WorkOrder])
getWorkOrders pool mGoodsId limit offset = do
  let stmt =
        preparable
          "SELECT id, code, goods_id, tech_card_id, qty_plan, qty_released, status, start_date, end_date, processor_id, notes, created_at, updated_at, created_by FROM work_order WHERE (? IS NULL OR goods_id = ?) ORDER BY id LIMIT ? OFFSET ?"
          (((\(gid, _, _, _) -> gid) >$< E.param (E.nullable E.int8)) <>
           ((\(_, gid', _, _) -> gid') >$< E.param (E.nullable E.int8)) <>
           ((\(_, _, limit', _) -> fromIntegral limit') >$< E.param (E.nonNullable E.int4)) <>
           ((\(_, _, _, offset') -> fromIntegral offset') >$< E.param (E.nonNullable E.int4)))
          (D.rowList workOrderRowDecoder)
  res <- use pool $ Session.statement (mGoodsId, mGoodsId, limit, offset) stmt
  case res of
    Right orders -> pure $ QuerySuccess orders
    Left err -> pure $ QueryError (T.pack $ show err)

-- | Get a work order by id
getWorkOrder :: Pool -> Int64 -> IO (QueryResult WorkOrder)
getWorkOrder pool woId = do
  let stmt =
        preparable
          "SELECT id, code, goods_id, tech_card_id, qty_plan, qty_released, status, start_date, end_date, processor_id, notes, created_at, updated_at, created_by FROM work_order WHERE id = $1"
          (E.param (E.nonNullable E.int8))
          (D.singleRow workOrderRowDecoder)
  res <- use pool $ Session.statement woId stmt
  case res of
    Right order -> pure $ QuerySuccess order
    Left err -> pure $ QueryError (T.pack $ show err)

-- | Create a new work order
createWorkOrder :: Pool -> WorkOrder -> UTCTime -> Text -> IO (QueryResult WorkOrder)
createWorkOrder pool input createTime userId = do
  let stmt =
        preparable
          "INSERT INTO work_order (code, goods_id, tech_card_id, qty_plan, qty_released, status, start_date, end_date, processor_id, notes, created_at, updated_at, created_by) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13) RETURNING id, code, goods_id, tech_card_id, qty_plan, qty_released, status, start_date, end_date, processor_id, notes, created_at, updated_at, created_by"
          (((\(code, _, _, _, _, _, _, _, _, _, _, _, _) -> code) >$< E.param (E.nonNullable E.text)) <>
           ((\(_, goodsId, _, _, _, _, _, _, _, _, _, _, _) -> goodsId) >$< E.param (E.nonNullable E.int8)) <>
           ((\(_, _, techCardId, _, _, _, _, _, _, _, _, _, _) -> techCardId) >$< E.param (E.nullable E.int8)) <>
           ((\(_, _, _, qtyPlan, _, _, _, _, _, _, _, _, _) -> realToFrac qtyPlan) >$< E.param (E.nonNullable E.numeric)) <>
           ((\(_, _, _, _, qtyReleased, _, _, _, _, _, _, _, _) -> realToFrac qtyReleased) >$< E.param (E.nonNullable E.numeric)) <>
           ((\(_, _, _, _, _, status, _, _, _, _, _, _, _) -> (fromIntegral status :: Int16)) >$< E.param (E.nonNullable E.int2)) <>
           ((\(_, _, _, _, _, _, startDate, _, _, _, _, _, _) -> startDate) >$< E.param (E.nullable E.date)) <>
           ((\(_, _, _, _, _, _, _, endDate, _, _, _, _, _) -> endDate) >$< E.param (E.nullable E.date)) <>
           ((\(_, _, _, _, _, _, _, _, processorId, _, _, _, _) -> processorId) >$< E.param (E.nullable E.int8)) <>
           ((\(_, _, _, _, _, _, _, _, _, notes, _, _, _) -> notes) >$< E.param (E.nullable E.text)) <>
           ((\(_, _, _, _, _, _, _, _, _, _, createdAt, _, _) -> createdAt) >$< E.param (E.nonNullable E.timestamptz)) <>
           ((\(_, _, _, _, _, _, _, _, _, _, _, updatedAt, _) -> updatedAt) >$< E.param (E.nonNullable E.timestamptz)) <>
           ((\(_, _, _, _, _, _, _, _, _, _, _, _, createdBy) -> createdBy) >$< E.param (E.nullable E.text)))
          (D.singleRow workOrderRowDecoder)
  res <- use pool $ Session.statement (workOrderCode input, workOrderGoodsId input, workOrderParentId input, workOrderPlannedQtty input, workOrderFactQtty input, fromIntegral (workOrderStatus input), workOrderStartDate input, workOrderEndDate input, workOrderAssignedTo input, workOrderNote input, createTime, createTime, Nothing) stmt
  case res of
    Right order -> pure $ QuerySuccess order
    Left err -> pure $ QueryError (T.pack $ show err)

-- | Update an existing work order
updateWorkOrder :: Pool -> Int64 -> WorkOrder -> UTCTime -> Text -> IO (QueryResult WorkOrder)
updateWorkOrder pool woId input updateTime userId = do
  let stmt =
        preparable
          "UPDATE work_order SET code = $1, goods_id = $2, tech_card_id = $3, qty_plan = $4, qty_released = $5, status = $6, start_date = $7, end_date = $8, processor_id = $9, notes = $10, updated_at = $11, created_by = $12 WHERE id = $13 RETURNING id, code, goods_id, tech_card_id, qty_plan, qty_released, status, start_date, end_date, processor_id, notes, created_at, updated_at, created_by"
          (((\(code, _, _, _, _, _, _, _, _, _, _, _, _) -> code) >$< E.param (E.nonNullable E.text)) <>
           ((\(_, goodsId, _, _, _, _, _, _, _, _, _, _, _) -> goodsId) >$< E.param (E.nonNullable E.int8)) <>
           ((\(_, _, techCardId, _, _, _, _, _, _, _, _, _, _) -> techCardId) >$< E.param (E.nullable E.int8)) <>
           ((\(_, _, _, qtyPlan, _, _, _, _, _, _, _, _, _) -> realToFrac qtyPlan) >$< E.param (E.nonNullable E.numeric)) <>
           ((\(_, _, _, _, qtyReleased, _, _, _, _, _, _, _, _) -> realToFrac qtyReleased) >$< E.param (E.nonNullable E.numeric)) <>
           ((\(_, _, _, _, _, status, _, _, _, _, _, _, _) -> (fromIntegral status :: Int16)) >$< E.param (E.nonNullable E.int2)) <>
           ((\(_, _, _, _, _, _, startDate, _, _, _, _, _, _) -> startDate) >$< E.param (E.nullable E.date)) <>
           ((\(_, _, _, _, _, _, _, endDate, _, _, _, _, _) -> endDate) >$< E.param (E.nullable E.date)) <>
             ((\(_, _, _, _, _, _, _, _, processorId, _, _, _, _) -> processorId) >$< E.param (E.nullable E.int8)) <>
             ((\(_, _, _, _, _, _, _, _, _, notes, _, _, _) -> notes) >$< E.param (E.nullable E.text)) <>
             ((\(_, _, _, _, _, _, _, _, _, _, updatedAt, _, _) -> updatedAt) >$< E.param (E.nonNullable E.timestamptz)) <>
             ((\(_, _, _, _, _, _, _, _, _, _, _, createdBy, _) -> createdBy) >$< E.param (E.nullable E.text)) <>
             ((\(_, _, _, _, _, _, _, _, _, _, _, _, woId) -> woId) >$< E.param (E.nonNullable E.int8)))
           (D.singleRow workOrderRowDecoder)
  res <- use pool $ Session.statement (workOrderCode input, workOrderGoodsId input, workOrderParentId input, workOrderPlannedQtty input, workOrderFactQtty input, fromIntegral (workOrderStatus input), workOrderStartDate input, workOrderEndDate input, workOrderAssignedTo input, workOrderNote input, updateTime, Just userId, woId) stmt
  case res of
    Right order -> pure $ QuerySuccess order
    Left err -> pure $ QueryError (T.pack $ show err)

-- | Delete a work order
deleteWorkOrder :: Pool -> Int64 -> IO (QueryResult ())
deleteWorkOrder pool woId = do
  let stmt =
        preparable
          "DELETE FROM work_order WHERE id = $1"
          (E.param (E.nonNullable E.int8))
          (D.noResult)
  res <- use pool $ Session.statement woId stmt
  case res of
    Right () -> pure $ QuerySuccess ()
    Left err -> pure $ QueryError (T.pack $ show err)

-- | Release a work order
releaseWorkOrder :: Pool -> Int64 -> UTCTime -> Text -> IO (QueryResult WorkOrder)
releaseWorkOrder pool woId releaseTime userId = do
  let stmt =
        preparable
          "UPDATE work_order SET status = $1, start_at = $2, updated_at = $3, updated_by = $4 WHERE id = $5 RETURNING id, code, goods_id, tech_card_id, qty_plan, qty_released, status, start_date, end_date, processor_id, notes, created_at, updated_at, created_by"
          (((\(status, _, _, _, _) -> status) >$< E.param (E.nonNullable E.int2)) <>
           ((\(_, startTime, _, _, _) -> startTime) >$< E.param (E.nullable E.timestamptz)) <>
           ((\(_, _, updatedAt, _, _) -> updatedAt) >$< E.param (E.nonNullable E.timestamptz)) <>
           ((\(_, _, _, updatedBy, _) -> updatedBy) >$< E.param (E.nullable E.text)) <>
           ((\(_, _, _, _, woId) -> woId) >$< E.param (E.nonNullable E.int8)))
          (D.singleRow workOrderRowDecoder)
  res <- use pool $ Session.statement (fromIntegral (1 :: Int16), Just releaseTime, releaseTime, Just userId, woId) stmt
  case res of
    Right order -> pure $ QuerySuccess order
    Left err -> pure $ QueryError (T.pack $ show err)

-- | Complete a work order
completeWorkOrder :: Pool -> Int64 -> UTCTime -> Text -> IO (QueryResult WorkOrder)
completeWorkOrder pool woId completionTime userId = do
  let stmt =
        preparable
          "UPDATE work_order SET status = $1, end_at = $2, updated_at = $3, updated_by = $4 WHERE id = $5 RETURNING id, code, goods_id, tech_card_id, qty_plan, qty_released, status, start_date, end_date, processor_id, notes, created_at, updated_at, created_by"
          (((\(status, _, _, _, _) -> status) >$< E.param (E.nonNullable E.int2)) <>
           ((\(_, endTime, _, _, _) -> endTime) >$< E.param (E.nullable E.timestamptz)) <>
           ((\(_, _, updatedAt, _, _) -> updatedAt) >$< E.param (E.nonNullable E.timestamptz)) <>
           ((\(_, _, _, updatedBy, _) -> updatedBy) >$< E.param (E.nullable E.text)) <>
           ((\(_, _, _, _, woId) -> woId) >$< E.param (E.nonNullable E.int8)))
          (D.singleRow workOrderRowDecoder)
  res <- use pool $ Session.statement (fromIntegral (2 :: Int16), Just completionTime, completionTime, Just userId, woId) stmt
  case res of
    Right order -> pure $ QuerySuccess order
    Left err -> pure $ QueryError (T.pack $ show err)

-- | Get accounting turn by id
getAccTurnById :: Pool -> Int64 -> IO (QueryResult AccTurn)
getAccTurnById pool turnId = do
  let stmt =
        preparable
          "SELECT id, bill_id, dbt_acc_id, crd_acc_id, amount, date FROM acc_turn WHERE id = $1"
          (E.param (E.nonNullable E.int8))
          (D.rowMaybe accTurnRowDecoder)
  res <- use pool $ Session.statement turnId stmt
  case res of
    Right (Just turn) -> pure $ QuerySuccess turn
    Right Nothing -> pure $ QueryError "Not Found"
    Left err -> pure $ QueryError (T.pack $ show err)

-- | Job types for DAL
data JobRecord = JobRecord
  { jrId :: Int64,
    jrType :: Text,
    jrStatus :: Int,
    jrPayload :: Maybe Text,
    jrCreatedAt :: UTCTime
  }
  deriving (Show, Eq)

-- | Job row decoder
jobRowDecoder :: D.Row JobRecord
jobRowDecoder =
  JobRecord
    <$> D.column (D.nonNullable D.int8)
    <*> D.column (D.nonNullable D.text)
    <*> (fromIntegral <$> D.column (D.nonNullable D.int2))
    <*> D.column (D.nullable D.text)
    <*> D.column (D.nonNullable D.timestamptz)

-- | Get jobs from database
getJobs :: Pool -> IO (QueryResult [JobRecord])
getJobs pool = do
  let stmt =
        preparable
          "SELECT id, job_type, status, payload, created_at FROM jobs ORDER BY created_at DESC LIMIT 100"
          E.noParams
          (D.rowList jobRowDecoder)
  res <- use pool $ Session.statement () stmt
  case res of
    Right jobs -> pure $ QuerySuccess jobs
    Left err -> pure $ QueryError (T.pack $ show err)
