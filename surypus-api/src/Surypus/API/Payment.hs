{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE OverloadedStrings #-}

module Surypus.API.Payment (
    listPayments,
    createPayment,
    getPayment,
    updatePayment,
    deletePayment,
)
where

import Control.Monad.IO.Class (liftIO)
import DAL.Database (ConnectionPool)
import qualified DAL.Mutations as Mut
import DAL.Types (MutationResult (..), Payment (..), PaymentInput (..), QueryResult (..))
import Data.Int (Int64)
import Database.Esqueleto.Experimental
import Database.Persist.Sql (runSqlPool, toSqlKey)
import DAL.Conversion (paymentFromEntity)
import DAL.Schema

listPayments :: ConnectionPool -> IO (QueryResult [Payment])
listPayments pool = do
    entities <- liftIO $ runSqlPool
        (select $ do
            p <- from $ table @PaymentEntity
            orderBy [desc $ p ^. PaymentEntityDate, desc $ p ^. PaymentEntityId]
            return p
        ) pool
    return $ QuerySuccess (map paymentFromEntity entities)

createPayment :: ConnectionPool -> PaymentInput -> IO (QueryResult MutationResult)
createPayment = Mut.createPayment

getPayment :: ConnectionPool -> Int64 -> IO (QueryResult Payment)
getPayment pool pid = do
    result <- liftIO $ runSqlPool
        (selectOne $ do
            p <- from $ table @PaymentEntity
            where_ $ p ^. PaymentEntityId ==. val (toSqlKey pid)
            return p
        ) pool
    case result of
        Nothing -> return $ QueryError "Not Found"
        Just entity -> return $ QuerySuccess (paymentFromEntity entity)

updatePayment :: ConnectionPool -> Int64 -> PaymentInput -> IO (QueryResult Payment)
updatePayment pool pid input = do
    result <- Mut.updatePayment pool pid input
    case result of
        QuerySuccess _ -> getPayment pool pid
        QueryError err -> return $ QueryError err

deletePayment :: ConnectionPool -> Int64 -> IO (QueryResult ())
deletePayment pool pid = do
    result <- Mut.deletePayment pool pid
    case result of
        QuerySuccess _ -> return $ QuerySuccess ()
        QueryError err -> return $ QueryError err
