{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}

module DAL.Repository.Bill
  ( BillRepository (..),
    HasBillRepository (..),
    mkBillRepository,
    listBillsPage,
    getBillLinesRepo,
    createBillRepo,
    updateBillStatusRepo,
    deleteBillRepo,
  )
where

import Control.Monad.IO.Class (liftIO)
import Control.Monad.Trans.Except (ExceptT, throwE)
import DAL.Mutations (createBill, deleteBill, updateBillStatus)
import DAL.Queries (getBillById, getBillLines, getBillsPaginated)
import DAL.Repository (HasRepository (..), RepositoryError (..), isNotFoundMessage)
import DAL.Types
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Hasql.Pool (Pool)
import qualified Surypus.Validation as Validation

newtype BillRepository = BillRepository
  { brPool :: Pool
  }

listBillsPage :: BillRepository -> BillFilter -> Pagination -> Maybe BillSortBy -> Maybe SortDir -> ExceptT RepositoryError IO (PaginatedResult Bill)
listBillsPage repo billFilter pagination sortBy sortDir = do
  result <- liftIO $ getBillsPaginated (brPool repo) billFilter pagination sortBy sortDir
  case result of
    QuerySuccess page -> pure page
    QueryError err -> throwE (DatabaseError err)

getBillLinesRepo :: BillRepository -> Int64 -> ExceptT RepositoryError IO [BillLine]
getBillLinesRepo repo billId = do
  result <- liftIO $ getBillLines (brPool repo) billId
  case result of
    QuerySuccess linesList -> pure linesList
    QueryError err -> throwE (DatabaseError err)

createBillRepo :: BillRepository -> BillInput -> ExceptT RepositoryError IO Bill
createBillRepo repo input = do
  validated <- validateBillInputRepo input
  mutation <- liftIO $ createBill (brPool repo) validated
  billId <- extractMutationId "Bill created but id was not returned" mutation
  result <- liftIO $ getBillById (brPool repo) billId
  case result of
    QuerySuccess bill -> pure bill
    QueryError err -> throwE (DatabaseError err)

updateBillStatusRepo :: BillRepository -> Int64 -> Int -> ExceptT RepositoryError IO Int64
updateBillStatusRepo repo billId status = do
  mutation <- liftIO $ updateBillStatus (brPool repo) billId status
  extractMutationId "Bill status updated but id was not returned" mutation

deleteBillRepo :: BillRepository -> Int64 -> ExceptT RepositoryError IO ()
deleteBillRepo repo billId = do
  mutation <- liftIO $ deleteBill (brPool repo) billId
  case mutation of
    QuerySuccess _ -> pure ()
    QueryError err
      | isNotFoundMessage err -> throwE (NotFound "Bill not found")
      | otherwise -> throwE (DatabaseError err)

validateBillInputRepo :: BillInput -> ExceptT RepositoryError IO BillInput
validateBillInputRepo input = case Validation.validateBillInput input of
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

class HasBillRepository a where
  getBillRepository :: a -> BillRepository

instance HasBillRepository BillRepository where
  getBillRepository = id

instance HasRepository BillRepository Pool where
  getPool = brPool

mkBillRepository :: Pool -> BillRepository
mkBillRepository = BillRepository
