{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}

module DAL.Repository.Tax
  ( TaxRepository (..),
    HasTaxRepository (..),
    mkTaxRepository,
    runTaxRepository,
    listTaxesRepo,
    createTaxRepo,
    updateTaxRepo,
    deleteTaxRepo,
  )
where

import Control.Monad.IO.Class (liftIO)
import Control.Monad.Trans.Except (ExceptT, throwE)
import DAL.Mutations (createTax, deleteTax, updateTax)
import DAL.Queries (getTaxById, getTaxes)
import DAL.Repository
import DAL.Types
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Hasql.Pool (Pool)
import Surypus.Types (fromDecimal)
import qualified Surypus.Validation as Validation

data TaxRepository = TaxRepository
  { trPool :: Pool
  }

instance Repository TaxRepository Tax where
  find repo tid = do
    result <- liftIO $ getTaxById (trPool repo) tid
    case result of
      QuerySuccess taxVal -> pure (Just taxVal)
      QueryError err
        | isNotFoundMessage err -> pure Nothing
        | otherwise -> throwE (DatabaseError err)

  findAll repo = do
    result <- liftIO $ getTaxes (trPool repo)
    case result of
      QuerySuccess taxes -> pure taxes
      QueryError err -> throwE (DatabaseError err)

  create repo taxVal = createTaxRepo repo (toTaxInput taxVal)

  update repo tid taxVal = updateTaxRepo repo tid (toTaxInput taxVal)

  delete = deleteTaxRepo

listTaxesRepo :: TaxRepository -> ExceptT RepositoryError IO [Tax]
listTaxesRepo = findAll

createTaxRepo :: TaxRepository -> TaxInput -> ExceptT RepositoryError IO Tax
createTaxRepo repo input = do
  validated <- validateTaxInputRepo input
  mutation <- liftIO $ createTax (trPool repo) validated
  tid <- extractMutationId "Tax created but id was not returned" mutation
  mTax <- find repo tid
  case mTax of
    Just taxVal -> pure taxVal
    Nothing -> throwE (NotFound "Created tax was not found")

updateTaxRepo :: TaxRepository -> Int64 -> TaxInput -> ExceptT RepositoryError IO Tax
updateTaxRepo repo tid input = do
  validated <- validateTaxInputRepo input
  mutation <- liftIO $ updateTax (trPool repo) tid validated
  _ <- extractMutationId "Tax updated but id was not returned" mutation
  mTax <- find repo tid
  case mTax of
    Just taxVal -> pure taxVal
    Nothing -> throwE (NotFound "Updated tax was not found")

deleteTaxRepo :: TaxRepository -> Int64 -> ExceptT RepositoryError IO ()
deleteTaxRepo repo tid = do
  mutation <- liftIO $ deleteTax (trPool repo) tid
  case mutation of
    QuerySuccess _ -> pure ()
    QueryError err
      | isNotFoundMessage err -> throwE (NotFound "Tax not found")
      | otherwise -> throwE (DatabaseError err)

toTaxInput :: Tax -> TaxInput
toTaxInput taxVal =
  TaxInput
    { tiName = taxName taxVal,
      tiRate = fromDecimal (taxRate taxVal),
      tiTaxType = 0,
      tiIncluded = False
    }

validateTaxInputRepo :: TaxInput -> ExceptT RepositoryError IO TaxInput
validateTaxInputRepo input = case Validation.validateTaxInput input of
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

class HasTaxRepository a where
  getTaxRepository :: a -> TaxRepository

instance HasTaxRepository TaxRepository where
  getTaxRepository = id

instance HasRepository TaxRepository Pool where
  getRepository = trPool

mkTaxRepository :: Pool -> TaxRepository
mkTaxRepository = TaxRepository

runTaxRepository :: TaxRepository -> RepositoryT IO a -> IO (Either RepositoryError a)
runTaxRepository repo action = runRepository (defaultRepositoryContext (trPool repo)) action
