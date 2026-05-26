{-# LANGUAGE OverloadedStrings #-}
{- | DAL.Database - Database connection pool wrapper
-}
module DAL.Database (
  -- * Pool Management  
  Pool,
  acquirePool,
  releasePool,
  usePool,
  runQuery,
  runCommand,
   
  -- * Connection Settings
  Settings,
  settings,
   
  -- * Session and Statement types (kept for compatibility)
  Session,
  Statement,
) where

import qualified Hasql.Connection as C
import qualified Hasql.Session as Session
import qualified Hasql.Statement as Statement
import qualified Hasql.Pool as Pool
import Data.Text (Text)
import qualified Data.Text as T
import Data.Either (Either(..))

type Pool = Pool.Pool
acquirePool = Pool.acquire
releasePool = Pool.release
usePool = Pool.use

runQuery :: Pool -> Statement.Statement params result -> params -> IO (Either Text result)
runQuery pool stmt params = do
  res <- Pool.use pool $ Session.statement params stmt
  case res of
    Left err -> pure $ Left (T.pack $ show err)
    Right val -> pure $ Right val

runCommand :: Pool -> Statement.Statement params () -> params -> IO (Either Text ())
runCommand pool stmt params = do
  res <- Pool.use pool $ Session.statement params stmt
  case res of
    Left err -> pure $ Left (T.pack $ show err)
    Right () -> pure $ Right ()

type Settings = C.Settings
settings = C.settings

type Session = Session.Session
type Statement = Statement.Statement
