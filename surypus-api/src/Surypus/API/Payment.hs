{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE OverloadedStrings #-}

module Surypus.API.Payment
  ( listPayments,
    createPayment,
    getPayment,
    updatePayment,
    deletePayment,
  )
where

import DAL.Types (Decimal (..), Payment (..), PaymentInput (..), QueryResult (..))
import Data.Functor.Contravariant ((>$<))
import Data.Int (Int16, Int32, Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (Day)
import qualified Hasql.Decoders as D
import qualified Hasql.Encoders as E
import Hasql.Pool (Pool, use)
import qualified Hasql.Session as Session
import qualified Hasql.Statement as S

listPayments :: Pool -> IO (QueryResult [Payment])
listPayments pool = do
  result <- use pool $ Session.statement () selectPaymentsStmt
  return $ case result of
    Left err -> QueryError (T.pack $ show err)
    Right payments -> QuerySuccess payments

createPayment :: Pool -> PaymentInput -> IO (QueryResult Payment)
createPayment pool input = do
  result <- use pool $ Session.statement (piBillId input, piPayDate input, piAmount input, piPayMethod input, piPayStatus input) insertPaymentStmt
  return $ case result of
    Left err -> QueryError (T.pack $ show err)
    Right p -> QuerySuccess p

getPayment :: Pool -> Int64 -> IO (QueryResult Payment)
getPayment pool pid = do
  result <- use pool $ Session.statement pid selectPaymentStmt
  return $ case result of
    Left err -> QueryError (T.pack $ show err)
    Right p -> QuerySuccess p

updatePayment :: Pool -> Int64 -> PaymentInput -> IO (QueryResult Payment)
updatePayment pool pid input = do
  result <- use pool $ Session.statement (input, pid) updatePaymentStmt
  return $ case result of
    Left err -> QueryError (T.pack $ show err)
    Right p -> QuerySuccess p

deletePayment :: Pool -> Int64 -> IO (QueryResult ())
deletePayment pool pid = do
  result <- use pool $ Session.statement pid deletePaymentStmt
  return $ case result of
    Left err -> QueryError (T.pack $ show err)
    Right () -> QuerySuccess ()

selectPaymentsStmt :: S.Statement () [Payment]
selectPaymentsStmt = S.Statement sql encoder decoder True
  where
    sql = "SELECT id, bill_id, pay_date, amount, pay_method, pay_status FROM payments ORDER BY id LIMIT 50"
    encoder = E.noParams
    decoder = D.rowList paymentDecoder

selectPaymentStmt :: S.Statement Int64 Payment
selectPaymentStmt = S.Statement sql encoder decoder True
  where
    sql = "SELECT id, bill_id, pay_date, amount, pay_method, pay_status FROM payments WHERE id = $1"
    encoder = ((\(pid) -> pid) >$< E.param (E.nonNullable E.int8))
    decoder = D.singleRow paymentDecoder

insertPaymentStmt :: S.Statement (Int64, Day, Double, Int, Int) Payment
insertPaymentStmt = S.Statement sql encoder decoder True
  where
    sql = "INSERT INTO payments (bill_id, pay_date, amount, pay_method, pay_status) VALUES ($1, $2, $3, $4, $5) RETURNING id, bill_id, pay_date, amount, pay_method, pay_status"
    encoder =
      ((\(bid, _, _, _, _) -> bid) >$< E.param (E.nonNullable E.int8))
        <> ((\(_, date, _, _, _) -> date) >$< E.param (E.nonNullable E.date))
        <> ((\(_, _, amount, _, _) -> amount) >$< E.param (E.nonNullable E.float8))
        <> ((\(_, _, _, method, _) -> fromIntegral method) >$< E.param (E.nonNullable E.int4))
        <> ((\(_, _, _, _, status) -> fromIntegral status) >$< E.param (E.nonNullable E.int4))
    decoder = D.singleRow paymentDecoder

updatePaymentStmt :: S.Statement (PaymentInput, Int64) Payment
updatePaymentStmt = S.Statement sql encoder decoder True
  where
    sql = "UPDATE payments SET bill_id = $1, pay_date = $2, amount = $3, pay_method = $4, pay_status = $5 WHERE id = $6 RETURNING id, bill_id, pay_date, amount, pay_method, pay_status"
    encoder =
      ((\(pi, _) -> piBillId pi) >$< E.param (E.nonNullable E.int8))
        <> ((\(pi, _) -> piPayDate pi) >$< E.param (E.nonNullable E.date))
        <> ((\(pi, _) -> piAmount pi) >$< E.param (E.nonNullable E.float8))
        <> ((\(pi, _) -> fromIntegral (piPayMethod pi)) >$< E.param (E.nonNullable E.int4))
        <> ((\(pi, _) -> fromIntegral (piPayStatus pi)) >$< E.param (E.nonNullable E.int4))
        <> ((\(_, pid) -> pid) >$< E.param (E.nonNullable E.int8))
    decoder = D.singleRow paymentDecoder

deletePaymentStmt :: S.Statement Int64 ()
deletePaymentStmt = S.Statement sql encoder decoder True
  where
    sql = "DELETE FROM payments WHERE id = $1"
    encoder = ((\(pid) -> pid) >$< E.param (E.nonNullable E.int8))
    decoder = D.noResult

paymentDecoder :: D.Row Payment
paymentDecoder = Payment <$> D.column (D.nonNullable D.int8) <*> D.column (D.nonNullable D.int8) <*> D.column (D.nonNullable D.date) <*> (Decimal . round <$> D.column (D.nonNullable D.numeric)) <*> (fromIntegral <$> D.column (D.nonNullable D.int4)) <*> (fromIntegral <$> D.column (D.nonNullable D.int4))
