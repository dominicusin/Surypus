{-# LANGUAGE OverloadedStrings #-}

module DAL.Database (
    Pool,
    usePool,
    UsageError,
)
where

import Hasql.Pool (Pool, UsageError, use)
import qualified Hasql.Session as Session

-- | Alias for Hasql's use function with proper naming for this codebase
usePool :: Pool -> Session.Session a -> IO (Either UsageError a)
usePool = use
