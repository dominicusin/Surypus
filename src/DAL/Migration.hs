{-# LANGUAGE OverloadedStrings #-}

module DAL.Migration
  ( runMigrations
  , runMigrationsQuiet
  , migrateAll
  ) where

import Data.Text (Text)
import Database.Persist.Sql (SqlPersistT, runMigrationQuiet, runMigration)
import DAL.Schema (migrateAll)

runMigrations :: SqlPersistT IO ()
runMigrations = runMigration migrateAll

runMigrationsQuiet :: SqlPersistT IO [Text]
runMigrationsQuiet = runMigrationQuiet migrateAll
