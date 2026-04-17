-- ============================================================================
-- API V1 - Persons
-- Simple summary endpoints for persons
-- ============================================================================

module API.V1.Persons (personsAPI) where

import Control.Monad.IO.Class (MonadIO (..))
import Data.Aeson (Value (..), object)
import qualified Data.UUID as UUID
import Servant
import Service.Auth (HasJWT, requireJWT, requirePerm)
import qualified Service.PersonService as PS

-- | Person Summary API
personsAPI :: PS.PersonService -> API
personsAPI svc = "summary" :> (getSummary :<|> getSnapshots)
  where
    getSummary :: Handler Value
    getSummary = do
      -- Call DB.PersonSummary
      return $ object ["summary" .= ([] :: [Value])]

    getSnapshots :: Handler [Value]
    getSnapshots = do
      -- List person snapshots
      return []

-- | Persons with permissions
personsPermAPI :: PS.PersonService -> API
personsPermAPI svc = requireJWT :. requirePerm "PersonRead" :> personsAPI svc

server :: PS.PersonService -> Server (personsPermAPI PS.PersonService)
server svc = personsServer svc
  where
    personsServer = serverFor (Proxy :: Proxy (personsPermAPI PS.PersonService))

app :: PS.PersonService -> Application
app svc = serveWithContext (Proxy :: Proxy (personsPermAPI PS.PersonService)) ctx (server svc)
  where
    ctx = ()

runOnPort :: Int -> PS.PersonService -> IO ()
runOnPort port svc = do
  let cfg = setPort port defaultServConfig
  runSettings cfg $ app svc
