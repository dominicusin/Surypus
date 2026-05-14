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

import DAL.Types (Payment (..), PaymentInput (..), QueryResult (..))
import Data.Functor.Contravariant ((>$<))
import Data.Int (Int64)
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
  result <- use pool $ Session.statement (payInputPersonId input, payInputAmount input, payInputDate input) insertPaymentStmt
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
    sql = "SELECT id, person_id, amount, date FROM payments ORDER BY id LIMIT 50"
    encoder = E.noParams
    decoder = D.rowList paymentDecoder

selectPaymentStmt :: S.Statement Int64 Payment
selectPaymentStmt = S.Statement sql encoder decoder True
  where
    sql = "SELECT id, person_id, amount, date FROM payments WHERE id = $1"
    encoder = ((\(pid) -> pid) >$< E.param (E.nonNullable E.int8))
    decoder = D.singleRow paymentDecoder

insertPaymentStmt :: S.Statement (Int64, Double, Day) Payment
insertPaymentStmt = S.Statement sql encoder decoder True
  where
    sql = "INSERT INTO payments (person_id, amount, date) VALUES ($1, $2, $3) RETURNING id, person_id, amount, date"
    encoder =
      ((\(personId, _, _) -> personId) >$< E.param (E.nonNullable E.int8))
        <> ((\(_, amount, _) -> amount) >$< E.param (E.nonNullable E.float8))
        <> ((\(_, _, date) -> date) >$< E.param (E.nonNullable E.date))
    decoder = D.singleRow paymentDecoder

updatePaymentStmt :: S.Statement (PaymentInput, Int64) Payment
updatePaymentStmt = S.Statement sql encoder decoder True
  where
    sql = "UPDATE payments SET person_id = $1, amount = $2, date = $3 WHERE id = $4 RETURNING id, person_id, amount, date"
    encoder =
      ((\(pi, _) -> payInputPersonId pi) >$< E.param (E.nonNullable E.int8))
        <> ((\(pi, _) -> payInputAmount pi) >$< E.param (E.nonNullable E.float8))
        <> ((\(pi, _) -> payInputDate pi) >$< E.param (E.nonNullable E.date))
        <> ((\(_, pid) -> pid) >$< E.param (E.nonNullable E.int8))
    decoder = D.singleRow paymentDecoder

deletePaymentStmt :: S.Statement Int64 ()
deletePaymentStmt = S.Statement sql encoder decoder True
  where
    sql = "DELETE FROM payments WHERE id = $1"
    encoder = ((\(pid) -> pid) >$< E.param (E.nonNullable E.int8))
    decoder = D.noResult

paymentDecoder :: D.Row Payment
paymentDecoder = Payment
  <$> D.column (D.nonNullable D.int8)
  <*> D.column (D.nonNullable D.int8)
  <*> D.column (D.nonNullable D.float8)
  <*> D.column (D.nonNullable D.date)