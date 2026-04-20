{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE ScopedTypeVariables #-}

module System.CircuitBreaker
  ( CBConfig (..),
    CircuitBreaker,
    BreakerState (..),
    initCircuitBreaker,
    withBreaker,
  )
where

import Control.Concurrent.STM (STM, TVar, atomically, newTVarIO, readTVar, writeTVar)
import Control.Exception (SomeException, try)
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text as TT
import Data.Time.Clock (NominalDiffTime, UTCTime, addUTCTime, diffUTCTime, getCurrentTime)
import GHC.Generics (Generic)

data BreakerState = CBClosed | CBOpen UTCTime | CBHalfOpen Int deriving (Show, Eq)

data CBConfig = CBConfig
  { cbMaxFailures :: Int,
    cbResetTimeout :: NominalDiffTime,
    cbHalfOpenMaxCalls :: Int
  }
  deriving (Show, Eq, Generic)

data CircuitBreaker = CircuitBreaker
  { cbState :: TVar BreakerState,
    cbConfig :: CBConfig
  }

initCircuitBreaker :: CBConfig -> IO CircuitBreaker
initCircuitBreaker cfg = do
  st <- newTVarIO CBClosed
  pure $ CircuitBreaker st cfg

withBreaker :: CircuitBreaker -> IO a -> IO (Either Text a)
withBreaker cb action = do
  now <- getCurrentTime
  state <- atomically $ readTVar (cbState cb)
  case state of
    CBOpen t ->
      if now < t
        then pure $ Left (T.pack "Circuit is open")
        else do
          atomically $ writeTVar (cbState cb) (CBHalfOpen 0)
          run
    CBHalfOpen _ -> run
    CBClosed -> run
  where
    run = do
      result <- try action
      case result of
        Right val -> do
          atomically $ writeTVar (cbState cb) CBClosed
          return $ Right val
        Left (e :: SomeException) -> do
          now' <- getCurrentTime
          atomically $ writeTVar (cbState cb) (CBOpen now')
          return $ Left (T.pack $ show e)
