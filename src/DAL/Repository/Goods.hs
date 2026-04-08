{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Goods Repository with LiquidHaskell refinement types
module DAL.Repository.Goods
  ( GoodsRepository (..),
    HasGoodsRepository (..),
    mkGoodsRepository,
    runGoodsRepository,
    listGoodsPage,
    createGoodsRepo,
    updateGoodsRepo,
    deleteGoodsRepo,
  )
where

import Control.Monad.IO.Class (liftIO)
import Control.Monad.Trans.Except (ExceptT, runExceptT, throwE)
import DAL.Mutations (createGoods, deleteGoods, updateGoods)
import DAL.Queries (getGoodsById, getGoodsPaginated)
import DAL.Repository (HasRepository (..), RepositoryError (..), isNotFoundMessage)
import DAL.Types
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Hasql.Pool (Pool)
import qualified Surypus.Validation as Validation

-- | Goods price must be non-negative

{-@ type GoodsPrice = {v:Double | v >= 0} @-}

-- | Goods quantity must be non-negative

{-@ type GoodsQty = {v:Int | v >= 0} @-}

newtype GoodsRepository = GoodsRepository
  { grPool :: Pool
  }

-- | Run repository action

{-@ runGoodsRepository :: GoodsRepository -> ExceptT RepositoryError IO a -> IO (Either RepositoryError a) @-}
runGoodsRepository :: GoodsRepository -> ExceptT RepositoryError IO a -> IO (Either RepositoryError a)
runGoodsRepository = runExceptT

-- | List goods with pagination and filtering

{-@ listGoodsPage :: GoodsRepository -> GoodsFilter -> Pagination -> Maybe GoodsSortBy -> Maybe SortDir -> ExceptT RepositoryError IO (PaginatedResult Goods) @-}
listGoodsPage :: GoodsRepository -> GoodsFilter -> Pagination -> Maybe GoodsSortBy -> Maybe SortDir -> ExceptT RepositoryError IO (PaginatedResult Goods)
listGoodsPage repo filter' pagination mSortBy mSortDir = do
  result <- liftIO $ getGoodsPaginated (grPool repo) filter' pagination mSortBy mSortDir
  case result of
    QuerySuccess goods -> pure goods
    QueryError err -> throwE (DatabaseError err)

-- | Create goods with validation

{-@ createGoodsRepo :: GoodsRepository -> GoodsInput -> ExceptT RepositoryError IO Goods @-}
createGoodsRepo :: GoodsRepository -> GoodsInput -> ExceptT RepositoryError IO Goods
createGoodsRepo repo input = do
  validated <- validateGoodsInputRepo input
  mutation <- liftIO $ createGoods (grPool repo) validated
  gid <- extractMutationId "Goods created but id was not returned" mutation
  result <- liftIO $ getGoodsById (grPool repo) gid
  case result of
    QuerySuccess goods -> pure goods
    QueryError err -> throwE (DatabaseError err)

-- | Update goods with validation

{-@ updateGoodsRepo :: GoodsRepository -> Int64 -> GoodsInput -> ExceptT RepositoryError IO Goods @-}
updateGoodsRepo :: GoodsRepository -> Int64 -> GoodsInput -> ExceptT RepositoryError IO Goods
updateGoodsRepo repo gid input = do
  validated <- validateGoodsInputRepo input
  mutation <- liftIO $ updateGoods (grPool repo) gid validated
  _ <- extractMutationId "Goods updated but id was not returned" mutation
  result <- liftIO $ getGoodsById (grPool repo) gid
  case result of
    QuerySuccess goods -> pure goods
    QueryError err -> throwE (DatabaseError err)

-- | Delete goods

{-@ deleteGoodsRepo :: GoodsRepository -> Int64 -> ExceptT RepositoryError IO () @-}
deleteGoodsRepo :: GoodsRepository -> Int64 -> ExceptT RepositoryError IO ()
deleteGoodsRepo repo gid = do
  mutation <- liftIO $ deleteGoods (grPool repo) gid
  case mutation of
    QuerySuccess _ -> pure ()
    QueryError err
      | isNotFoundMessage err -> throwE (NotFound "Goods not found")
      | otherwise -> throwE (DatabaseError err)

-- | Validate goods input

{-@ validateGoodsInputRepo :: GoodsInput -> ExceptT RepositoryError IO GoodsInput @-}
validateGoodsInputRepo :: GoodsInput -> ExceptT RepositoryError IO GoodsInput
validateGoodsInputRepo input = case Validation.validateGoodsInput input of
  Right ok -> pure ok
  Left errs ->
    throwE . ValidationError . T.intercalate "; " $ fmap validationMessage errs
  where
    validationMessage (Validation.ValidationError msg) = msg

-- | Extract mutation ID

{-@ extractMutationId :: Text -> QueryResult MutationResult -> ExceptT RepositoryError IO Int64 @-}
extractMutationId :: Text -> QueryResult MutationResult -> ExceptT RepositoryError IO Int64
extractMutationId missingIdMessage result = case result of
  QuerySuccess (MutationResult _ (Just rid) _) -> pure rid
  QuerySuccess _ -> throwE (DatabaseError missingIdMessage)
  QueryError err -> throwE (DatabaseError err)

class HasGoodsRepository a where
  getGoodsRepository :: a -> GoodsRepository

instance HasGoodsRepository GoodsRepository where
  getGoodsRepository = id

instance HasRepository GoodsRepository Pool where
  getPool = grPool

mkGoodsRepository :: Pool -> GoodsRepository
mkGoodsRepository = GoodsRepository
