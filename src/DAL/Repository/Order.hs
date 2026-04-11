{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}

module DAL.Repository.Order
  ( OrderRepository (..),
    HasOrderRepository (..),
    mkOrderRepository,
    listOrdersPage,
    createOrderRepo,
    updateOrderStatusRepo,
    deleteOrderRepo,
  )
where

import Control.Monad.IO.Class (liftIO)
import Control.Monad.Trans.Except (ExceptT, throwE)
import DAL.Mutations (createOrder, deleteOrder, updateOrderStatus)
import DAL.Queries (getOrderById, getOrders)
import DAL.Repository (HasRepository (..), RepositoryError (..), isNotFoundMessage)
import DAL.Types
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Hasql.Pool (Pool)
import qualified Surypus.Validation as Validation

newtype OrderRepository = OrderRepository
  { orPool :: Pool
  }

listOrdersPage :: OrderRepository -> Int64 -> Int64 -> ExceptT RepositoryError IO [Order]
listOrdersPage repo _limit _offset = do
  result <- liftIO $ getOrders (orPool repo)
  case result of
    QuerySuccess orders -> pure orders
    QueryError err -> throwE (DatabaseError err)

createOrderRepo :: OrderRepository -> OrderInput -> ExceptT RepositoryError IO Order
createOrderRepo repo input = do
  validated <- validateOrderInputRepo input
  mutation <- liftIO $ createOrder (orPool repo) validated
  orderId <- extractMutationId "Order created but id was not returned" mutation
  result <- liftIO $ getOrderById (orPool repo) orderId
  case result of
    QuerySuccess orderVal -> pure orderVal
    QueryError err -> throwE (DatabaseError err)

updateOrderStatusRepo :: OrderRepository -> Int64 -> Int64 -> ExceptT RepositoryError IO Order
updateOrderStatusRepo repo orderId statusId = do
  mutation <- liftIO $ updateOrderStatus (orPool repo) orderId (fromIntegral statusId)
  _ <- extractMutationId "Order updated but id was not returned" mutation
  result <- liftIO $ getOrderById (orPool repo) orderId
  case result of
    QuerySuccess orderVal -> pure orderVal
    QueryError err -> throwE (DatabaseError err)

deleteOrderRepo :: OrderRepository -> Int64 -> ExceptT RepositoryError IO ()
deleteOrderRepo repo orderId = do
  mutation <- liftIO $ deleteOrder (orPool repo) orderId
  case mutation of
    QuerySuccess _ -> pure ()
    QueryError err
      | isNotFoundMessage err -> throwE (NotFound "Order not found")
      | otherwise -> throwE (DatabaseError err)

validateOrderInputRepo :: OrderInput -> ExceptT RepositoryError IO OrderInput
validateOrderInputRepo input = case Validation.validateOrderInput input of
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

class HasOrderRepository a where
  getOrderRepository :: a -> OrderRepository

instance HasOrderRepository OrderRepository where
  getOrderRepository = id

instance HasRepository OrderRepository Pool where
  getPool = orPool

mkOrderRepository :: Pool -> OrderRepository
mkOrderRepository = OrderRepository
