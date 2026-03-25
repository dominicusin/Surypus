-- | Database Mutations (Write operations)
module DAL.Mutations where

import DAL.Types
import Data.ByteString (ByteString)
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Encoding as T
import qualified Hasql.Decoders as D
import qualified Hasql.Encoders as E
import Hasql.Pool (Pool, use)
import qualified Hasql.Session as Session
import Hasql.Statement (unpreparable)
import Surypus.Types (Decimal (..))

escapeText :: String -> String
escapeText s = map (\c -> if c == '\'' then '\'' else c) s
  where
    -- Replace single quote with two single quotes for SQL
    -- Actually, let's just double the quote
    replaceQuote :: Char -> Char
    replaceQuote '\'' = '\'' -- This would double it in a raw string sense
    replaceQuote c = c

escapeSql :: String -> String
escapeSql [] = []
escapeSql ('\'' : rest) = '\'' : '\'' : escapeSql rest
escapeSql (c : rest) = c : escapeSql rest

renderMaybeText :: Maybe Text -> String
renderMaybeText Nothing = "NULL"
renderMaybeText (Just t) = "'" <> escapeSql (T.unpack t) <> "'"

renderMaybeInt64 :: Maybe Int64 -> String
renderMaybeInt64 Nothing = "NULL"
renderMaybeInt64 (Just i) = show i

renderDecimal :: Decimal -> String
renderDecimal (Decimal d) = show d

createPerson :: Pool -> PersonInput -> IO (QueryResult MutationResult)
createPerson pool input = do
  let codeVal = renderMaybeText (piCode input)
      nameVal = "'" <> escapeSql (T.unpack (piName input)) <> "'"
      innVal = renderMaybeText (piINN input)
      kppVal = renderMaybeText (piKPP input)
      personTypeVal = show (piPersonType input)
      statusVal = show (piStatus input)

      sql =
        T.pack $
          "INSERT INTO persons.person (code, name, inn, kpp, person_type, status) VALUES ("
            <> codeVal
            <> ", "
            <> nameVal
            <> ", "
            <> innVal
            <> ", "
            <> kppVal
            <> ", "
            <> personTypeVal
            <> ", "
            <> statusVal
            <> ") RETURNING id"

  let stmt = unpreparable sql E.noParams (D.singleRow (D.column (D.nonNullable D.int8)))
  res <- use pool $ Session.statement () stmt
  case res of
    Right pid -> pure $ QuerySuccess (MutationResult True (Just pid) (T.pack "Person created successfully"))
    Left err -> pure $ QueryError (T.pack $ show err)

updatePerson :: Pool -> Int64 -> PersonInput -> IO (QueryResult MutationResult)
updatePerson pool pid input = do
  let codeVal = renderMaybeText (piCode input)
      nameVal = "'" <> escapeSql (T.unpack (piName input)) <> "'"
      innVal = renderMaybeText (piINN input)
      kppVal = renderMaybeText (piKPP input)
      personTypeVal = show (piPersonType input)
      statusVal = show (piStatus input)

      sql =
        T.pack $
          "UPDATE persons.person SET code = "
            <> codeVal
            <> ", name = "
            <> nameVal
            <> ", inn = "
            <> innVal
            <> ", kpp = "
            <> kppVal
            <> ", person_type = "
            <> personTypeVal
            <> ", status = "
            <> statusVal
            <> " WHERE id = "
            <> show pid
            <> " RETURNING id"

  let stmt = unpreparable sql E.noParams (D.singleRow (D.column (D.nonNullable D.int8)))
  res <- use pool $ Session.statement () stmt
  case res of
    Right _ -> pure $ QuerySuccess (MutationResult True (Just pid) (T.pack "Person updated successfully"))
    Left err -> pure $ QueryError (T.pack $ show err)

deletePerson :: Pool -> Int64 -> IO (QueryResult MutationResult)
deletePerson pool pid = do
  let sql = T.pack $ "DELETE FROM persons.person WHERE id = " <> show pid <> " RETURNING id"
  let stmt = unpreparable sql E.noParams (D.singleRow (D.column (D.nonNullable D.int8)))
  res <- use pool $ Session.statement () stmt
  case res of
    Right _ -> pure $ QuerySuccess (MutationResult True (Just pid) (T.pack "Person deleted successfully"))
    Left err -> pure $ QueryError (T.pack $ show err)

