-- | Main entry point for Surypus API server
module Main where

import qualified Data.Text          as T
import           System.Environment (getArgs, getEnv, getEnvironment)
import           System.IO          (hPutStrLn, stderr)

import           API.Server         (ServerConfig (..), runServer)
import           DB.Connection      (Pool, PoolConfig (..), closePool, createPool,
                                     initSchema)
import           Core.Service       (ServiceCommand (..), initialServiceState,
                                     parseServiceCommand, serviceCommandHelp,
                                     serviceStatePhase, transition)
import           Core.ServiceManager (runDaemon)

main :: IO ()
main = do
  args <- getArgs
  putStrLn "========================================="
  putStrLn "  Surypus - ERP/CRM System"
  putStrLn "  Version 0.1.0"
  putStrLn "========================================="

  -- Load configuration from environment
  host <- getEnvDefault "SURYPUS_HOST" "0.0.0.0"
  port <- read <$> getEnvDefault "SURYPUS_PORT" "3000"
  pgHost <- getEnvDefault "SURYPUS_PG_HOST" "localhost"
  pgPort <- read <$> getEnvDefault "SURYPUS_PG_PORT" "5432"
  pgUser <- getEnvDefault "SURYPUS_PG_USER" "surypus"
  pgPass <- getEnvDefault "SURYPUS_PG_PASSWORD" "surypus"
  pgDb <- getEnvDefault "SURYPUS_PG_DATABASE" "surypus"

  let poolCfg = PoolConfig
        { pcHost = pgHost
        , pcPort = pgPort
        , pcUser = pgUser
        , pcPassword = pgPass
        , pcDatabase = pgDb
        , pcConnections = 10
        , pcStripes = 1
        , pcIdleTime = 60
        }

      serverCfg = ServerConfig
        { scPort = port
        , scHost = host
        , scPoolConfig = poolCfg
        }

  putStrLn $ "Database: " ++ pgHost ++ ":" ++ show pgPort ++ "/" ++ pgDb
  putStrLn $ "Server: " ++ host ++ ":" ++ show port

  -- Create connection pool
  putStrLn "Creating database connection pool..."
  pool <- createPool poolCfg

  -- Initialize schema (only if tables don't exist)
  putStrLn "Initializing database schema..."
  initSchema pool

  case parseServiceCommand args of
    Just cmd -> runServiceMode serverCfg pool cmd
    Nothing -> do
      -- Run server
      putStrLn "Starting API server..."
      runServer serverCfg pool

  -- Cleanup on exit
  closePool pool

-- | Get environment variable with default
getEnvDefault :: String -> String -> IO String
getEnvDefault name defaultVal = do
  val <- tryGetEnv name
  return $ case val of
    Just v  -> v
    Nothing -> defaultVal
  where
    tryGetEnv n = do
      envs <- getEnvironment
      return $ lookup n envs

runServiceMode :: ServerConfig -> Pool -> ServiceCommand -> IO ()
runServiceMode _ _ CmdHelp = putStrLn (T.unpack serviceCommandHelp)
runServiceMode serverCfg pool cmd = case transition initialServiceState cmd of
  Left err -> hPutStrLn stderr (T.unpack err)
  Right state -> do
    putStrLn $ "Service phase: " ++ show (serviceStatePhase state)
    case cmd of
      CmdRun -> do
        putStrLn "Executing ppws run command"
        runServer serverCfg pool
      CmdInstall login pw -> do
        putStrLn $ "Installing service (login=" ++ show login ++ ", password=" ++ show pw ++ ")"
      CmdUninstall ->
        putStrLn "Uninstalling service"
      CmdStart ->
        putStrLn "Starting service daemon"
      CmdStop ->
        putStrLn "Stopping service daemon"
      CmdClient ->
        putStrLn "Running client utilities"
      CmdDaemon -> do
        putStrLn "Starting daemon jobs"
        runDaemon pool
      CmdRFID ->
        putStrLn "Running RFID processor"
      _ ->
        return ()
