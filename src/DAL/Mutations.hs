{-# LANGUAGE OverloadedStrings #-}

-- | Database Mutations (Write operations)
module DAL.Mutations where

import DAL.Types
import Data.Functor.Contravariant ((>$<))
import Data.Int (Int16, Int64)
import Data.Text (Text)
import qualified Data.Text as T
import qualified Hasql.Decoders as D
import qualified Hasql.Encoders as E
import Hasql.Pool (Pool, use)
import qualified Hasql.Session as Session
import Hasql.Statement (unpreparable)
import Surypus.Types (Decimal, fromDecimal)

mutationIdDecoder :: D.Result Int64
mutationIdDecoder = D.singleRow (D.column (D.nonNullable D.int8))

toInt16 :: Int -> Int16
toInt16 = fromIntegral

toDouble :: Decimal -> Double
toDouble = fromDecimal

runMutationReturningId :: Pool -> Text -> E.Params params -> params -> Text -> IO (QueryResult MutationResult)
runMutationReturningId pool sql encoder payload successMessage = do
  let stmt = unpreparable sql encoder mutationIdDecoder
  res <- use pool $ Session.statement payload stmt
  case res of
    Right rid -> pure $ QuerySuccess (MutationResult True (Just rid) successMessage)
    Left err -> pure $ QueryError (T.pack (show err))

personInputEncoder :: E.Params PersonInput
personInputEncoder =
  (piCode >$< E.param (E.nullable E.text))
    <> (piName >$< E.param (E.nonNullable E.text))
    <> (piINN >$< E.param (E.nullable E.text))
    <> (piKPP >$< E.param (E.nullable E.text))
    <> (piPersonType >$< E.param (E.nonNullable E.int2))
    <> (piStatus >$< E.param (E.nonNullable E.int2))

updatePersonEncoder :: E.Params (Int64, PersonInput)
updatePersonEncoder =
  (fst >$< E.param (E.nonNullable E.int8))
    <> ((piCode . snd) >$< E.param (E.nullable E.text))
    <> ((piName . snd) >$< E.param (E.nonNullable E.text))
    <> ((piINN . snd) >$< E.param (E.nullable E.text))
    <> ((piKPP . snd) >$< E.param (E.nullable E.text))
    <> ((piPersonType . snd) >$< E.param (E.nonNullable E.int2))
    <> ((piStatus . snd) >$< E.param (E.nonNullable E.int2))

createPerson :: Pool -> PersonInput -> IO (QueryResult MutationResult)
createPerson pool input =
  runMutationReturningId
    pool
    "INSERT INTO persons.person (code, name, inn, kpp, person_type, status) VALUES ($1, $2, $3, $4, $5, $6) RETURNING id"
    personInputEncoder
    input
    "Person created successfully"

updatePerson :: Pool -> Int64 -> PersonInput -> IO (QueryResult MutationResult)
updatePerson pool pid input =
  runMutationReturningId
    pool
    "UPDATE persons.person SET code = $2, name = $3, inn = $4, kpp = $5, person_type = $6, status = $7 WHERE id = $1 RETURNING id"
    updatePersonEncoder
    (pid, input)
    "Person updated successfully"

deletePerson :: Pool -> Int64 -> IO (QueryResult MutationResult)
deletePerson pool pid =
  runMutationReturningId
    pool
    "DELETE FROM persons.person WHERE id = $1 RETURNING id"
    (E.param (E.nonNullable E.int8))
    pid
    "Person deleted successfully"

goodsInputEncoder :: E.Params GoodsInput
goodsInputEncoder =
  (giCode >$< E.param (E.nullable E.text))
    <> (giName >$< E.param (E.nonNullable E.text))
    <> (giBarcode >$< E.param (E.nullable E.text))
    <> (giUnitId >$< E.param (E.nonNullable E.int8))
    <> (giParentId >$< E.param (E.nullable E.int8))

updateGoodsEncoder :: E.Params (Int64, GoodsInput)
updateGoodsEncoder =
  (fst >$< E.param (E.nonNullable E.int8))
    <> ((giCode . snd) >$< E.param (E.nullable E.text))
    <> ((giName . snd) >$< E.param (E.nonNullable E.text))
    <> ((giBarcode . snd) >$< E.param (E.nullable E.text))
    <> ((giUnitId . snd) >$< E.param (E.nonNullable E.int8))
    <> ((giParentId . snd) >$< E.param (E.nullable E.int8))

createGoods :: Pool -> GoodsInput -> IO (QueryResult MutationResult)
createGoods pool input =
  runMutationReturningId
    pool
    "INSERT INTO goods (code, name, barcode, unit_id, parent_id) VALUES ($1, $2, $3, $4, $5) RETURNING id"
    goodsInputEncoder
    input
    "Goods created successfully"

updateGoods :: Pool -> Int64 -> GoodsInput -> IO (QueryResult MutationResult)
updateGoods pool gid input =
  runMutationReturningId
    pool
    "UPDATE goods SET code = $2, name = $3, barcode = $4, unit_id = $5, parent_id = $6 WHERE id = $1 RETURNING id"
    updateGoodsEncoder
    (gid, input)
    "Goods updated successfully"

deleteGoods :: Pool -> Int64 -> IO (QueryResult MutationResult)
deleteGoods pool gid =
  runMutationReturningId
    pool
    "DELETE FROM goods WHERE id = $1 RETURNING id"
    (E.param (E.nonNullable E.int8))
    gid
    "Goods deleted successfully"

billInputEncoder :: E.Params BillInput
billInputEncoder =
  (biCode >$< E.param (E.nullable E.text))
    <> ((toInt16 . biType) >$< E.param (E.nonNullable E.int2))
    <> ((toInt16 . biStatus) >$< E.param (E.nonNullable E.int2))
    <> (biDate >$< E.param (E.nonNullable E.date))
    <> (biPersonId >$< E.param (E.nullable E.int8))
    <> (biLocationId >$< E.param (E.nullable E.int8))
    <> ((toDouble . biTotal) >$< E.param (E.nonNullable E.float8))
    <> ((toDouble . biDiscount) >$< E.param (E.nonNullable E.float8))
    <> ((toDouble . biTax) >$< E.param (E.nonNullable E.float8))

createBill :: Pool -> BillInput -> IO (QueryResult MutationResult)
createBill pool input =
  runMutationReturningId
    pool
    "INSERT INTO bill (code, bill_type, doc_status, doc_date, person_id, location_id, total, discount_amount, tax_amount) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9) RETURNING id"
    billInputEncoder
    input
    "Bill created successfully"

updateBillStatus :: Pool -> Int64 -> Int -> IO (QueryResult MutationResult)
updateBillStatus pool bid status =
  runMutationReturningId
    pool
    "UPDATE bill SET doc_status = $2 WHERE id = $1 RETURNING id"
    ( (fst >$< E.param (E.nonNullable E.int8))
        <> (snd >$< E.param (E.nonNullable E.int2))
    )
    (bid, toInt16 status)
    "Bill status updated"

postBill :: Pool -> Int64 -> IO (QueryResult MutationResult)
postBill pool bid =
  runMutationReturningId
    pool
    "UPDATE bill SET doc_status = 2 WHERE id = $1 RETURNING id"
    (E.param (E.nonNullable E.int8))
    bid
    "Bill posted successfully"

addBillLineEncoder :: E.Params (Int64, BillLineInput)
addBillLineEncoder =
  (fst >$< E.param (E.nonNullable E.int8))
    <> ((bliGoodsId . snd) >$< E.param (E.nonNullable E.int8))
    <> ((toDouble . bliQtty . snd) >$< E.param (E.nonNullable E.float8))
    <> ((toDouble . bliPrice . snd) >$< E.param (E.nonNullable E.float8))
    <> ((toDouble . bliDiscount . snd) >$< E.param (E.nonNullable E.float8))
    <> ((toDouble . bliAmount . snd) >$< E.param (E.nonNullable E.float8))

addBillLine :: Pool -> Int64 -> BillLineInput -> IO (QueryResult MutationResult)
addBillLine pool bid input =
  runMutationReturningId
    pool
    "INSERT INTO bill_line (bill_id, goods_id, qtty, price, discount_amount, amount) VALUES ($1, $2, $3, $4, $5, $6) RETURNING id"
    addBillLineEncoder
    (bid, input)
    "Bill line added"

deleteBillLine :: Pool -> Int64 -> IO (QueryResult MutationResult)
deleteBillLine pool blid =
  runMutationReturningId
    pool
    "DELETE FROM bill_line WHERE id = $1 RETURNING id"
    (E.param (E.nonNullable E.int8))
    blid
    "Bill line deleted"

deleteBill :: Pool -> Int64 -> IO (QueryResult MutationResult)
deleteBill pool bid =
  runMutationReturningId
    pool
    "DELETE FROM bill WHERE id = $1 RETURNING id"
    (E.param (E.nonNullable E.int8))
    bid
    "Bill deleted"

locationInputEncoder :: E.Params LocationInput
locationInputEncoder =
  (liCode >$< E.param (E.nullable E.text))
    <> (liName >$< E.param (E.nonNullable E.text))
    <> ((toInt16 . liType) >$< E.param (E.nonNullable E.int2))

updateLocationEncoder :: E.Params (Int64, LocationInput)
updateLocationEncoder =
  (fst >$< E.param (E.nonNullable E.int8))
    <> ((liCode . snd) >$< E.param (E.nullable E.text))
    <> ((liName . snd) >$< E.param (E.nonNullable E.text))
    <> ((toInt16 . liType . snd) >$< E.param (E.nonNullable E.int2))

createLocation :: Pool -> LocationInput -> IO (QueryResult MutationResult)
createLocation pool input =
  runMutationReturningId
    pool
    "INSERT INTO location (code, name, location_type) VALUES ($1, $2, $3) RETURNING id"
    locationInputEncoder
    input
    "Location created successfully"

updateLocation :: Pool -> Int64 -> LocationInput -> IO (QueryResult MutationResult)
updateLocation pool lid input =
  runMutationReturningId
    pool
    "UPDATE location SET code = $2, name = $3, location_type = $4 WHERE id = $1 RETURNING id"
    updateLocationEncoder
    (lid, input)
    "Location updated successfully"

deleteLocation :: Pool -> Int64 -> IO (QueryResult MutationResult)
deleteLocation pool lid =
  runMutationReturningId
    pool
    "DELETE FROM location WHERE id = $1 RETURNING id"
    (E.param (E.nonNullable E.int8))
    lid
    "Location deleted successfully"

stockQtyEncoder :: E.Params (Decimal, Int64, Int64)
stockQtyEncoder =
  ((toDouble . (\(qty, _, _) -> qty)) >$< E.param (E.nonNullable E.float8))
    <> ((\(_, goodsId, _) -> goodsId) >$< E.param (E.nonNullable E.int8))
    <> ((\(_, _, locationId) -> locationId) >$< E.param (E.nonNullable E.int8))

updateStock :: Pool -> Int64 -> Int64 -> Decimal -> IO (QueryResult MutationResult)
updateStock pool goodsId locationId qty =
  runMutationReturningId
    pool
    "UPDATE stock SET qtty = $1 WHERE goods_id = $2 AND location_id = $3 RETURNING id"
    stockQtyEncoder
    (qty, goodsId, locationId)
    "Stock updated"

reserveStock :: Pool -> Int64 -> Int64 -> Decimal -> IO (QueryResult MutationResult)
reserveStock pool goodsId locationId qty =
  runMutationReturningId
    pool
    "UPDATE stock SET resrv_qtty = resrv_qtty + $1 WHERE goods_id = $2 AND location_id = $3 RETURNING id"
    stockQtyEncoder
    (qty, goodsId, locationId)
    "Stock reserved"

releaseStock :: Pool -> Int64 -> Int64 -> Decimal -> IO (QueryResult MutationResult)
releaseStock pool goodsId locationId qty =
  runMutationReturningId
    pool
    "UPDATE stock SET resrv_qtty = resrv_qtty - $1 WHERE goods_id = $2 AND location_id = $3 AND resrv_qtty >= $1 RETURNING id"
    stockQtyEncoder
    (qty, goodsId, locationId)
    "Stock released"

orderInputEncoder :: E.Params OrderInput
orderInputEncoder =
  (oiCode >$< E.param (E.nullable E.text))
    <> (oiName >$< E.param (E.nullable E.text))
    <> (oiDate >$< E.param (E.nonNullable E.date))
    <> (oiPersonId >$< E.param (E.nullable E.int8))
    <> (oiLocationId >$< E.param (E.nullable E.int8))
    <> ((toInt16 . oiStatus) >$< E.param (E.nonNullable E.int2))
    <> ((toDouble . oiTotal) >$< E.param (E.nonNullable E.float8))
    <> ((toDouble . oiDiscount) >$< E.param (E.nonNullable E.float8))
    <> ((toDouble . oiTax) >$< E.param (E.nonNullable E.float8))

createOrder :: Pool -> OrderInput -> IO (QueryResult MutationResult)
createOrder pool input =
  runMutationReturningId
    pool
    "INSERT INTO order_head (code, name, doc_date, person_id, location_id, doc_status, total, discount_amount, tax_amount) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9) RETURNING id"
    orderInputEncoder
    input
    "Order created successfully"

updateOrderStatus :: Pool -> Int64 -> Int -> IO (QueryResult MutationResult)
updateOrderStatus pool oid status =
  runMutationReturningId
    pool
    "UPDATE order_head SET doc_status = $2 WHERE id = $1 RETURNING id"
    ( (fst >$< E.param (E.nonNullable E.int8))
        <> (snd >$< E.param (E.nonNullable E.int2))
    )
    (oid, toInt16 status)
    "Order status updated"

deleteOrder :: Pool -> Int64 -> IO (QueryResult MutationResult)
deleteOrder pool oid =
  runMutationReturningId
    pool
    "DELETE FROM order_head WHERE id = $1 RETURNING id"
    (E.param (E.nonNullable E.int8))
    oid
    "Order deleted"

paymentInputEncoder :: E.Params PaymentInput
paymentInputEncoder =
  (piBillId >$< E.param (E.nonNullable E.int8))
    <> (piPayDate >$< E.param (E.nonNullable E.date))
    <> (piAmount >$< E.param (E.nonNullable E.float8))
    <> ((toInt16 . piPayMethod) >$< E.param (E.nonNullable E.int2))
    <> ((toInt16 . piPayStatus) >$< E.param (E.nonNullable E.int2))

updatePaymentEncoder :: E.Params (Int64, PaymentInput)
updatePaymentEncoder =
  (fst >$< E.param (E.nonNullable E.int8))
    <> ((piBillId . snd) >$< E.param (E.nonNullable E.int8))
    <> ((piPayDate . snd) >$< E.param (E.nonNullable E.date))
    <> ((piAmount . snd) >$< E.param (E.nonNullable E.float8))
    <> ((toInt16 . piPayMethod . snd) >$< E.param (E.nonNullable E.int2))
    <> ((toInt16 . piPayStatus . snd) >$< E.param (E.nonNullable E.int2))

createPayment :: Pool -> PaymentInput -> IO (QueryResult MutationResult)
createPayment pool input =
  runMutationReturningId
    pool
    "INSERT INTO payment (bill_id, date, amount, payment_method, payment_status) VALUES ($1, $2, $3, $4, $5) RETURNING id"
    paymentInputEncoder
    input
    "Payment created successfully"

updatePayment :: Pool -> Int64 -> PaymentInput -> IO (QueryResult MutationResult)
updatePayment pool paymentId input =
  runMutationReturningId
    pool
    "UPDATE payment SET bill_id = $2, date = $3, amount = $4, payment_method = $5, payment_status = $6 WHERE id = $1 RETURNING id"
    updatePaymentEncoder
    (paymentId, input)
    "Payment updated successfully"

deletePayment :: Pool -> Int64 -> IO (QueryResult MutationResult)
deletePayment pool paymentId =
  runMutationReturningId
    pool
    "DELETE FROM payment WHERE id = $1 RETURNING id"
    (E.param (E.nonNullable E.int8))
    paymentId
    "Payment deleted"

createUser :: Pool -> User -> IO (QueryResult MutationResult)
createUser _ _ = pure $ QuerySuccess (MutationResult True (Just 0) "User stub - not implemented")

updateUser :: Pool -> User -> IO (QueryResult MutationResult)
updateUser _ _ = pure $ QuerySuccess (MutationResult True Nothing "User stub - not implemented")

authenticateUser :: Pool -> Text -> Text -> IO (QueryResult (Maybe User))
authenticateUser _ _ _ = pure $ QuerySuccess Nothing

priceInputEncoder :: E.Params PriceInput
priceInputEncoder =
  (priGoodsId >$< E.param (E.nonNullable E.int8))
    <> ((toInt16 . priPriceType) >$< E.param (E.nonNullable E.int2))
    <> ((toDouble . priPrice) >$< E.param (E.nonNullable E.float8))
    <> (priCurrencyId >$< E.param (E.nonNullable E.int8))
    <> (priFromDate >$< E.param (E.nonNullable E.date))
    <> (priToDate >$< E.param (E.nullable E.date))

createPrice :: Pool -> PriceInput -> IO (QueryResult MutationResult)
createPrice pool input =
  runMutationReturningId
    pool
    "INSERT INTO goods_price (goods_id, price_type, price, currency_id, valid_from, valid_to) VALUES ($1, $2, $3, $4, $5, $6) RETURNING id"
    priceInputEncoder
    input
    "Price created"

taxInputEncoder :: E.Params TaxInput
taxInputEncoder =
  (tiName >$< E.param (E.nonNullable E.text))
    <> (tiRate >$< E.param (E.nonNullable E.float8))
    <> ((toInt16 . tiTaxType) >$< E.param (E.nonNullable E.int2))
    <> (tiIncluded >$< E.param (E.nonNullable E.bool))

updateTaxEncoder :: E.Params (Int64, TaxInput)
updateTaxEncoder =
  (fst >$< E.param (E.nonNullable E.int8))
    <> ((tiName . snd) >$< E.param (E.nonNullable E.text))
    <> ((tiRate . snd) >$< E.param (E.nonNullable E.float8))
    <> ((toInt16 . tiTaxType . snd) >$< E.param (E.nonNullable E.int2))
    <> ((tiIncluded . snd) >$< E.param (E.nonNullable E.bool))

createTax :: Pool -> TaxInput -> IO (QueryResult MutationResult)
createTax pool input =
  runMutationReturningId
    pool
    "INSERT INTO tax (name, obj_type, rate, tax_type, is_included) VALUES ($1, 'tax', $2, $3, $4) RETURNING id"
    taxInputEncoder
    input
    "Tax created"

updateTax :: Pool -> Int64 -> TaxInput -> IO (QueryResult MutationResult)
updateTax pool tid input =
  runMutationReturningId
    pool
    "UPDATE tax SET name = $2, rate = $3, tax_type = $4, is_included = $5 WHERE id = $1 RETURNING id"
    updateTaxEncoder
    (tid, input)
    "Tax updated"

currencyInputEncoder :: E.Params CurrencyInput
currencyInputEncoder =
  (ciCode >$< E.param (E.nonNullable E.text))
    <> (ciName >$< E.param (E.nonNullable E.text))
    <> (ciSymbol >$< E.param (E.nonNullable E.text))
    <> (ciRate >$< E.param (E.nonNullable E.float8))

updateCurrencyEncoder :: E.Params (Int64, CurrencyInput)
updateCurrencyEncoder =
  (fst >$< E.param (E.nonNullable E.int8))
    <> ((ciCode . snd) >$< E.param (E.nonNullable E.text))
    <> ((ciName . snd) >$< E.param (E.nonNullable E.text))
    <> ((ciSymbol . snd) >$< E.param (E.nonNullable E.text))
    <> ((ciRate . snd) >$< E.param (E.nonNullable E.float8))

createCurrency :: Pool -> CurrencyInput -> IO (QueryResult MutationResult)
createCurrency pool input =
  runMutationReturningId
    pool
    "INSERT INTO currency (code, name, obj_type, symbol, rate_to_base) VALUES ($1, $2, 'currency', $3, $4) RETURNING id"
    currencyInputEncoder
    input
    "Currency created"

updateCurrency :: Pool -> Int64 -> CurrencyInput -> IO (QueryResult MutationResult)
updateCurrency pool currencyId input =
  runMutationReturningId
    pool
    "UPDATE currency SET code = $2, name = $3, symbol = $4, rate_to_base = $5 WHERE id = $1 RETURNING id"
    updateCurrencyEncoder
    (currencyId, input)
    "Currency updated"

deleteTax :: Pool -> Int64 -> IO (QueryResult MutationResult)
deleteTax pool tid =
  runMutationReturningId
    pool
    "DELETE FROM tax WHERE id = $1 RETURNING id"
    (E.param (E.nonNullable E.int8))
    tid
    "Tax deleted"

deleteCurrency :: Pool -> Int64 -> IO (QueryResult MutationResult)
deleteCurrency pool cid =
  runMutationReturningId
    pool
    "DELETE FROM currency WHERE id = $1 RETURNING id"
    (E.param (E.nonNullable E.int8))
    cid
    "Currency deleted"

-- | Create accounting plan
accPlanInputEncoder :: E.Params AccPlanInput
accPlanInputEncoder =
  (apiCode >$< E.param (E.nonNullable E.text))
    <> (apiName >$< E.param (E.nonNullable E.text))
    <> ((toInt16 . apiType) >$< E.param (E.nonNullable E.int2))
    <> (apiParentCode >$< E.param (E.nullable E.text))
    <> ((toInt16 . apiKind) >$< E.param (E.nonNullable E.int2))
    <> (apiIsAnalytical >$< E.param (E.nonNullable E.bool))

createAccPlan :: Pool -> AccPlanInput -> IO (QueryResult MutationResult)
createAccPlan pool input =
  runMutationReturningId
    pool
    "INSERT INTO acc_plan (code, name, acc_type, parent_code, kind, is_analytical, obj_type) \
    \VALUES ($1, $2, $3, $4, $5, $6, 'account_plan') RETURNING id"
    accPlanInputEncoder
    input
    "Account plan created"

updateAccPlanEncoder :: E.Params (Int64, AccPlanInput)
updateAccPlanEncoder =
  (fst >$< E.param (E.nonNullable E.int8))
    <> ((apiCode . snd) >$< E.param (E.nonNullable E.text))
    <> ((apiName . snd) >$< E.param (E.nonNullable E.text))
    <> (((toInt16 . apiType) . snd) >$< E.param (E.nonNullable E.int2))
    <> ((apiParentCode . snd) >$< E.param (E.nullable E.text))
    <> (((toInt16 . apiKind) . snd) >$< E.param (E.nonNullable E.int2))
    <> ((apiIsAnalytical . snd) >$< E.param (E.nonNullable E.bool))

updateAccPlan :: Pool -> Int64 -> AccPlanInput -> IO (QueryResult MutationResult)
updateAccPlan pool planId input =
  runMutationReturningId
    pool
    "UPDATE acc_plan SET code = $2, name = $3, acc_type = $4, parent_code = $5, kind = $6, is_analytical = $7 \
    \WHERE id = $1 RETURNING id"
    updateAccPlanEncoder
    (planId, input)
    "Account plan updated"

deleteAccPlan :: Pool -> Int64 -> IO (QueryResult MutationResult)
deleteAccPlan pool planId =
  runMutationReturningId
    pool
    "DELETE FROM acc_plan WHERE id = $1 RETURNING id"
    (E.param (E.nonNullable E.int8))
    planId
    "Account plan deleted"

-- | Create accounting turn
accTurnInputEncoder :: E.Params AccTurnInput
accTurnInputEncoder =
  (atiDbtAccId >$< E.param (E.nonNullable E.int8))
    <> (atiCrdAccId >$< E.param (E.nonNullable E.int8))
    <> (atiAmount >$< E.param (E.nonNullable E.float8))
    <> (atiDate >$< E.param (E.nonNullable E.date))
    <> (atiBillId >$< E.param (E.nullable E.int8))

createAccTurn :: Pool -> AccTurnInput -> IO (QueryResult MutationResult)
createAccTurn pool input =
  runMutationReturningId
    pool
    "INSERT INTO acc_turn (dbt_acc_id, crd_acc_id, amount, date, bill_id) \
    \VALUES ($1, $2, $3, $4, $5) RETURNING id"
    accTurnInputEncoder
    input
    "Accounting entry created"

updateAccTurnEncoder :: E.Params (Int64, AccTurnInput)
updateAccTurnEncoder =
  (fst >$< E.param (E.nonNullable E.int8))
    <> ((atiDbtAccId . snd) >$< E.param (E.nonNullable E.int8))
    <> ((atiCrdAccId . snd) >$< E.param (E.nonNullable E.int8))
    <> ((atiAmount . snd) >$< E.param (E.nonNullable E.float8))
    <> ((atiDate . snd) >$< E.param (E.nonNullable E.date))
    <> ((atiBillId . snd) >$< E.param (E.nullable E.int8))

updateAccTurn :: Pool -> Int64 -> AccTurnInput -> IO (QueryResult MutationResult)
updateAccTurn pool turnId input =
  runMutationReturningId
    pool
    "UPDATE acc_turn SET dbt_acc_id = $2, crd_acc_id = $3, amount = $4, date = $5, bill_id = $6 \
    \WHERE id = $1 RETURNING id"
    updateAccTurnEncoder
    (turnId, input)
    "Accounting entry updated"

deleteAccTurn :: Pool -> Int64 -> IO (QueryResult MutationResult)
deleteAccTurn pool turnId =
  runMutationReturningId
    pool
    "DELETE FROM acc_turn WHERE id = $1 RETURNING id"
    (E.param (E.nonNullable E.int8))
    turnId
    "Accounting entry deleted"