createGoods :: Pool -> GoodsInput -> IO (QueryResult MutationResult)
createGoods pool input = do
  let codeVal = renderMaybeText (giCode input)
      nameVal = "'" <> escapeSql (T.unpack (giName input)) <> "'"
      barcodeVal = renderMaybeText (giBarcode input)
      unitIdVal = show (giUnitId input)
      parentIdVal = renderMaybeInt64 (giParentId input)

      sql =
        T.pack $
          "INSERT INTO goods (code, name, barcode, unit_id, parent_id) VALUES ("
            <> codeVal
            <> ", "
            <> nameVal
            <> ", "
            <> barcodeVal
            <> ", "
            <> unitIdVal
            <> ", "
            <> parentIdVal
            <> ") RETURNING id"

  let stmt = unpreparable sql E.noParams (D.singleRow (D.column (D.nonNullable D.int8)))
  res <- use pool $ Session.statement () stmt
  case res of
    Right gid -> pure $ QuerySuccess (MutationResult True (Just gid) (T.pack "Goods created successfully"))
    Left err -> pure $ QueryError (T.pack $ show err)

updateGoods :: Pool -> Int64 -> GoodsInput -> IO (QueryResult MutationResult)
updateGoods pool gid input = do
  let codeVal = renderMaybeText (giCode input)
      nameVal = "'" <> escapeSql (T.unpack (giName input)) <> "'"
      barcodeVal = renderMaybeText (giBarcode input)
      unitIdVal = show (giUnitId input)
      parentIdVal = renderMaybeInt64 (giParentId input)

      sql =
        T.pack $
          "UPDATE goods SET code = "
            <> codeVal
            <> ", name = "
            <> nameVal
            <> ", barcode = "
            <> barcodeVal
            <> ", unit_id = "
            <> unitIdVal
            <> ", parent_id = "
            <> parentIdVal
            <> " WHERE id = "
            <> show gid
            <> " RETURNING id"

  let stmt = unpreparable sql E.noParams (D.singleRow (D.column (D.nonNullable D.int8)))
  res <- use pool $ Session.statement () stmt
  case res of
    Right _ -> pure $ QuerySuccess (MutationResult True (Just gid) (T.pack "Goods updated successfully"))
    Left err -> pure $ QueryError (T.pack $ show err)

deleteGoods :: Pool -> Int64 -> IO (QueryResult MutationResult)
deleteGoods pool gid = do
  let sql = T.pack $ "DELETE FROM goods WHERE id = " <> show gid <> " RETURNING id"
  let stmt = unpreparable sql E.noParams (D.singleRow (D.column (D.nonNullable D.int8)))
  res <- use pool $ Session.statement () stmt
  case res of
    Right _ -> pure $ QuerySuccess (MutationResult True (Just gid) (T.pack "Goods deleted successfully"))
    Left err -> pure $ QueryError (T.pack $ show err)

createBill :: Pool -> BillInput -> IO (QueryResult MutationResult)
createBill pool input = do
  let codeVal = renderMaybeText (biCode input)
      typeVal = show (biType input)
      statusVal = show (biStatus input)
      dateVal = "'" <> show (biDate input) <> "'"
      personIdVal = renderMaybeInt64 (biPersonId input)
      locationIdVal = renderMaybeInt64 (biLocationId input)
      totalVal = renderDecimal (biTotal input)
      discountVal = renderDecimal (biDiscount input)
      taxVal = renderDecimal (biTax input)

      sql =
        T.pack $
          "INSERT INTO bill (code, bill_type, doc_status, doc_date, person_id, location_id, total, discount_amount, tax_amount) VALUES ("
            <> codeVal
            <> ", "
            <> typeVal
            <> ", "
            <> statusVal
            <> ", "
            <> dateVal
            <> ", "
            <> personIdVal
            <> ", "
            <> locationIdVal
            <> ", "
            <> totalVal
            <> ", "
            <> discountVal
            <> ", "
            <> taxVal
            <> ") RETURNING id"

  let stmt = unpreparable sql E.noParams (D.singleRow (D.column (D.nonNullable D.int8)))
  res <- use pool $ Session.statement () stmt
  case res of
    Right bid -> pure $ QuerySuccess (MutationResult True (Just bid) (T.pack "Bill created successfully"))
    Left err -> pure $ QueryError (T.pack $ show err)

