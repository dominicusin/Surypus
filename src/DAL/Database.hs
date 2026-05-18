{-# LANGUAGE OverloadedStrings #-}
{- | DAL.Database - Database connection pool wrapper
-}
module DAL.Database (
  -- * Pool Management  
  Pool,
  acquirePool,
  releasePool,
  usePool,
  
  -- * Connection Settings
  Settings,
  settings,
  
  -- * Session and Statement types
  Session,
  Statement,
) where

import qualified Hasql.Connection as C
import qualified Hasql.Session as Session
import qualified Hasql.Statement as Statement
import qualified Hasql.Pool as Pool

type Pool = Pool.Pool
acquirePool = Pool.acquire
releasePool = Pool.release
usePool = Pool.use

type Settings = C.Settings
settings = C.settings

type Session = Session.Session
type Statement = Statement.Statement
