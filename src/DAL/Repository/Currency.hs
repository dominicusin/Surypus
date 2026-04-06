{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Currency repository interface and implementation.
--
-- This module defines the repository pattern for Currency entities, providing
-- CRUD operations and query functions. It abstracts the database access
-- layer and allows for easy mocking in tests.
--
-- The repository is parameterized over a pool type, allowing different
-- connection pool implementations to be used.
--
-- === Examples
--
-- Creating a repository and finding a currency by ID:
-- @
-- import DAL.Repository.Currency (CurrencyRepository, mkCurrencyRepository, runCurrencyRepository)
-- import DAL.Types (Currency)
-- import Hasql.Pool (Pool)
--
-- -- Assuming you have a connection pool
-- let pool :: Pool = undefined -- TODO: Initialize pool
-- let repo :: CurrencyRepository = mkCurrencyRepository pool
--
-- -- Find a currency by ID
-- result <- runCurrencyRepository repo $ find 123
-- case result of
--   Right (Just currency) -> print (currency :: Currency)
--   Right Nothing  -> putStrLn "Currency not found"
--   Left err       -> putStrLn $ "Error: " ++ err
-- @
--
-- Listing all currencies:
-- @
-- import DAL.Repository.Currency (CurrencyRepository, mkCurrencyRepository, runCurrencyRepository)
-- import Hasql.Pool (Pool)
--
-- -- Assuming you have a connection pool
-- let pool :: Pool = undefined -- TODO: Initialize pool
-- let repo :: CurrencyRepository = mkCurrencyRepository pool
--
-- result <- runCurrencyRepository repo $ listCurrenciesRepo
-- case result of
--   Right currencies -> mapM_ print currencies
--   Left err       -> putStrLn $ "Error: " ++ err
-- @
--
-- Creating a new currency:
-- @
-- import DAL.Repository.Currency (CurrencyRepository, mkCurrencyRepository, runCurrencyRepository)
-- import DAL.Types (CurrencyInput)
-- import Hasql.Pool (Pool)
--
-- -- Assuming you have a connection pool
-- let pool :: Pool = undefined -- TODO: Initialize pool
-- let repo :: CurrencyRepository = mkCurrencyRepository pool
-- let input = CurrencyInput
--       { ciCode = "USD"
--       , ciName = "US Dollar"
--       , ciSymbol = "$"
--       , ciRate = 1.0
--       }
--
-- result <- runCurrencyRepository repo $ createCurrencyRepo input
-- case result of
--   Right currencyId -> putStrLn $ "Created currency with ID: " ++ show currencyId
--   Left err     -> putStrLn $ "Error: " ++ err
-- @
module DAL.Repository.Currency
  ( CurrencyRepository (..),
    HasCurrencyRepository (..),
    mkCurrencyRepository,
    runCurrencyRepository,
    listCurrenciesRepo,
    createCurrencyRepo,
    updateCurrencyRepo,
    deleteCurrencyRepo,
  )
where

import Control.Monad.IO.Class (liftIO)
import Control.Monad.Trans.Except (ExceptT, throwE)
import DAL.Mutations (createCurrency, deleteCurrency, updateCurrency)
import DAL.Queries (getCurrencies, getCurrencyById)
import DAL.Repository
import DAL.Types
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Hasql.Pool (Pool)
import Surypus.Types (fromDecimal)
import qualified Surypus.Validation as Validation

newtype CurrencyRepository = CurrencyRepository
  { curPool :: Pool
  }

instance Repository CurrencyRepository Currency where
  find repo currencyId = do
    result <- liftIO $ getCurrencyById (curPool repo) currencyId
    case result of
      QuerySuccess currency -> pure (Just currency)
      QueryError err
        | isNotFoundMessage err -> pure Nothing
        | otherwise -> throwE (DatabaseError err)

  findAll repo = do
    result <- liftIO $ getCurrencies (curPool repo)
    case result of
      QuerySuccess currencies -> pure currencies
      QueryError err -> throwE (DatabaseError err)

  create repo currency = do
    created <- createCurrencyRepo repo (toCurrencyInput currency)
    pure (currId created)

  update repo currencyId currency = do
    updated <- updateCurrencyRepo repo currencyId (toCurrencyInput currency)
    pure (Just updated)

  delete repo currencyId = do
    deleteCurrencyRepo repo currencyId
    pure Nothing

listCurrenciesRepo :: CurrencyRepository -> ExceptT RepositoryError IO [Currency]
listCurrenciesRepo = findAll

createCurrencyRepo :: CurrencyRepository -> CurrencyInput -> ExceptT RepositoryError IO Currency
createCurrencyRepo repo input = do
  validated <- validateCurrencyInputRepo input
  mutation <- liftIO $ createCurrency (curPool repo) validated
  currencyId <- extractMutationId "Currency created but id was not returned" mutation
  mCurrency <- find repo currencyId
  case mCurrency of
    Just currency -> pure currency
    Nothing -> throwE (NotFound "Created currency was not found")

updateCurrencyRepo :: CurrencyRepository -> Int64 -> CurrencyInput -> ExceptT RepositoryError IO Currency
updateCurrencyRepo repo currencyId input = do
  validated <- validateCurrencyInputRepo input
  mutation <- liftIO $ updateCurrency (curPool repo) currencyId validated
  _ <- extractMutationId "Currency updated but id was not returned" mutation
  mCurrency <- find repo currencyId
  case mCurrency of
    Just currency -> pure currency
    Nothing -> throwE (NotFound "Updated currency was not found")

deleteCurrencyRepo :: CurrencyRepository -> Int64 -> ExceptT RepositoryError IO ()
deleteCurrencyRepo repo currencyId = do
  mutation <- liftIO $ deleteCurrency (curPool repo) currencyId
  case mutation of
    QuerySuccess _ -> pure ()
    QueryError err
      | isNotFoundMessage err -> throwE (NotFound "Currency not found")
      | otherwise -> throwE (DatabaseError err)

toCurrencyInput :: Currency -> CurrencyInput
toCurrencyInput currency =
  CurrencyInput
    { ciCode = currCode currency,
      ciName = currName currency,
      ciSymbol = currSymbol currency,
      ciRate = fromDecimal (currRateToBase currency)
    }

validateCurrencyInputRepo :: CurrencyInput -> ExceptT RepositoryError IO CurrencyInput
validateCurrencyInputRepo input = case Validation.validateCurrencyInput input of
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

class HasCurrencyRepository a where
  getCurrencyRepository :: a -> CurrencyRepository

instance HasCurrencyRepository CurrencyRepository where
  getCurrencyRepository = id

instance HasRepository CurrencyRepository Pool where
  getRepository = curPool

mkCurrencyRepository :: Pool -> CurrencyRepository
mkCurrencyRepository = CurrencyRepository

runCurrencyRepository :: CurrencyRepository -> RepositoryT IO a -> IO (Either RepositoryError a)
runCurrencyRepository repo = runRepository (defaultRepositoryContext (curPool repo))