updateBillStatus :: Pool -> Int64 -> Int -> IO (QueryResult MutationResult)
updateBillStatus pool bid status = do
  let sql = T.pack $ "UPDATE bill SET doc_status = " <> show status <> " WHERE id = " <> show bid <> " RETURNING id"
  let stmt = unpreparable sql E.noParams (D.singleRow (D.column (D.nonNullable D.int8)))
  res <- use pool $ Session.statement () stmt
  case res of
    Right _ -> pure $ QuerySuccess (MutationResult True (Just bid) (T.pack "Bill status updated"))
    Left err -> pure $ QueryError (T.pack $ show err)

postBill :: Pool -> Int64 -> IO (QueryResult MutationResult)
postBill pool bid = do
  let sql = T.pack $ "UPDATE bill SET doc_status = 2 WHERE id = " <> show bid <> " RETURNING id"
  let stmt = unpreparable sql E.noParams (D.singleRow (D.column (D.nonNullable D.int8)))
  res <- use pool $ Session.statement () stmt
  case res of
    Right _ -> pure $ QuerySuccess (MutationResult True (Just bid) (T.pack "Bill posted successfully"))
    Left err -> pure $ QueryError (T.pack $ show err)

addBillLine :: Pool -> Int64 -> BillLineInput -> IO (QueryResult MutationResult)
addBillLine pool bid input = do
  let goodsIdVal = show (bliGoodsId input)
      qttyVal = renderDecimal (bliQtty input)
      priceVal = renderDecimal (bliPrice input)
      discountVal = renderDecimal (bliDiscount input)
      amountVal = renderDecimal (bliAmount input)

      sql =
        T.pack $
          "INSERT INTO bill_line (bill_id, goods_id, qtty, price, discount_amount, amount) VALUES ("
            <> show bid
            <> ", "
            <> goodsIdVal
            <> ", "
            <> qttyVal
            <> ", "
            <> priceVal
            <> ", "
            <> discountVal
            <> ", "
            <> amountVal
            <> ") RETURNING id"

  let stmt = unpreparable sql E.noParams (D.singleRow (D.column (D.nonNullable D.int8)))
  res <- use pool $ Session.statement () stmt
  case res of
    Right blid -> pure $ QuerySuccess (MutationResult True (Just blid) (T.pack "Bill line added"))
    Left err -> pure $ QueryError (T.pack $ show err)

deleteBillLine :: Pool -> Int64 -> IO (QueryResult MutationResult)
deleteBillLine pool blid = do
  let sql = T.pack $ "DELETE FROM bill_line WHERE id = " <> show blid <> " RETURNING id"
  let stmt = unpreparable sql E.noParams (D.singleRow (D.column (D.nonNullable D.int8)))
  res <- use pool $ Session.statement () stmt
  case res of
    Right _ -> pure $ QuerySuccess (MutationResult True (Just blid) (T.pack "Bill line deleted"))
    Left err -> pure $ QueryError (T.pack $ show err)

deleteBill :: Pool -> Int64 -> IO (QueryResult MutationResult)
deleteBill pool bid = do
  let sql = T.pack $ "DELETE FROM bill WHERE id = " <> show bid <> " RETURNING id"
  let stmt = unpreparable sql E.noParams (D.singleRow (D.column (D.nonNullable D.int8)))
  res <- use pool $ Session.statement () stmt
  case res of
    Right _ -> pure $ QuerySuccess (MutationResult True (Just bid) (T.pack "Bill deleted"))
    Left err -> pure $ QueryError (T.pack $ show err)

createLocation :: Pool -> LocationInput -> IO (QueryResult MutationResult)
createLocation pool input = do
  let codeVal = renderMaybeText (liCode input)
      nameVal = "'" <> escapeSql (T.unpack (liName input)) <> "'"
      typeVal = show (liType input)

      sql =
        T.pack $
          "INSERT INTO location (code, name, location_type) VALUES ("
            <> codeVal
            <> ", "
            <> nameVal
            <> ", "
            <> typeVal
            <> ") RETURNING id"

  let stmt = unpreparable sql E.noParams (D.singleRow (D.column (D.nonNullable D.int8)))
  res <- use pool $ Session.statement () stmt
  case res of
    Right lid -> pure $ QuerySuccess (MutationResult True (Just lid) (T.pack "Location created successfully"))
    Left err -> pure $ QueryError (T.pack $ show err)

