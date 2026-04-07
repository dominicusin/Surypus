{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}

module DAL.Repository.Payment
  ( PaymentRepository (..),
    HasPaymentRepository (..),
    mkPaymentRepository,
    listPaymentsRepo,
    listPaymentsByBillRepo,
    createPaymentRepo,
    updatePaymentRepo,
    deletePaymentRepo,
  )
where

import Control.Monad.IO.Class (liftIO)
import Control.Monad.Trans.Except (ExceptT, throwE)
import DAL.Mutations (createPayment, deletePayment, updatePayment)
import DAL.Queries (getPaymentById, getPayments, getPaymentsByBill)
import DAL.Repository (HasRepository (..), RepositoryError (..), isNotFoundMessage)
import DAL.Types
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Hasql.Pool (Pool)
import qualified Surypus.Validation as Validation

newtype PaymentRepository = PaymentRepository
  { payrPool :: Pool
  }

listPaymentsRepo :: PaymentRepository -> ExceptT RepositoryError IO [Payment]
listPaymentsRepo repo = do
  result <- liftIO $ getPayments (payrPool repo)
  case result of
    QuerySuccess payments -> pure payments
    QueryError err -> throwE (DatabaseError err)

listPaymentsByBillRepo :: PaymentRepository -> Int64 -> ExceptT RepositoryError IO [Payment]
listPaymentsByBillRepo repo billId = do
  result <- liftIO $ getPaymentsByBill (payrPool repo) billId
  case result of
    QuerySuccess payments -> pure payments
    QueryError err -> throwE (DatabaseError err)

createPaymentRepo :: PaymentRepository -> PaymentInput -> ExceptT RepositoryError IO Payment
createPaymentRepo repo input = do
  validated <- validatePaymentInputRepo input
  mutation <- liftIO $ createPayment (payrPool repo) validated
  paymentId <- extractMutationId "Payment created but id was not returned" mutation
  result <- liftIO $ getPaymentById (payrPool repo) paymentId
  case result of
    QuerySuccess payment -> pure payment
    QueryError err -> throwE (DatabaseError err)

updatePaymentRepo :: PaymentRepository -> Int64 -> PaymentInput -> ExceptT RepositoryError IO Payment
updatePaymentRepo repo paymentId input = do
  validated <- validatePaymentInputRepo input
  mutation <- liftIO $ updatePayment (payrPool repo) paymentId validated
  _ <- extractMutationId "Payment updated but id was not returned" mutation
  result <- liftIO $ getPaymentById (payrPool repo) paymentId
  case result of
    QuerySuccess payment -> pure payment
    QueryError err -> throwE (DatabaseError err)

deletePaymentRepo :: PaymentRepository -> Int64 -> ExceptT RepositoryError IO ()
deletePaymentRepo repo paymentId = do
  mutation <- liftIO $ deletePayment (payrPool repo) paymentId
  case mutation of
    QuerySuccess _ -> pure ()
    QueryError err
      | isNotFoundMessage err -> throwE (NotFound "Payment not found")
      | otherwise -> throwE (DatabaseError err)

validatePaymentInputRepo :: PaymentInput -> ExceptT RepositoryError IO PaymentInput
validatePaymentInputRepo input = case Validation.validatePaymentInput input of
  Right ok -> pure ok
  Left errs ->
    throwE . ValidationError . T.intercalate "; " $ fmap validationMessage errs
  where
    validationMessage (Validation.ValidationError msg) = msg

extractMutationId :: Text -> QueryResult MutationResult -> ExceptT RepositoryError IO Int64
extractMutationId missingIdMessage result = case result of
  QuerySuccess (MutationResult _ (Just rid) _) -> pure rid
  QuerySuccess _ -> throwE (DatabaseError missingIdMessage)
  QueryError err -> throwE (DatabaseError err)

class HasPaymentRepository a where
  getPaymentRepository :: a -> PaymentRepository

instance HasPaymentRepository PaymentRepository where
  getPaymentRepository = id

instance HasRepository PaymentRepository Pool where
  getPool = payrPool

mkPaymentRepository :: Pool -> PaymentRepository
mkPaymentRepository = PaymentRepository
