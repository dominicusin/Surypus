{-# LANGUAGE OverloadedStrings #-}
module DAL.Database (
    Pool,
    createPool,
    closePool,
    ConnectionPool,
    runDb,
) where

import Database.Persist.Postgresql (ConnectionPool, createPostgresqlPool)
import Database.Persist.Sql (SqlPersistT, runSqlPool)
import Control.Monad.Logger (runNoLoggingT)
import Data.ByteString.Char8 (pack)

type Pool = ConnectionPool

createPool :: IO ConnectionPool
createPool = runNoLoggingT $ createPostgresqlPool (pack "host=localhost port=5432 dbname=surypus user=postgres password=postgres") 10

closePool :: ConnectionPool -> IO ()
closePool _ = return ()

runDb :: ConnectionPool -> SqlPersistT IO a -> IO a
runDb pool action = runSqlPool action pool