updateLocation :: Pool -> Int64 -> LocationInput -> IO (QueryResult MutationResult)
updateLocation pool lid input = do
  let codeVal = renderMaybeText (liCode input)
      nameVal = "'" <> escapeSql (T.unpack (liName input)) <> "'"
      typeVal = show (liType input)

      sql =
        T.pack $
          "UPDATE location SET code = "
            <> codeVal
            <> ", name = "
            <> nameVal
            <> ", location_type = "
            <> typeVal
            <> " WHERE id = "
            <> show lid
            <> " RETURNING id"

  let stmt = unpreparable sql E.noParams (D.singleRow (D.column (D.nonNullable D.int8)))
  res <- use pool $ Session.statement () stmt
  case res of
    Right _ -> pure $ QuerySuccess (MutationResult True (Just lid) (T.pack "Location updated successfully"))
    Left err -> pure $ QueryError (T.pack $ show err)

deleteLocation :: Pool -> Int64 -> IO (QueryResult MutationResult)
deleteLocation pool lid = do
  let sql = T.pack $ "DELETE FROM location WHERE id = " <> show lid <> " RETURNING id"
  let stmt = unpreparable sql E.noParams (D.singleRow (D.column (D.nonNullable D.int8)))
  res <- use pool $ Session.statement () stmt
  case res of
    Right _ -> pure $ QuerySuccess (MutationResult True (Just lid) (T.pack "Location deleted successfully"))
    Left err -> pure $ QueryError (T.pack $ show err)

updateStock :: Pool -> Int64 -> Int64 -> Decimal -> IO (QueryResult MutationResult)
updateStock pool goodsId locationId qty = do
  let sql =
        T.pack $
          "UPDATE stock SET qtty = "
            <> renderDecimal qty
            <> " WHERE goods_id = "
            <> show goodsId
            <> " AND location_id = "
            <> show locationId
            <> " RETURNING id"
  let stmt = unpreparable sql E.noParams (D.singleRow (D.column (D.nonNullable D.int8)))
  res <- use pool $ Session.statement () stmt
  case res of
    Right sid -> pure $ QuerySuccess (MutationResult True (Just sid) (T.pack "Stock updated"))
    Left err -> pure $ QueryError (T.pack $ show err)

reserveStock :: Pool -> Int64 -> Int64 -> Decimal -> IO (QueryResult MutationResult)
reserveStock pool goodsId locationId qty = do
  let sql =
        T.pack $
          "UPDATE stock SET resrv_qtty = resrv_qtty + "
            <> renderDecimal qty
            <> " WHERE goods_id = "
            <> show goodsId
            <> " AND location_id = "
            <> show locationId
            <> " RETURNING id"
  let stmt = unpreparable sql E.noParams (D.singleRow (D.column (D.nonNullable D.int8)))
  res <- use pool $ Session.statement () stmt
  case res of
    Right sid -> pure $ QuerySuccess (MutationResult True (Just sid) (T.pack "Stock reserved"))
    Left err -> pure $ QueryError (T.pack $ show err)

releaseStock :: Pool -> Int64 -> Int64 -> Decimal -> IO (QueryResult MutationResult)
releaseStock pool goodsId locationId qty = do
  let sql =
        T.pack $
          "UPDATE stock SET resrv_qtty = resrv_qtty - "
            <> renderDecimal qty
            <> " WHERE goods_id = "
            <> show goodsId
            <> " AND location_id = "
            <> show locationId
            <> " AND resrv_qtty >= "
            <> renderDecimal qty
            <> " RETURNING id"
  let stmt = unpreparable sql E.noParams (D.singleRow (D.column (D.nonNullable D.int8)))
  res <- use pool $ Session.statement () stmt
  case res of
    Right sid -> pure $ QuerySuccess (MutationResult True (Just sid) (T.pack "Stock released"))
    Left err -> pure $ QueryError (T.pack $ show err)

