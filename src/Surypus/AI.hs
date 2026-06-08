{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}

-- | AI Infrastructure Module - LLM integration and document parsing
-- Phase 22 of v3.0 roadmap
module Surypus.AI
  ( AIConfig   (..)
  , AIProvider   (..)
  , LLMRequest   (..)
  , LLMResponse   (..)
  , parseDocument
  , getRecommendations
  ) where

import Data.Text (Text)
import qualified Data.Text as T
import Data.Aeson (ToJSON, FromJSON, Value, object, parseJSON, withObject)
import GHC.Generics (Generic)
import Control.Monad.IO.Class (MonadIO, liftIO)
import Data.Time.Clock (getCurrentTime, UTCTime)

-- | AI Provider configuration
data AIProvider 
  = OpenAI
  | Anthropic
  | LocalLLM
  deriving (Show, Eq, Generic)

instance ToJSON AIProvider
instance FromJSON AIProvider

-- | AI Configuration
data AIConfig = AIConfig
  { aiProvider :: AIProvider
  , aiModel :: Text
  , aiApiKey :: Text
  , aiEndpoint :: Text
  } deriving (Show, Eq, Generic)

instance ToJSON AIConfig
instance FromJSON AIConfig

-- | LLM Request
data LLMRequest = LLMRequest
  { reqModel :: Text
  , reqMessages :: [Value]
  , reqMaxTokens :: Int
  , reqTemperature :: Double
  } deriving (Show, Eq, Generic)

instance ToJSON LLMRequest

-- | LLM Response
data LLMResponse = LLMResponse
  { respId :: Text
  , respContent :: Text
  , respModel :: Text
  , respCreatedAt :: UTCTime
  } deriving (Show, Eq, Generic)

instance FromJSON LLMResponse

-- | Parse a document using AI
parseDocument :: Text -> IO (Either Text LLMResponse)
parseDocument docContent = do
  -- TODO: Implement actual LLM call
  pure $ Right $ LLMResponse
    { respId = "stub"
    , respContent = T.take 100 docContent
    , respModel = "stub"
    , respCreatedAt = error "not implemented"
    }

-- | Get recommendations using AI
getRecommendations :: Text -> IO (Either Text [Text])
getRecommendations query = do
  -- TODO: Implement actual recommendations
  pure $ Right ["stub recommendation"]