{-# LANGUAGE OverloadedStrings #-}

module DAL.Migration
  ( runMigrations
  , runMigrationsQuiet
  , migrateAll
  ) where

import Data.Text (Text)
import Database.Persist.Sql (SqlPersistT, runMigrationQuiet, runMigration)

-- | Migrate all entities (Phase 1: no-op stub)
migrateAll :: SqlPersistT IO ()
migrateAll = return ()

-- | Run migrations
runMigrations :: SqlPersistT IO ()
runMigrations = migrateAll

-- | Run migrations quietly
runMigrationsQuiet :: SqlPersistT IO [Text]
runMigrationsQuiet = do
  migrateAll
  return []