createOrder :: Pool -> OrderInput -> IO (QueryResult MutationResult)
createOrder pool input = do
  let codeVal = renderMaybeText (oiCode input)
      nameVal = renderMaybeText (oiName input)
      dateVal = "'" <> show (oiDate input) <> "'"
      personIdVal = renderMaybeInt64 (oiPersonId input)
      locationIdVal = renderMaybeInt64 (oiLocationId input)
      statusVal = show (oiStatus input)
      totalVal = renderDecimal (oiTotal input)
      discountVal = renderDecimal (oiDiscount input)
      taxVal = renderDecimal (oiTax input)

      sql =
        T.pack $
          "INSERT INTO order_head (code, name, doc_date, person_id, location_id, doc_status, total, discount_amount, tax_amount) VALUES ("
            <> codeVal
            <> ", "
            <> nameVal
            <> ", "
            <> dateVal
            <> ", "
            <> personIdVal
            <> ", "
            <> locationIdVal
            <> ", "
            <> statusVal
            <> ", "
            <> totalVal
            <> ", "
            <> discountVal
            <> ", "
            <> taxVal
            <> ") RETURNING id"

  let stmt = unpreparable sql E.noParams (D.singleRow (D.column (D.nonNullable D.int8)))
  res <- use pool $ Session.statement () stmt
  case res of
    Right oid -> pure $ QuerySuccess (MutationResult True (Just oid) (T.pack "Order created successfully"))
    Left err -> pure $ QueryError (T.pack $ show err)

updateOrderStatus :: Pool -> Int64 -> Int -> IO (QueryResult MutationResult)
updateOrderStatus pool oid status = do
  let sql = T.pack $ "UPDATE order_head SET doc_status = " <> show status <> " WHERE id = " <> show oid <> " RETURNING id"
  let stmt = unpreparable sql E.noParams (D.singleRow (D.column (D.nonNullable D.int8)))
  res <- use pool $ Session.statement () stmt
  case res of
    Right _ -> pure $ QuerySuccess (MutationResult True (Just oid) (T.pack "Order status updated"))
    Left err -> pure $ QueryError (T.pack $ show err)

deleteOrder :: Pool -> Int64 -> IO (QueryResult MutationResult)
deleteOrder pool oid = do
  let sql = T.pack $ "DELETE FROM order_head WHERE id = " <> show oid <> " RETURNING id"
  let stmt = unpreparable sql E.noParams (D.singleRow (D.column (D.nonNullable D.int8)))
  res <- use pool $ Session.statement () stmt
  case res of
    Right _ -> pure $ QuerySuccess (MutationResult True (Just oid) (T.pack "Order deleted"))
    Left err -> pure $ QueryError (T.pack $ show err)

createPayment :: Pool -> PaymentInput -> IO (QueryResult MutationResult)
createPayment pool input = do
  let billIdVal = show (piBillId input)
      payDateVal = "'" <> show (piPayDate input) <> "'"
      amountVal = show (piAmount input)
      payMethodVal = show (piPayMethod input)
      payStatusVal = show (piPayStatus input)
      sql =
        T.pack $
          "INSERT INTO payment (bill_id, pay_date, amount, pay_method, pay_status) VALUES ("
            <> billIdVal
            <> ", "
            <> payDateVal
            <> ", "
            <> amountVal
            <> ", "
            <> payMethodVal
            <> ", "
            <> payStatusVal
            <> ") RETURNING id"
  let stmt = unpreparable sql E.noParams (D.singleRow (D.column (D.nonNullable D.int8)))
  res <- use pool $ Session.statement () stmt
  case res of
    Right pid -> pure $ QuerySuccess (MutationResult True (Just pid) (T.pack "Payment created successfully"))
    Left err -> pure $ QueryError (T.pack $ show err)

createUser :: Pool -> User -> IO (QueryResult MutationResult)
createUser _ _ = pure $ QuerySuccess (MutationResult True (Just 0) (T.pack "User stub - not implemented"))

updateUser :: Pool -> User -> IO (QueryResult MutationResult)
updateUser _ _ = pure $ QuerySuccess (MutationResult True Nothing (T.pack "User stub - not implemented"))

authenticateUser :: Pool -> Text -> Text -> IO (QueryResult (Maybe User))
authenticateUser _ _ _ = pure $ QuerySuccess Nothing

