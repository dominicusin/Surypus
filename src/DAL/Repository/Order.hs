{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}

module DAL.Repository.Order
  ( OrderRepository (..),
    HasOrderRepository (..),
    mkOrderRepository,
    runOrderRepository,
    listOrdersPage,
    createOrderRepo,
    updateOrderStatusRepo,
    deleteOrderRepo,
  )
where

import Control.Monad.IO.Class (liftIO)
import Control.Monad.Trans.Except (ExceptT, throwE)
import DAL.Mutations (createOrder, deleteOrder, updateOrderStatus)
import DAL.Queries (getOrderById, getOrders, getOrdersPaginated)
import DAL.Repository
import DAL.Types
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Hasql.Pool (Pool)
import qualified Surypus.Validation as Validation

data OrderRepository = OrderRepository
  { orPool :: Pool
  }

instance Repository OrderRepository Order where
  find repo orderId = do
    result <- liftIO $ getOrderById (orPool repo) orderId
    case result of
      QuerySuccess orderVal -> pure (Just orderVal)
      QueryError err
        | isNotFoundMessage err -> pure Nothing
        | otherwise -> throwE (DatabaseError err)

  findAll repo = do
    result <- liftIO $ getOrders (orPool repo)
    case result of
      QuerySuccess orders -> pure orders
      QueryError err -> throwE (DatabaseError err)

  create repo orderVal = createOrderRepo repo (toOrderInput orderVal)

  update repo orderId orderVal = do
    _ <- updateOrderStatusRepo repo orderId (oStatus orderVal)
    mOrder <- find repo orderId
    case mOrder of
      Just updatedOrder -> pure updatedOrder
      Nothing -> throwE (NotFound "Updated order was not found")

  delete = deleteOrderRepo

listOrdersPage :: OrderRepository -> OrderFilter -> Pagination -> Maybe OrderSortBy -> Maybe SortDir -> ExceptT RepositoryError IO (PaginatedResult Order)
listOrdersPage repo orderFilter pagination sortBy sortDir = do
  result <- liftIO $ getOrdersPaginated (orPool repo) orderFilter pagination sortBy sortDir
  case result of
    QuerySuccess page -> pure page
    QueryError err -> throwE (DatabaseError err)

createOrderRepo :: OrderRepository -> OrderInput -> ExceptT RepositoryError IO Order
createOrderRepo repo input = do
  validated <- validateOrderInputRepo input
  mutation <- liftIO $ createOrder (orPool repo) validated
  orderId <- extractMutationId "Order created but id was not returned" mutation
  mOrder <- find repo orderId
  case mOrder of
    Just orderVal -> pure orderVal
    Nothing -> throwE (NotFound "Created order was not found")

updateOrderStatusRepo :: OrderRepository -> Int64 -> Int -> ExceptT RepositoryError IO Int64
updateOrderStatusRepo repo orderId status = do
  mutation <- liftIO $ updateOrderStatus (orPool repo) orderId status
  extractMutationId "Order status updated but id was not returned" mutation

deleteOrderRepo :: OrderRepository -> Int64 -> ExceptT RepositoryError IO ()
deleteOrderRepo repo orderId = do
  mutation <- liftIO $ deleteOrder (orPool repo) orderId
  case mutation of
    QuerySuccess _ -> pure ()
    QueryError err
      | isNotFoundMessage err -> throwE (NotFound "Order not found")
      | otherwise -> throwE (DatabaseError err)

toOrderInput :: Order -> OrderInput
toOrderInput orderVal =
  OrderInput
    { oiCode = oCode orderVal,
      oiName = oName orderVal,
      oiDate = oDate orderVal,
      oiPersonId = oPersonId orderVal,
      oiLocationId = oLocationId orderVal,
      oiStatus = oStatus orderVal,
      oiTotal = oTotal orderVal,
      oiDiscount = oDiscount orderVal,
      oiTax = oTax orderVal
    }

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
  getRepository = orPool

mkOrderRepository :: Pool -> OrderRepository
mkOrderRepository = OrderRepository

runOrderRepository :: OrderRepository -> RepositoryT IO a -> IO (Either RepositoryError a)
runOrderRepository repo action = runRepository (defaultRepositoryContext (orPool repo)) action
