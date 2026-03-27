{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}

module DAL.Repository.Price
  ( PriceRepository (..),
    HasPriceRepository (..),
    mkPriceRepository,
    listGoodsPricesRepo,
    listGoodsPricesByGoodsRepo,
    createPriceRepo,
  )
where

import Control.Monad.IO.Class (liftIO)
import Control.Monad.Trans.Except (ExceptT, throwE)
import DAL.Mutations (createPrice)
import DAL.Queries (getGoodsPriceByGoods, getGoodsPriceById, getGoodsPrices)
import DAL.Repository (HasRepository (..), RepositoryError (..), isNotFoundMessage)
import DAL.Types
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Hasql.Pool (Pool)
import qualified Surypus.Validation as Validation

data PriceRepository = PriceRepository
  { prcPool :: Pool
  }

listGoodsPricesRepo :: PriceRepository -> ExceptT RepositoryError IO [GoodsPrice]
listGoodsPricesRepo repo = do
  result <- liftIO $ getGoodsPrices (prcPool repo)
  case result of
    QuerySuccess prices -> pure prices
    QueryError err -> throwE (DatabaseError err)

listGoodsPricesByGoodsRepo :: PriceRepository -> Int64 -> ExceptT RepositoryError IO [GoodsPrice]
listGoodsPricesByGoodsRepo repo goodsId = do
  result <- liftIO $ getGoodsPriceByGoods (prcPool repo) goodsId
  case result of
    QuerySuccess prices -> pure prices
    QueryError err -> throwE (DatabaseError err)

createPriceRepo :: PriceRepository -> PriceInput -> ExceptT RepositoryError IO GoodsPrice
createPriceRepo repo input = do
  validated <- validatePriceInputRepo input
  mutation <- liftIO $ createPrice (prcPool repo) validated
  priceId <- extractMutationId "Price created but id was not returned" mutation
  result <- liftIO $ getGoodsPriceById (prcPool repo) priceId
  case result of
    QuerySuccess price -> pure price
    QueryError err
      | isNotFoundMessage err -> throwE (NotFound "Created price was not found")
      | otherwise -> throwE (DatabaseError err)

validatePriceInputRepo :: PriceInput -> ExceptT RepositoryError IO PriceInput
validatePriceInputRepo input = case Validation.validatePriceInput input of
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

class HasPriceRepository a where
  getPriceRepository :: a -> PriceRepository

instance HasPriceRepository PriceRepository where
  getPriceRepository = id

instance HasRepository PriceRepository Pool where
  getRepository = prcPool

mkPriceRepository :: Pool -> PriceRepository
mkPriceRepository = PriceRepository
