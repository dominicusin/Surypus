{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Bill repository interface and implementation.
--
-- This module defines the repository pattern for Bill entities, providing
-- CRUD operations and query functions. It abstracts the database access
-- layer and allows for easy mocking in tests.
--
-- The repository is parameterized over a pool type, allowing different
-- connection pool implementations to be used.
--
-- === Examples
--
-- Creating a repository and finding a bill by ID:
-- @
-- import DAL.Repository.Bill (BillRepository, mkBillRepository, runBillRepository)
-- import DAL.Types (Bill)
-- import Hasql.Pool (Pool)
--
-- -- Assuming you have a connection pool
-- let pool :: Pool = undefined -- See issue: https://github.com/dominicusin/Surypus/issues/123
-- let repo :: BillRepository = mkBillRepository pool
--
-- -- Find a bill by ID
-- result <- runBillRepository repo $ find 123
-- case result of
--   Right (Just bill) -> print (bill :: Bill)
--   Right Nothing  -> putStrLn "Bill not found"
--   Left err       -> putStrLn $ "Error: " ++ err
-- @
--
-- Listing bills with pagination:
-- @
-- import DAL.Repository.Bill (BillRepository, mkBillRepository, runBillRepository)
-- import DAL.Types (BillFilter, Pagination, BillSortBy, SortDir)
-- import Hasql.Pool (Pool)
--
-- -- Assuming you have a connection pool
-- let pool :: Pool = undefined -- See issue: https://github.com/dominicusin/Surypus/issues/123
-- let repo :: BillRepository = mkBillRepository pool
-- let filter = BillFilter Nothing Nothing Nothing Nothing Nothing Nothing Nothing -- No filtering
-- let pagination = Pagination 10 0 -- First page, 10 items per page
--
-- result <- runBillRepository repo $ listBillsPage filter pagination Nothing Nothing
-- case result of
--   Right paginated -> mapM_ print (prItems paginated)
--   Left err       -> putStrLn $ "Error: " ++ err
-- @
--
-- Updating bill status:
-- @
-- import DAL.Repository.Bill (BillRepository, mkBillRepository, runBillRepository)
-- import DAL.Types (Bill)
-- import Hasql.Pool (Pool)
--
-- -- Assuming you have a connection pool
-- let pool :: Pool = undefined -- See issue: https://github.com/dominicusin/Surypus/issues/123
-- let repo :: BillRepository = mkBillRepository pool
--
-- -- Update bill status to 2 (posted)
-- result <- runBillRepository repo $ updateBillStatusRepo 123 2
-- case result of
--   Right (Just bill) -> putStrLn "Bill status updated successfully"
--   Right Nothing  -> putStrLn "Bill not found"
--   Left err       -> putStrLn $ "Error: " ++ err
-- @
module DAL.Repository.Bill
  ( BillRepository (..),
    HasBillRepository (..),
    mkBillRepository,
    runBillRepository,
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
import DAL.Queries (getBillById, getBillLines, getBills, getBillsPaginated)
import DAL.Repository
import DAL.Types
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Hasql.Pool (Pool)
import qualified Surypus.Validation as Validation

data BillRepository = BillRepository
  { brPool :: Pool
  }

instance Repository BillRepository Bill where
  find repo billId = do
    result <- liftIO $ getBillById (brPool repo) billId
    case result of
      QuerySuccess bill -> pure (Just bill)
      QueryError err
        | isNotFoundMessage err -> pure Nothing
        | otherwise -> throwE (DatabaseError err)

  findAll repo = do
    result <- liftIO $ getBills (brPool repo)
    case result of
      QuerySuccess bills -> pure bills
      QueryError err -> throwE (DatabaseError err)

  create repo bill = do
    created <- createBillRepo repo (toBillInput bill)
    pure (bId created)

  update repo billId bill = do
    _ <- updateBillStatusRepo repo billId (bStatus bill)
    mBill <- find repo billId
    case mBill of
      Just updatedBill -> pure (Just updatedBill)
      Nothing -> throwE (NotFound "Updated bill was not found")

  delete repo billId = do
    deleteBillRepo repo billId
    pure Nothing

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
  mBill <- find repo billId
  case mBill of
    Just bill -> pure bill
    Nothing -> throwE (NotFound "Created bill was not found")

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

toBillInput :: Bill -> BillInput
toBillInput bill =
  BillInput
    { biCode = bCode bill,
      biType = bType bill,
      biStatus = bStatus bill,
      biDate = bDate bill,
      biPersonId = bPersonId bill,
      biLocationId = bLocationId bill,
      biTotal = bTotal bill,
      biDiscount = bDiscount bill,
      biTax = bTax bill
    }

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
  getRepository = brPool

mkBillRepository :: Pool -> BillRepository
mkBillRepository = BillRepository

runBillRepository :: BillRepository -> RepositoryT IO a -> IO (Either RepositoryError a)
runBillRepository repo action = runRepository (defaultRepositoryContext (brPool repo)) action
