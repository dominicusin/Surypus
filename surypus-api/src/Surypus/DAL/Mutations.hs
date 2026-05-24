{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE Arrows #-}
{-# LANGUAGE TypeOperators #-}

-- | Database Mutations (Write operations)
--
-- This module provides all write operations for the database layer.
-- It includes encoders for inserting/updating data and mutation helpers.
--
-- = Design
--
-- The mutation layer uses:
--
-- * Opaleye for type-safe mutations
-- * Parameter encoders using 'Data.Profunctor.Product.Default'
-- * 'runMutationReturningId' for INSERT/UPDATE with RETURNING
--
-- = Encoders
--
-- Each entity has corresponding input encoders (e.g., 'personInputEncoder').
-- These are composed using the '>$<' operator from Contravariant.
module DAL.Mutations where

import Control.Monad (forM)
import Data.Functor.Contravariant ((>$<))
import Data.Profunctor.Product.Default (Default)
import Data.Int (Int16, Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (Day, fromGregorian)
import qualified Database.PostgreSQL.Simple as PGS
import qualified Opaleye as OE
import qualified Opaleye.Internal.HaskellDB.PrimQuery as OPQ
import qualified Opaleye.Internal.PGTypes as OPG
import qualified Opaleye.Internal.Tag as OITag

-- Import types from the main Surypus package
import DAL.Types
import qualified DAL.Queries as Queries
import DAL.Database (Pool, usePool, runQuery, runCommand)

-- | Helper to run a mutation that returns an ID
runMutationReturningId :: Pool -> OE.Insert OE.PGString r -> IO (QueryResult MutationResult)
runMutationReturningId pool insert = do
   res <- runCommand pool (OE.runInsert insert)
   case res of
     Left err -> return $ QueryError (T.pack (show err))
     Right count -> if count > 0 
                    then return $ QuerySuccess (MutationResult True Nothing "Mutation successful") 
                    else return $ QueryError "No rows affected"

-- | Helper to run a mutation that returns a list of IDs
runMutationReturningIds :: Pool -> [OE.Insert OE.PGString r] -> IO (QueryResult [Int64])
runMutationReturningIds pool inserts = do
   results <- mapM (\insert -> runCommand pool (OE.runInsert insert)) inserts
   case sequence results of
     Right counts -> return $ QuerySuccess (map fromIntegral $ filter (>0) counts)
     Left err -> return $ QueryError (T.pack (show err))

toInt16 :: Int -> Int16
toInt16 = fromIntegral

-- Define the table structure for persons
personsTable :: OE.Table (OE.OEText, OE.OEText, OE.OEText, OE.OEText, OE.OEInt2, OE.OEInt2) (OE.OEInt8, OE.OEText, OE.OEText, OE.OEText, OE.OEText, OE.OEInt2, OE.OEInt2)
personsTable = OE.table "persons.person" (OITag.tag "persons.person")
   ( \(personId, personCode, personName, personINN, personKPP, personType, personStatus) ->
      ( personId
      , personCode
      , personName
      , personINN
      , personKPP
      , personType
      , personStatus
      )
   )
   ( \(personId, personCode, personName, personINN, personKPP, personType, personStatus) ->
      ( OE.required personId
      , OE.required personCode
      , OE.required personName
      , OE.required personINN
      , OE.required personKPP
      , OE.required personType
      , OE.required personStatus
      )
   )

personInputEncoder :: (OE.OEText, OE.OEText, OE.OEText, OE.OEText, OE.OEInt2, OE.OEInt2) -> OE.Insert OE.PGString (OE.OEInt8)
personInputEncoder (personCode, personName, personINN, personKPP, personType, personStatus) =
   OE.insert personsTable
      OE.constNothing
      ( personCode
      , personName
      , personINN
      , personKPP
      , personType
      , personStatus
      )

updatePersonEncoder :: (OE.OEInt8, OE.OEText, OE.OEText, OE.OEText, OE.OEText, OE.OEInt2, OE.OEInt2) -> OE.Update OE.PGString (OE.OEInt8)
updatePersonEncoder (personId, personCode, personName, personINN, personKPP, personType, personStatus) =
   OE.update personsTable
      \(_personId _personCode _personName _personINN _personKPP _personType _personStatus) ->
        ( _personId
        , _personCode
        , _personName
        , _personINN
        , _personKPP
        , _personType
        , _personStatus
        )
      \(_personId _personCode _personName _personINN _personKPP _personType _personStatus) ->
        ( OE.constant personId
        , OE.constant personCode
        , OE.constant personName
        , OE.constant personINN
        , OE.constant personKPP
        , OE.constant personType
        , OE.constant personStatus
        )
      (\(_personId _personCode _personName _personINN _personKPP _personType _personStatus) ->
        OE.primaryKey _personId)

createPerson :: Pool -> PersonInput -> IO (QueryResult MutationResult)
createPerson pool input =
   runMutationReturningId pool (personInputEncoder (
      piCode input
    , piName input
    , piINN input
    , piKPP input
    , (fromIntegral . piPersonType) input
    , (fromIntegral . piStatus) input
    ))

updatePerson :: Pool -> Int64 -> PersonInput -> IO (QueryResult MutationResult)
updatePerson pool pid input =
   runMutationReturningId pool (updatePersonEncoder (
      pid
    , piCode input
    , piName input
    , piINN input
    , piKPP input
    , (fromIntegral . piPersonType) input
    , (fromIntegral . piStatus) input
    ))

deletePerson :: Pool -> Int64 -> IO (QueryResult MutationResult)
deletePerson pool pid =
   let deleteQuery = OE.delete personsTable
        \(_personId _personCode _personName _personINN _personKPP _personType _personStatus) ->
          OE.primaryKey _personId .== OE.constant pid
   in runCommand pool deleteQuery >>= \res ->
        case res of
          Left err -> return $ QueryError (T.pack (show err))
          Right count -> if count > 0
                         then return $ QuerySuccess (MutationResult True Nothing "Person deleted successfully")
                         else return $ QueryError "No person found to delete"

-- Define the table structure for goods
goodsTable :: OE.Table (OE.OEText, OE.OEText, OE.OEText, OE.OEInt8, OE.OEInt8) (OE.OEInt8, OE.OEText, OE.OEText, OE.OEText, OE.OEInt8, OE.OEInt8)
goodsTable = OE.table "goods" (OITag.tag "goods")
   \(goodsId, goodsCode, goodsName, goodsBarcode, goodsUnitId, goodsParentId) ->
      ( goodsId
      , goodsCode
      , goodsName
      , goodsBarcode
      , goodsUnitId
      , goodsParentId
      )
   \(goodsId, goodsCode, goodsName, goodsBarcode, goodsUnitId, goodsParentId) ->
      ( OE.required goodsId
      , OE.required goodsCode
      , OE.required goodsName
      , OE.required goodsBarcode
      , OE.required goodsUnitId
      , OE.required goodsParentId
      )

goodsInputEncoder :: (OE.OEText, OE.OEText, OE.OEText, OE.OEInt8, OE.OEInt8) -> OE.Insert OE.PGString (OE.OEInt8)
goodsInputEncoder (goodsCode, goodsName, goodsBarcode, goodsUnitId, goodsParentId) =
   OE.insert goodsTable
      OE.constNothing
      ( goodsCode
      , goodsName
      , goodsBarcode
      , goodsUnitId
      , goodsParentId
      )

updateGoodsEncoder :: (OE.OEInt8, OE.OEText, OE.OEText, OE.OEText, OE.OEInt8, OE.OEInt8) -> OE.Update OE.PGString (OE.OEInt8)
updateGoodsEncoder (goodsId, goodsCode, goodsName, goodsBarcode, goodsUnitId, goodsParentId) =
   OE.update goodsTable
      \(_goodsId _goodsCode _goodsName _goodsBarcode _goodsUnitId _goodsParentId) ->
        ( _goodsId
        , _goodsCode
        , _goodsName
        , _goodsBarcode
        , _goodsUnitId
        , _goodsParentId
        )
      \(_goodsId _goodsCode _goodsName _goodsBarcode _goodsUnitId _goodsParentId) ->
        ( OE.constant goodsId
        , OE.constant goodsCode
        , OE.constant goodsName
        , OE.constant goodsBarcode
        , OE.constant goodsUnitId
        , OE.constant goodsParentId
        )
      (\(_goodsId _goodsCode _goodsName _goodsBarcode _goodsUnitId _goodsParentId) ->
        OE.primaryKey _goodsId)

createGoods :: Pool -> GoodsInput -> IO (QueryResult MutationResult)
createGoods pool input =
   runMutationReturningId pool (goodsInputEncoder (
      giCode input
    , giName input
    , giBarcode input
    , giUnitId input
    , giParentId input
    ))

updateGoods :: Pool -> Int64 -> GoodsInput -> IO (QueryResult MutationResult)
updateGoods pool gid input =
   runMutationReturningId pool (updateGoodsEncoder (
      gid
    , giCode input
    , giName input
    , giBarcode input
    , giUnitId input
    , giParentId input
    ))

deleteGoods :: Pool -> Int64 -> IO (QueryResult MutationResult)
deleteGoods pool gid =
   let deleteQuery = OE.delete goodsTable
        \(_goodsId _goodsCode _goodsName _goodsBarcode _goodsUnitId _goodsParentId) ->
          OE.primaryKey _goodsId .== OE.constant gid
   in runCommand pool deleteQuery >>= \res ->
        case res of
          Left err -> return $ QueryError (T.pack (show err))
          Right count -> if count > 0
                         then return $ QuerySuccess (MutationResult True Nothing "Goods deleted successfully")
                         else return $ QueryError "No goods found to delete"

-- Define the table structure for bill
billTable :: OE.Table (OE.OEText, OE.OEInt2, OE.OEInt2, OE.OEDate, OE.OEInt8, OE.OEInt8, OE.OEDouble, OE.OEDouble, OE.OEDouble) (OE.OEInt8, OE.OEText, OE.OEInt2, OE.OEInt2, OE.OEDate, OE.OEInt8, OE.OEInt8, OE.OEDouble, OE.OEDouble, OE.OEDouble)
billTable = OE.table "bill" (OITag.tag "bill")
   \(billId, billCode, billType, billStatus, billDate, billPersonId, billLocationId, billTotal, billDiscount, billTaxAmount) ->
      ( billId
      , billCode
      , billType
      , billStatus
      , billDate
      , billPersonId
      , billLocationId
      , billTotal
      , billDiscount
      , billTaxAmount
      )
   \(billId, billCode, billType, billStatus, billDate, billPersonId, billLocationId, billTotal, billDiscount, billTaxAmount) ->
      ( OE.required billId
      , OE.required billCode
      , OE.required billType
      , OE.required billStatus
      , OE.required billDate
      , OE.required billPersonId
      , OE.required billLocationId
      , OE.required billTotal
      , OE.required billDiscount
      , OE.required billTaxAmount
      )

billInputEncoder :: (OE.OEText, OE.OEInt2, OE.OEInt2, OE.OEDate, OE.OEInt8, OE.OEInt8, OE.OEDouble, OE.OEDouble, OE.OEDouble) -> OE.Insert OE.PGString (OE.OEInt8)
billInputEncoder (billCode, billType, billStatus, billDate, billPersonId, billLocationId, billTotal, billDiscount, billTaxAmount) =
   OE.insert billTable
      OE.constNothing
      ( billCode
      , billType
      , billStatus
      , billDate
      , billPersonId
      , billLocationId
      , billTotal
      , billDiscount
      , billTaxAmount
      )

createBill :: Pool -> BillInput -> IO (QueryResult MutationResult)
createBill pool input =
   runMutationReturningId pool (billInputEncoder (
      biCode input
    , (toInt16 . biType) input
    , (toInt16 . biStatus) input
    , biDate input
    , biPersonId input
    , biLocationId input
    , biTotal input
    , biDiscount input
    , biTax input
    ))

updateBillStatus :: Pool -> Int64 -> Int -> IO (QueryResult MutationResult)
updateBillStatus pool bid status =
   let updateQuery = OE.update billTable
        \(_billId _billCode _billType _billStatus _billDate _billPersonId _billLocationId _billTotal _billDiscount _billTaxAmount) ->
          ( _billId
          , _billCode
          , _billType
          , _billStatus
          , _billDate
          , _billPersonId
          , _billLocationId
          , _billTotal
          , _billDiscount
          , _billTaxAmount
          )
        \(_billId _billCode _billType _billStatus _billDate _billPersonId _billLocationId _billTotal _billDiscount _billTaxAmount) ->
          ( OE.constant billId
          , OE.constant billCode
          , OE.constant billType
          , OE.constant status
          , OE.constant billDate
          , OE.constant billPersonId
          , OE.constant billLocationId
          , OE.constant billTotal
          , OE.constant billDiscount
          , OE.constant billTaxAmount
          )
        (\(_billId _billCode _billType _billStatus _billDate _billPersonId _billLocationId _billTotal _billDiscount _billTaxAmount) ->
          OE.primaryKey _billId)
   in runCommand pool updateQuery >>= \res ->
        case res of
          Left err -> return $ QueryError (T.pack (show err))
          Right count -> if count > 0
                         then return $ QuerySuccess (MutationResult True Nothing "Bill status updated")
                         else return $ QueryError "No bill found to update"

-- | Post a bill - updates status to posted (simple version)
postBill :: Pool -> Int64 -> IO (QueryResult MutationResult)
postBill pool bid = updateBillStatus pool bid 2

-- | Post a bill - creates accounting entries using service layer logic
-- This version integrates with DAL.Mutations for persistence
postBillWithAcc :: Pool -> Int64 -> IO (QueryResult [Int64])
postBillWithAcc pool bid = do
  -- First update bill status to "posted" (2)
  statusResult <- updateBillStatus pool bid 2
  case statusResult of
    QueryError err -> return $ QueryError err
    QuerySuccess _ -> do
      -- Get bill lines to calculate accounting entries
      billLinesResult <- Queries.getBillLines pool bid
      case billLinesResult of
        QueryError err -> return $ QueryError err
        QuerySuccess billLines -> do
          -- Calculate total from lines for accounting
          let totalAmount = sum (map lineAmount billLines)
              -- Create standard double-entry: Debit (account 10) = Credit (account 20)
              -- Using 1970-01-01 as placeholder date - should use actual bill date
              placeholderDate = fromGregorian 1970 1 1
              debitEntry = AccTurnInput 10 20 totalAmount placeholderDate (Just bid)
              creditEntry = AccTurnInput 20 10 totalAmount placeholderDate (Just bid)
          
          -- Create accounting turn entries
          debitResult <- createAccTurn pool debitEntry
          creditResult <- createAccTurn pool creditEntry
          
          let turnIds = case (debitResult, creditResult) of
                (QuerySuccess (MutationResult _ (Just id1) _), QuerySuccess (MutationResult _ (Just id2) _)) -> [id1, id2]
                _ -> []
          
          return $ QuerySuccess turnIds

addBillLineEncoder :: E.Params (Int64, BillLineInput)
addBillLineEncoder =
  (fst >$< E.param (E.nonNullable E.int8))
    <> ((bliGoodsId . snd) >$< E.param (E.nonNullable E.int8))
    <> (bliQtty . snd >$< E.param (E.nonNullable E.float8))
    <> (bliPrice . snd >$< E.param (E.nonNullable E.float8))
    <> (bliDiscount . snd >$< E.param (E.nonNullable E.float8))
    <> (bliAmount . snd >$< E.param (E.nonNullable E.float8))

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

stockQtyEncoder :: E.Params (Double, Int64, Int64)
stockQtyEncoder =
  ((\(qty, _, _) -> qty) >$< E.param (E.nonNullable E.float8)) <>
  ((\(_, goodsId, _) -> goodsId) >$< E.param (E.nonNullable E.int8)) <>
  ((\(_, _, locationId) -> locationId) >$< E.param (E.nonNullable E.int8))

updateStock :: Pool -> Int64 -> Int64 -> Double -> IO (QueryResult MutationResult)
updateStock pool goodsId locationId qty =
  runMutationReturningId
    pool
    "UPDATE stock SET qtty = $1 WHERE goods_id = $2 AND location_id = $3 RETURNING id"
    stockQtyEncoder
    (qty, goodsId, locationId)
    "Stock updated"

reserveStock :: Pool -> Int64 -> Int64 -> Double -> IO (QueryResult MutationResult)
reserveStock pool goodsId locationId qty =
  runMutationReturningId
    pool
    "UPDATE stock SET resrv_qtty = resrv_qtty + $1 WHERE goods_id = $2 AND location_id = $3 RETURNING id"
    stockQtyEncoder
    (qty, goodsId, locationId)
    "Stock reserved"

releaseStock :: Pool -> Int64 -> Int64 -> Double -> IO (QueryResult MutationResult)
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
    <> (oiTotal >$< E.param (E.nonNullable E.float8))
    <> (oiDiscount >$< E.param (E.nonNullable E.float8))
    <> (oiTax >$< E.param (E.nonNullable E.float8))

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

userInputEncoder :: E.Params UserInput
userInputEncoder =
  (uiLogin >$< E.param (E.nonNullable E.text))
    <> (uiPasswordHash >$< E.param (E.nonNullable E.text))
    <> (uiPersonId >$< E.param (E.nullable E.int8))
    <> ((toInt16 . uiStatus) >$< E.param (E.nonNullable E.int2))

updateUserEncoder :: E.Params (Int64, UserInput)
updateUserEncoder =
  (fst >$< E.param (E.nonNullable E.int8))
    <> ((uiLogin . snd) >$< E.param (E.nonNullable E.text))
    <> ((uiPasswordHash . snd) >$< E.param (E.nonNullable E.text))
    <> ((uiPersonId . snd) >$< E.param (E.nullable E.int8))
    <> ((toInt16 . uiStatus . snd) >$< E.param (E.nonNullable E.int2))

createUser :: Pool -> UserInput -> IO (QueryResult MutationResult)
createUser pool input =
  runMutationReturningId
    pool
    "INSERT INTO usr (login, password_hash, person_id, status) VALUES ($1, $2, $3, $4) RETURNING id"
    userInputEncoder
    input
    "User created successfully"

updateUser :: Pool -> Int64 -> UserInput -> IO (QueryResult MutationResult)
updateUser pool userId input =
  runMutationReturningId
    pool
    "UPDATE usr SET login = $2, password_hash = $3, person_id = $4, status = $5 WHERE id = $1 RETURNING id"
    updateUserEncoder
    (userId, input)
    "User updated successfully"

authenticateUser :: Pool -> Text -> Text -> IO (QueryResult (Maybe User))
authenticateUser pool login password = do
  let stmt =
        unpreparable
          "SELECT id, login, person_id, NULL, email, role_id, status FROM usr WHERE login = $1 AND password_hash = $2 AND status = 0"
          ( (fst >$< E.param (E.nonNullable E.text))
              <> (snd >$< E.param (E.nonNullable E.text))
          )
          authenticateUserRowDecoder
  res <- use pool $ Session.statement (login, password) stmt
  case res of
    Right mbUser -> pure $ QuerySuccess mbUser
    Left err -> pure $ QueryError (T.pack $ show err)

authenticateUserRowDecoder :: D.Result (Maybe User)
authenticateUserRowDecoder =
  D.rowMaybe $
    User
      <$> D.column (D.nonNullable D.int8)
      <*> D.column (D.nonNullable D.text)
      <*> pure Nothing
      <*> D.column (D.nullable D.text)
      <*> D.column (D.nullable D.int8)
      <*> (fromIntegral <$> D.column (D.nonNullable D.int2))

priceInputEncoder :: E.Params PriceInput
priceInputEncoder =
  (priGoodsId >$< E.param (E.nonNullable E.int8))
    <> ((toInt16 . priPriceType) >$< E.param (E.nonNullable E.int2))
    <> (priPrice >$< E.param (E.nonNullable E.float8))
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
