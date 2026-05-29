{-# LANGUAGE OverloadedStrings #-}

module DAL.Database (
    Pool,
    ConnectionPool,
    usePool,
    UsageError,
) where

import Hasql.Pool (Pool, UsageError, use)
import qualified Hasql.Session as Session
import Database.Persist.Postgresql (ConnectionPool)

-- | Alias for Hasql's use function with proper naming for this codebase
usePool :: Pool -> Session.Session a -> IO (Either UsageError a)
usePool = use
