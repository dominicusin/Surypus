{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeOperators #-}

module Surypus.API.Server (apiServer, startServantServer) where

import Control.Monad.IO.Class (liftIO)
import Data.Int (Int64)
import Data.Proxy (Proxy (..))
import Data.Text (Text)
import qualified Data.Text.Encoding as TE
import qualified Data.Text as T
import qualified Data.Text.Lazy.Encoding as LBS
import Hasql.Pool (Pool)
import Network.Wai as W
import Servant (Application, Handler, Server, err401, err403, err500, serve, serveWithContext, throwError)
import qualified Data.UUID as UUID
import qualified Data.UUID.V4 as UUID
import qualified Surypus.API.Logger as Log
import DAL.Types (QueryResult (..), BillInput (..), GoodsInput (..))
import qualified Surypus.API.Bills as Bills
import qualified Surypus.API.Goods as Goods
import qualified Surypus.API.Persons as Persons
import qualified Surypus.API.Payment as Payments

data Env = Env
  { envPool :: Pool,
    envLogger :: Log.Logger
  }

-- | Correlation ID middleware - extracts or generates correlation ID
correlationMiddleware :: Log.Logger -> Application -> Application
correlationMiddleware logger app req respond = do
  let corrIdHeader = lookup "x-correlation-id" (W.requestHeaders req)
  corrId <- case corrIdHeader of
    Just cid -> return (TE.decodeUtf8 cid)
    Nothing -> UUID.toText <$> UUID.nextRandom
  -- Continue with correlation ID in context
  Log.withCorrelationId logger corrId $
    app req respond

apiServer :: Pool -> Log.Logger -> Application
apiServer pool logger =
  let env = Env pool logger
   in correlationMiddleware logger (serve (Proxy @SurypusApi) (server env))

startServantServer :: Pool -> Log.Logger -> IO ()
startServantServer pool logger = do
  Log.logInfo logger "SERVER" "Starting Servant server" []
  pure ()

-- | Simplified API type
type SurypusApi =
  "bills" :> "list" :> Get '[JSON] [Text]
    :<|> "bills" :> "create" :> ReqBody '[JSON] BillInput :> Post '[JSON] Text
    :<|> "goods" :> "list" :> Get '[JSON] [Text]
    :<|> "persons" :> "list" :> Get '[JSON] [Text]
    :<|> "payments" :> "list" :> Get '[JSON] [Text]

server :: Env -> Server SurypusApi
server env =
  billsList env
    :<|> billsCreate env
    :<|> goodsList env
    :<|> personsList env
    :<|> paymentsList env

billsList :: Env -> Handler [Text]
billsList env = do
  result <- liftIO $ Bills.listBills (envPool env) Nothing Nothing Nothing Nothing Nothing Nothing
  case result of
    QuerySuccess bills -> pure [T.pack $ show (Prelude.length bills)]
    QueryError err -> throwError $ err500 {errBody = "Database error: " <> TE.encodeUtf8 (T.pack (show err))}

billsCreate :: Env -> BillInput -> Handler Text
billsCreate env input = do
  result <- liftIO $ Bills.createBill (envPool env) input
  case result of
    QuerySuccess _ -> pure "Created"
    QueryError err -> throwError $ err500 {errBody = "Database error: " <> TE.encodeUtf8 (T.pack (show err))}

goodsList :: Env -> Handler [Text]
goodsList env = do
  result <- liftIO $ Goods.listGoods (envPool env) Nothing Nothing Nothing Nothing
  case result of
    QuerySuccess goods -> pure [T.pack $ show (Prelude.length goods)]
    QueryError err -> throwError $ err500 {errBody = "Database error: " <> TE.encodeUtf8 (T.pack (show err))}

personsList :: Env -> Handler [Text]
personsList env = do
  result <- liftIO $ Persons.listPersons (envPool env) Nothing Nothing Nothing Nothing Nothing
  case result of
    QuerySuccess persons -> pure [T.pack $ show (Prelude.length persons)]
    QueryError err -> throwError $ err500 {errBody = "Database error: " <> TE.encodeUtf8 (T.pack (show err))}

paymentsList :: Env -> Handler [Text]
paymentsList env = do
  result <- liftIO $ Payments.listPayments (envPool env) Nothing Nothing Nothing Nothing
  case result of
    QuerySuccess payments -> pure [T.pack $ show (Prelude.length payments)]
    QueryError err -> throwError $ err500 {errBody = "Database error: " <> TE.encodeUtf8 (T.pack (show err))}