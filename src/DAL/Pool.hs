-- | Canonical Pool type for Surypus.
-- All modules should import from here instead of DAL.Database,
-- DAL.ORMPool, or DAL.Hasql.Database.
module DAL.Pool
  ( ConnectionPool
  , createPool
  , closePool
  , runDb
  ) where

import DAL.Database (ConnectionPool, createPool, closePool, runDb)
