{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}

module DAL.Repository.Currency
  ( CurrencyRepository (..),
    HasCurrencyRepository (..),
    mkCurrencyRepository,
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
import DAL.Repository (HasRepository (..), RepositoryError (..), isNotFoundMessage)
import DAL.Types
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Hasql.Pool (Pool)
import qualified Surypus.Validation as Validation

newtype CurrencyRepository = CurrencyRepository
  { curPool :: Pool
  }

listCurrenciesRepo :: CurrencyRepository -> ExceptT RepositoryError IO [Currency]
listCurrenciesRepo repo = do
  result <- liftIO $ getCurrencies (curPool repo)
  case result of
    QuerySuccess currencies -> pure currencies
    QueryError err -> throwE (DatabaseError err)

createCurrencyRepo :: CurrencyRepository -> CurrencyInput -> ExceptT RepositoryError IO Currency
createCurrencyRepo repo input = do
  validated <- validateCurrencyInputRepo input
  mutation <- liftIO $ createCurrency (curPool repo) validated
  currencyId <- extractMutationId "Currency created but id was not returned" mutation
  result <- liftIO $ getCurrencyById (curPool repo) currencyId
  case result of
    QuerySuccess currency -> pure currency
    QueryError err -> throwE (DatabaseError err)

updateCurrencyRepo :: CurrencyRepository -> Int64 -> CurrencyInput -> ExceptT RepositoryError IO Currency
updateCurrencyRepo repo currencyId input = do
  validated <- validateCurrencyInputRepo input
  mutation <- liftIO $ updateCurrency (curPool repo) currencyId validated
  _ <- extractMutationId "Currency updated but id was not returned" mutation
  result <- liftIO $ getCurrencyById (curPool repo) currencyId
  case result of
    QuerySuccess currency -> pure currency
    QueryError err -> throwE (DatabaseError err)

deleteCurrencyRepo :: CurrencyRepository -> Int64 -> ExceptT RepositoryError IO ()
deleteCurrencyRepo repo currencyId = do
  mutation <- liftIO $ deleteCurrency (curPool repo) currencyId
  case mutation of
    QuerySuccess _ -> pure ()
    QueryError err
      | isNotFoundMessage err -> throwE (NotFound "Currency not found")
      | otherwise -> throwE (DatabaseError err)

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
  getPool = curPool

mkCurrencyRepository :: Pool -> CurrencyRepository
mkCurrencyRepository = CurrencyRepository
