module System.LoadBalancer where

import Control.Concurrent.STM (TVar, atomically, newTVarIO, readTVar, writeTVar)
import qualified Data.Set as Set
import Data.Word (Word32)

-- | Load balancer configuration
data LoadBalancerConfig = LoadBalancerConfig
  { lbAlgorithm :: LoadBalancingAlgorithm,
    lbMaxConnections :: Int,
    lbHealthCheckInterval :: Int
  }

-- | Load balancing algorithms
data LoadBalancingAlgorithm
  = RoundRobin
  | LeastConnections
  | IPHash
  | WeightedRoundRobin
  deriving (Show, Eq)

-- | Server definition
data Server = Server
  { serverId :: Text,
    serverAddress :: Text,
    serverWeight :: Int,
    serverActive :: Bool,
    serverCurrentConnections :: TVar Int
  }

-- | Load balancer state
data LoadBalancer = LoadBalancer
  { lbConfig :: LoadBalancerConfig,
    lbServers :: TVar [Server],
    lbCurrentIndex :: TVar Int,
    lbClientMappings :: TVar (Map.Map Text Text)
  }

-- | Initialize load balancer
initLoadBalancer :: LoadBalancerConfig -> IO LoadBalancer
initLoadBalancer config = do
  serversVar <- newTVarIO []
  indexVar <- newTVarIO 0
  mappingsVar <- newTVarIO Map.empty
  return $ LoadBalancer config serversVar indexVar mappingsVar

-- | Add server to load balancer
addServer :: LoadBalancer -> Server -> IO ()
addServer lb server = atomically $ do
  servers <- readTVar (lbServers lb)
  writeTVar (lbServers lb) (servers ++ [server])

-- | Remove server from load balancer
removeServer :: LoadBalancer -> Text -> IO ()
removeServer lb serverId = atomically $ do
  servers <- readTVar (lbServers lb)
  let filtered = filter (\s -> serverId /= serverId s) servers
  writeTVar (lbServers lb) filtered

-- | Get next server based on algorithm
getNextServer :: LoadBalancer -> IO (Maybe Server)
getNextServer lb = do
  servers <- readTVarIO (lbServers lb)
  let activeServers = filter serverActive servers
  if null activeServers
    then return Nothing
    else case lbAlgorithm (lbConfig lb) of
      RoundRobin -> do
        idx <- readTVarIO (lbCurrentIndex lb)
        let nextIdx = (idx + 1) `mod` length activeServers
        atomically $ writeTVar (lbCurrentIndex lb) nextIdx
        return $ Just (activeServers !! nextIdx)
      LeastConnections -> return $ Just (minimumBy (compare `on` (fmap =<< readTVarIO . serverCurrentConnections)) activeServers)
      IPHash -> error "IPHash not implemented"
      WeightedRoundRobin -> error "WeightedRoundRobin not implemented"

-- | Handle client request
handleRequest :: LoadBalancer -> Text -> IO (Maybe Server)
handleRequest lb clientIp = do
  mServer <- getNextServer lb
  case mServer of
    Just server -> do
      -- Increment connection count
      atomically $ do
        conn <- readTVar (serverCurrentConnections server)
        writeTVar (serverCurrentConnections server) (conn + 1)
      -- Map client to server (sticky sessions)
      atomically $ do
        mappings <- readTVar (lbClientMappings lb)
        let updated = Map.insert clientIp (serverId server) mappings
        writeTVar (lbClientMappings lb) updated
      return mServer
    Nothing -> return Nothing

-- | Health check server
healthCheckServer :: Server -> IO Bool
healthCheckServer server = do
  -- Simulate health check
  return True

-- | Run health checks
runHealthChecks :: LoadBalancer -> IO ()
runHealthChecks lb = do
  servers <- readTVarIO (lbServers lb)
  mapM_
    ( \s -> do
        healthy <- healthCheckServer s
        atomically $ do
          -- Update server active status
          writeTVar (serverCurrentConnections s) 0
        return ()
    )
    servers

-- | Get server statistics
getServerStats :: LoadBalancer -> IO [(Text, Int)]
getServerStats lb = do
  servers <- readTVarIO (lbServers lb)
  return $ map (\s -> (serverId s, =<< readTVarIO (serverCurrentConnections s))) servers
