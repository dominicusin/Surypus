{-# LANGUAGE OverloadedStrings #-}
module DAL.Database (
    Pool,
    createPool,
    closePool,
    ConnectionPool,
    runDb,
    runDbWithTenant,
) where

import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Database.Persist.Postgresql (ConnectionPool, createPostgresqlPool)
import Database.Persist.Sql (SqlPersistT, runSqlPool, PersistValue(..), rawExecute)
import Control.Monad.Logger (runNoLoggingT)
import Data.ByteString.Char8 (pack)

type Pool = ConnectionPool

createPool :: IO ConnectionPool
createPool = runNoLoggingT $ createPostgresqlPool (pack "host=localhost port=5432 dbname=surypus user=postgres password=postgres") 10

closePool :: ConnectionPool -> IO ()
closePool _ = return ()

runDb :: ConnectionPool -> SqlPersistT IO a -> IO a
runDb pool action = runSqlPool action pool

-- | Run a database action scoped to a specific tenant.
-- Sets the tenant context before the action and clears it after.
runDbWithTenant :: Int64 -> Int64 -> ConnectionPool -> SqlPersistT IO a -> IO a
runDbWithTenant tenantId userId pool action =
  runSqlPool (do
    rawExecute "SELECT set_config('app.tenant_id', ?, TRUE)"
      [PersistText (T.pack $ show tenantId)]
    rawExecute "SELECT set_config('app.user_id', ?, TRUE)"
      [PersistText (T.pack $ show userId)]
    result <- action
    rawExecute "SELECT set_config('app.tenant_id', '', TRUE)" []
    rawExecute "SELECT set_config('app.user_id', '', TRUE)" []
    pure result
    ) pool
