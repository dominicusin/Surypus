{-# LANGUAGE OverloadedStrings #-}
module DAL.Database
  ( Pool,
    usePool,
    UsageError,
  )
where

import qualified Database.PostgreSQL.Simple as PQ
import qualified Database.PostgreSQL.Simple.Pool as PQPool
import Control.Exception (catch)

type UsageError = PQ.SqlError
type Pool = PQPool.PostgresPool

usePool :: Pool -> (PQ.Connection -> IO a) -> IO (Either UsageError a)
usePool pool action =
  catch (Right <$> PQPool.withResource pool action)
        (\e -> return $ Left e)