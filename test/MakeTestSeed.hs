{-# LANGUAGE OverloadedStrings #-}
module MakeTestSeed (applyMigrations, seedInitialData) where

import System.Environment (lookupEnv)
import System.Directory (doesDirectoryExist, listDirectory)
import System.FilePath (takeExtension, (</>))
import Data.List (sort)
import qualified Data.Text as T
import qualified Data.Text.IO as TIO
import Data.Text (Text)
import qualified Data.Text.Encoding as TE
import Database.PostgreSQL.Simple
import Control.Exception (catch, SomeException)
import Data.Int (Int64)

-- Apply all SQL migrations found under sql/migrations in lexical order
applyMigrations :: IO ()
applyMigrations = do
  mdsn <- lookupEnv "TEST_DB_DSN"
  conn <- case mdsn of
    Just dsn -> connectPostgreSQL dsn
    Nothing  -> do
      -- defaults for local testing
      let ci = defaultConnectInfo { connectHost = "127.0.0.1"
                                 , connectPort = 5432
                                 , connectDatabase = "surypus_test"
                                 , connectUser = "postgres"
                                 , connectPassword = ""
                                 }
      connect ci
  runMigrations conn
  close conn

seedInitialData :: Connection -> IO ()
seedInitialData conn = do
  exists <- doesDirectoryExist "sql/seeds"
  if exists
    then do
      files <- listDirectory "sql/seeds"
      mapM_ (applySqlFile conn) (sort (filter ((== ".sql") . takeExtension) files))
    else return ()

-- Helpers
runMigrations :: Connection -> IO ()
runMigrations conn = do
  exists <- doesDirectoryExist "sql/migrations"
  if not exists
    then putStrLn "No migrations directory found at sql/migrations; skipping."
    else do
      files <- listDirectory "sql/migrations"
      mapM_ (applySqlFile conn) (sort (filter ((== ".sql") . takeExtension) files))

applySqlFile :: Connection -> FilePath -> IO ()
applySqlFile conn path = do
  sql <- TIO.readFile path
  let q = Query (TE.encodeUtf8 sql)
  _ <- execute_ conn q `catch` (s -> handler rs)
  return ()

handler :: SomeException -> IO Int64
handler e = do
  putStrLn $ "Migration error: " ++ show e
  return 0
