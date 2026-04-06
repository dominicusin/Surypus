{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Goods repository interface and implementation.
--
-- This module defines the repository pattern for Goods entities, providing
-- CRUD operations and query functions. It abstracts the database access
-- layer and allows for easy mocking in tests.
--
-- The repository is parameterized over a pool type, allowing different
-- connection pool implementations to be used.
--
-- === Examples
--
-- Creating a repository and finding goods by ID:
-- @
-- import DAL.Repository.Goods (GoodsRepository, mkGoodsRepository, runGoodsRepository)
-- import DAL.Types (Goods)
-- import Hasql.Pool (Pool)
--
-- -- Assuming you have a connection pool
-- let pool :: Pool = undefined -- TODO: Initialize pool
-- let repo :: GoodsRepository = mkGoodsRepository pool
--
-- -- Find goods by ID
-- result <- runGoodsRepository repo $ find 123
-- case result of
--   Right (Just goods) -> print (goods :: Goods)
--   Right Nothing  -> putStrLn "Goods not found"
--   Left err       -> putStrLn $ "Error: " ++ err
-- @
--
-- Listing goods with pagination:
-- @
-- import DAL.Repository.Goods (GoodsRepository, mkGoodsRepository, runGoodsRepository)
-- import DAL.Types (GoodsFilter, Pagination)
-- import Hasql.Pool (Pool)
--
-- -- Assuming you have a connection pool
-- let pool :: Pool = undefined -- TODO: Initialize pool
-- let repo :: GoodsRepository = mkGoodsRepository pool
-- let filter = GoodsFilter Nothing Nothing Nothing -- No filtering
-- let pagination = Pagination 10 0 -- First page, 10 items per page
--
-- result <- runGoodsRepository repo $ listGoodsPage filter pagination Nothing Nothing
-- case result of
--   Right paginated -> mapM_ print (prItems paginated)
--   Left err       -> putStrLn $ "Error: " ++ err
-- @
module DAL.Repository.Goods
  ( GoodsRepository (..),
    HasGoodsRepository (..),
    mkGoodsRepository,
    runGoodsRepository,
    listGoodsPage,
    searchGoodsRepo,
    createGoodsRepo,
    updateGoodsRepo,
    deleteGoodsRepo,
  )
where

import Control.Monad.IO.Class (liftIO)
import Control.Monad.Trans.Except (ExceptT, throwE)
import DAL.Mutations (createGoods, deleteGoods, updateGoods)
import DAL.Queries (getGoods, getGoodsById, getGoodsPaginated)
import qualified DAL.Queries as Queries
import DAL.Repository
import DAL.Types
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Hasql.Pool (Pool)
import qualified Surypus.Validation as Validation

newtype GoodsRepository = GoodsRepository
  { grPool :: Pool
  }

instance Repository GoodsRepository Goods where
  find repo goodsId = do
    result <- liftIO $ getGoodsById (grPool repo) goodsId
    case result of
      QuerySuccess goods -> pure (Just goods)
      QueryError err
        | isNotFoundMessage err -> pure Nothing
        | otherwise -> throwE (DatabaseError err)

  findAll repo = do
    result <- liftIO $ getGoods (grPool repo)
    case result of
      QuerySuccess goods -> pure goods
      QueryError err -> throwE (DatabaseError err)

  create repo goods = do
    created <- createGoodsRepo repo (toGoodsInput goods)
    pure (gId created)

  update repo goodsId goods = do
    updated <- updateGoodsRepo repo goodsId (toGoodsInput goods)
    pure (Just updated)

  delete repo goodsId = do
    deleteGoodsRepo repo goodsId
    pure Nothing

listGoodsPage :: GoodsRepository -> GoodsFilter -> Pagination -> Maybe GoodsSortBy -> Maybe SortDir -> ExceptT RepositoryError IO (PaginatedResult Goods)
listGoodsPage repo goodsFilter pagination sortBy sortDir = do
  result <- liftIO $ getGoodsPaginated (grPool repo) goodsFilter pagination sortBy sortDir
  case result of
    QuerySuccess page -> pure page
    QueryError err -> throwE (DatabaseError err)

searchGoodsRepo :: GoodsRepository -> Text -> ExceptT RepositoryError IO [Goods]
searchGoodsRepo repo queryText = do
  result <- liftIO $ Queries.searchGoods (grPool repo) queryText
  case result of
    QuerySuccess goods -> pure goods
    QueryError err -> throwE (DatabaseError err)

createGoodsRepo :: GoodsRepository -> GoodsInput -> ExceptT RepositoryError IO Goods
createGoodsRepo repo input = do
  validated <- validateGoodsInputRepo input
  mutation <- liftIO $ createGoods (grPool repo) validated
  goodsId <- extractMutationId "Goods created but id was not returned" mutation
  mGoods <- find repo goodsId
  case mGoods of
    Just goods -> pure goods
    Nothing -> throwE (NotFound "Created goods were not found")

updateGoodsRepo :: GoodsRepository -> Int64 -> GoodsInput -> ExceptT RepositoryError IO Goods
updateGoodsRepo repo goodsId input = do
  validated <- validateGoodsInputRepo input
  mutation <- liftIO $ updateGoods (grPool repo) goodsId validated
  _ <- extractMutationId "Goods updated but id was not returned" mutation
  mGoods <- find repo goodsId
  case mGoods of
    Just goods -> pure goods
    Nothing -> throwE (NotFound "Updated goods were not found")

deleteGoodsRepo :: GoodsRepository -> Int64 -> ExceptT RepositoryError IO ()
deleteGoodsRepo repo goodsId = do
  mutation <- liftIO $ deleteGoods (grPool repo) goodsId
  case mutation of
    QuerySuccess _ -> pure ()
    QueryError err
      | isNotFoundMessage err -> throwE (NotFound "Goods not found")
      | otherwise -> throwE (DatabaseError err)

toGoodsInput :: Goods -> GoodsInput
toGoodsInput goods =
  GoodsInput
    { giCode = gCode goods,
      giName = gName goods,
      giBarcode = gBarcode goods,
      giUnitId = gUnitId goods,
      giParentId = gParentId goods
    }

validateGoodsInputRepo :: GoodsInput -> ExceptT RepositoryError IO GoodsInput
validateGoodsInputRepo input = case Validation.validateGoodsInput input of
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

class HasGoodsRepository a where
  getGoodsRepository :: a -> GoodsRepository

instance HasGoodsRepository GoodsRepository where
  getGoodsRepository = id

instance HasRepository GoodsRepository Pool where
  getRepository = grPool

mkGoodsRepository :: Pool -> GoodsRepository
mkGoodsRepository = GoodsRepository

runGoodsRepository :: GoodsRepository -> RepositoryT IO a -> IO (Either RepositoryError a)
runGoodsRepository repo = runRepository (defaultRepositoryContext (grPool repo))