-- Price mutations
createPrice :: Pool -> PriceInput -> IO (QueryResult MutationResult)
createPrice pool input = do
  let goodsIdVal = show (priGoodsId input)
      priceTypeVal = show (priPriceType input)
      priceVal = renderDecimal (priPrice input)
      currencyIdVal = show (priCurrencyId input)
      fromDateVal = "'" <> show (priFromDate input) <> "'"
      toDateVal = case priToDate input of
        Just d -> "'" <> show d <> "'"
        Nothing -> "NULL"

      sql =
        T.pack $
          "INSERT INTO goods_price (goods_id, price_type, price, currency_id, from_date, to_date) VALUES ("
            <> goodsIdVal
            <> ", "
            <> priceTypeVal
            <> ", "
            <> priceVal
            <> ", "
            <> currencyIdVal
            <> ", "
            <> fromDateVal
            <> ", "
            <> toDateVal
            <> ") RETURNING id"

  let stmt = unpreparable sql E.noParams (D.singleRow (D.column (D.nonNullable D.int8)))
  res <- use pool $ Session.statement () stmt
  case res of
    Right pid -> pure $ QuerySuccess (MutationResult True (Just pid) (T.pack "Price created"))
    Left err -> pure $ QueryError (T.pack $ show err)

-- Tax mutations
createTax :: Pool -> TaxInput -> IO (QueryResult MutationResult)
createTax pool input = do
  let nameVal = "'" <> escapeSql (T.unpack (tiName input)) <> "'"
      rateVal = show (tiRate input)
      taxTypeVal = show (tiTaxType input)
      includedVal = if tiIncluded input then "TRUE" else "FALSE"

      sql =
        T.pack $
          "INSERT INTO tax (name, rate, tax_type, is_included) VALUES ("
            <> nameVal
            <> ", "
            <> rateVal
            <> ", "
            <> taxTypeVal
            <> ", "
            <> includedVal
            <> ") RETURNING id"

  let stmt = unpreparable sql E.noParams (D.singleRow (D.column (D.nonNullable D.int8)))
  res <- use pool $ Session.statement () stmt
  case res of
    Right tid -> pure $ QuerySuccess (MutationResult True (Just tid) (T.pack "Tax created"))
    Left err -> pure $ QueryError (T.pack $ show err)

-- Currency mutations
createCurrency :: Pool -> CurrencyInput -> IO (QueryResult MutationResult)
createCurrency pool input = do
  let codeVal = "'" <> escapeSql (T.unpack (ciCode input)) <> "'"
      nameVal = "'" <> escapeSql (T.unpack (ciName input)) <> "'"
      symbolVal = "'" <> escapeSql (T.unpack (ciSymbol input)) <> "'"
      rateVal = show (ciRate input)

      sql =
        T.pack $
          "INSERT INTO currency (code, name, symbol, rate) VALUES ("
            <> codeVal
            <> ", "
            <> nameVal
            <> ", "
            <> symbolVal
            <> ", "
            <> rateVal
            <> ") RETURNING id"

  let stmt = unpreparable sql E.noParams (D.singleRow (D.column (D.nonNullable D.int8)))
  res <- use pool $ Session.statement () stmt
  case res of
    Right cid -> pure $ QuerySuccess (MutationResult True (Just cid) (T.pack "Currency created"))
    Left err -> pure $ QueryError (T.pack $ show err)

deleteTax :: Pool -> Int64 -> IO (QueryResult MutationResult)
deleteTax pool tid = do
  let sql = T.pack $ "DELETE FROM tax WHERE id = " <> show tid <> " RETURNING id"
  let stmt = unpreparable sql E.noParams (D.singleRow (D.column (D.nonNullable D.int8)))
  res <- use pool $ Session.statement () stmt
  case res of
    Right _ -> pure $ QuerySuccess (MutationResult True Nothing (T.pack "Tax deleted"))
    Left err -> pure $ QueryError (T.pack $ show err)

deleteCurrency :: Pool -> Int64 -> IO (QueryResult MutationResult)
deleteCurrency pool cid = do
  let sql = T.pack $ "DELETE FROM currency WHERE id = " <> show cid <> " RETURNING id"
  let stmt = unpreparable sql E.noParams (D.singleRow (D.column (D.nonNullable D.int8)))
  res <- use pool $ Session.statement () stmt
  case res of
    Right _ -> pure $ QuerySuccess (MutationResult True Nothing (T.pack "Currency deleted"))
    Left err -> pure $ QueryError (T.pack $ show err)
