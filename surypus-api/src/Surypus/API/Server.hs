{-# LANGUAGE DataKinds #-}
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
import qualified Data.Text.Encoding as TE
import qualified Data.Text.Lazy as TL
import qualified Data.Text.Lazy.Encoding as LBS
import Hasql.Pool (Pool)
import Network.Wai as W
import Servant (Application, Handler, Server, ServerError(..), err404, err500, serve, throwError, (:>), Get, Post, ReqBody, JSON, (:<|>) (..), Capture)
import qualified Data.UUID as UUID
import qualified Data.UUID.V4 as UUID
import qualified Surypus.API.Logger as Log
import DAL.Types (QueryResult (..), Bill (..), BillInput (..), Goods (..), Person (..), Payment (..))
import qualified Surypus.API.Bills as Bills
import qualified Surypus.API.Goods as Goods
import qualified Surypus.API.Persons as Persons
import qualified Surypus.API.Payment as Payments

data Env = Env
  { envPool :: Pool,
    envLogger :: Log.Logger
  }

-- | Correlation ID middleware
correlationMiddleware :: Log.Logger -> Application -> Application
correlationMiddleware logger app req respond = do
  let corrIdHeader = lookup "x-correlation-id" (W.requestHeaders req)
  corrId <- case corrIdHeader of
    Just cid -> return (TE.decodeUtf8 cid)
    Nothing -> UUID.toText <$> UUID.nextRandom
  Log.withCorrelationId logger corrId $
    app req respond

apiServer :: Pool -> Log.Logger -> Application
apiServer pool logger =
  let env = Env pool logger
   in correlationMiddleware logger (serve (Proxy @SurypusApi) (server env))

startServantServer :: Pool -> Log.Logger -> IO ()
startServantServer _ logger = do
  Log.logInfo logger "SERVER" "Starting Servant server" []
  pure ()

-- | Full Surypus API type
type SurypusApi =
  "api" :> "v1" :> 
    ( "bills" :> Get '[JSON] [Bill]
      :<|> "bills" :> ReqBody '[JSON] BillInput :> Post '[JSON] Bill
      :<|> "bills" :> Capture "id" Int64 :> Get '[JSON] Bill
      :<|> "goods" :> Get '[JSON] [Goods]
      :<|> "persons" :> Get '[JSON] [Person]
      :<|> "payments" :> Get '[JSON] [Payment]
    )

server :: Env -> Server SurypusApi
server env =
  ( billsList env
    :<|> billsCreate env
    :<|> billGet env
    :<|> goodsList env
    :<|> personsList env
    :<|> paymentsList env
  )

billsList :: Env -> Handler [Bill]
billsList env = do
  result <- liftIO $ Bills.listBills (envPool env) Nothing Nothing Nothing Nothing Nothing Nothing
  case result of
    QuerySuccess bills -> pure bills
    QueryError err -> throwError $ err500 {errBody = LBS.encodeUtf8 $ "Database error: " <> TL.fromStrict err}

billsCreate :: Env -> BillInput -> Handler Bill
billsCreate env input = do
  result <- liftIO $ Bills.createBill (envPool env) input
  case result of
    QuerySuccess bill -> pure bill
    QueryError err -> throwError $ err500 {errBody = LBS.encodeUtf8 $ "Database error: " <> TL.fromStrict err}

billGet :: Env -> Int64 -> Handler Bill
billGet env bid = do
  result <- liftIO $ Bills.getBill (envPool env) bid
  case result of
    QuerySuccess bill -> pure bill
    QueryError "Not Found" -> throwError err404
    QueryError err -> throwError $ err500 {errBody = LBS.encodeUtf8 $ "Database error: " <> TL.fromStrict err}

goodsList :: Env -> Handler [Goods]
goodsList env = do
  result <- liftIO $ Goods.listGoods (envPool env) Nothing Nothing Nothing Nothing
  case result of
    QuerySuccess goods -> pure goods
    QueryError err -> throwError $ err500 {errBody = LBS.encodeUtf8 $ "Database error: " <> TL.fromStrict err}

personsList :: Env -> Handler [Person]
personsList env = do
  result <- liftIO $ Persons.listPersons (envPool env) Nothing Nothing Nothing Nothing Nothing
  case result of
    QuerySuccess persons -> pure persons
    QueryError err -> throwError $ err500 {errBody = LBS.encodeUtf8 $ "Database error: " <> TL.fromStrict err}

paymentsList :: Env -> Handler [Payment]
paymentsList env = do
  result <- liftIO $ Payments.listPayments (envPool env)
  case result of
    QuerySuccess payments -> pure payments
    QueryError err -> throwError $ err500 {errBody = LBS.encodeUtf8 $ "Database error: " <> TL.fromStrict err}
