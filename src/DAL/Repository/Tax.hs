{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Tax Repository with LiquidHaskell refinement types
module DAL.Repository.Tax
  ( TaxRepository (..),
    HasTaxRepository (..),
    mkTaxRepository,
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
import DAL.Repository (HasRepository (..), RepositoryError (..), isNotFoundMessage)
import DAL.Types
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Hasql.Pool (Pool)
import qualified Surypus.Validation as Validation

-- | Tax rate must be between 0 and 100

{-@ type TaxRate = {v:Double | v >= 0 && v <= 100} @-}

newtype TaxRepository = TaxRepository
  { trPool :: Pool
  }

-- | List all taxes - returns non-empty list when DB has data

{-@ listTaxesRepo :: TaxRepository -> ExceptT RepositoryError IO [Tax] @-}
listTaxesRepo :: TaxRepository -> ExceptT RepositoryError IO [Tax]
listTaxesRepo repo = do
  result <- liftIO $ getTaxes (trPool repo)
  case result of
    QuerySuccess taxes -> pure taxes
    QueryError err -> throwE (DatabaseError err)

-- | Create tax - validates input before mutation

{-@ createTaxRepo :: TaxRepository -> TaxInput -> ExceptT RepositoryError IO Tax @-}
createTaxRepo :: TaxRepository -> TaxInput -> ExceptT RepositoryError IO Tax
createTaxRepo repo input = do
  validated <- validateTaxInputRepo input
  mutation <- liftIO $ createTax (trPool repo) validated
  tid <- extractMutationId "Tax created but id was not returned" mutation
  result <- liftIO $ getTaxById (trPool repo) tid
  case result of
    QuerySuccess taxVal -> pure taxVal
    QueryError err -> throwE (DatabaseError err)

-- | Update tax - validates input before mutation

{-@ updateTaxRepo :: TaxRepository -> Int64 -> TaxInput -> ExceptT RepositoryError IO Tax @-}
updateTaxRepo :: TaxRepository -> Int64 -> TaxInput -> ExceptT RepositoryError IO Tax
updateTaxRepo repo tid input = do
  validated <- validateTaxInputRepo input
  mutation <- liftIO $ updateTax (trPool repo) tid validated
  _ <- extractMutationId "Tax updated but id was not returned" mutation
  result <- liftIO $ getTaxById (trPool repo) tid
  case result of
    QuerySuccess taxVal -> pure taxVal
    QueryError err -> throwE (DatabaseError err)

-- | Delete tax - succeeds silently if not found

{-@ deleteTaxRepo :: TaxRepository -> Int64 -> ExceptT RepositoryError IO () @-}
deleteTaxRepo :: TaxRepository -> Int64 -> ExceptT RepositoryError IO ()
deleteTaxRepo repo tid = do
  mutation <- liftIO $ deleteTax (trPool repo) tid
  case mutation of
    QuerySuccess _ -> pure ()
    QueryError err
      | isNotFoundMessage err -> throwE (NotFound "Tax not found")
      | otherwise -> throwE (DatabaseError err)

-- | Validate tax input before database operation

{-@ validateTaxInputRepo :: TaxInput -> ExceptT RepositoryError IO TaxInput @-}
validateTaxInputRepo :: TaxInput -> ExceptT RepositoryError IO TaxInput
validateTaxInputRepo input = case Validation.validateTaxInput input of
  Right ok -> pure ok
  Left errs ->
    throwE . ValidationError . T.intercalate "; " $ fmap validationMessage errs
  where
    validationMessage (Validation.ValidationError msg) = msg

-- | Extract mutation ID, fail if not present

{-@ extractMutationId :: Text -> QueryResult MutationResult -> ExceptT RepositoryError IO Int64 @-}
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
  getPool = trPool

mkTaxRepository :: Pool -> TaxRepository
mkTaxRepository = TaxRepository
