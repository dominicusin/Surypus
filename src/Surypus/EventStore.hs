{-# LANGUAGE OverloadedStrings #-}

module Surypus.EventStore
  ( EventStore (..),
    newEventStore,
    logEvent,
    Event (..),
    storeEvent,
  )
where

import Control.Concurrent.STM
import Control.Concurrent.STM.TQueue
import qualified DAL.Mutations as Mutations
import Data.Aeson (Value, encode)
import qualified Data.Aeson as A
import qualified Data.ByteString.Lazy as BL
import Data.Functor.Contravariant ((>$<))
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import qualified Hasql.Decoders as D
import qualified Hasql.Encoders as E
import Hasql.Pool (Pool, use)
import qualified Hasql.Session as Session
import Hasql.Statement (Statement (..))
import qualified Surypus.WebSocket as WS

-- Simple event type for foundation
data Event = Event
  { evName :: Text,
    evPayload :: Value
  }
  deriving (Show)

newtype EventStore = EventStore {esQueue :: TQueue Event}

newEventStore :: IO EventStore
newEventStore = do
  q <- newTQueueIO
  pure $ EventStore q

logEvent :: EventStore -> Event -> IO ()
logEvent (EventStore q) e = atomically $ writeTQueue q e

storeEvent :: Pool -> Event -> IO (Either Text ())
storeEvent pool ev = do
  let payloadText = TE.decodeUtf8 $ BL.toStrict $ encode (evPayload ev)
      sql = "INSERT INTO event_store (event_name, payload, created_at) VALUES ($1, $2, NOW()) RETURNING id"
      encoder = (fst >$< E.param (E.nonNullable E.text)) <> (snd >$< E.param (E.nonNullable E.text))
      stmt = Mutations.unpreparable sql encoder (D.singleRow (D.column (D.nonNullable D.int8)))
  res <- use pool $ Session.statement (evName ev, payloadText) stmt
  pure $ case res of
    Right _ -> Right ()
    Left err -> Left (T.pack $ show err)

storeEventAndNotify :: Pool -> Event -> WS.WebSocketHub -> IO (Either Text ())
storeEventAndNotify pool ev hub = do
  r <- storeEvent pool ev
  case r of
    Right _ -> do
      -- Notify connected clients with a generic system event
      WS.broadcastEvent hub WS.NTSystem (evPayload ev)
      return r
    Left err -> return $ Left err
