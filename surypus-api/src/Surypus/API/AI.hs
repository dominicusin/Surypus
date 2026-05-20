{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}

-- | AI API - REST endpoints for LLM-powered features
-- Phase 22-02 of v3.0 roadmap
module Surypus.API.AI
  ( AIDocumentParseRequest (..)
  , AIDocumentParseResponse (..)
  , AIRecommendationRequest (..)
  , AIRecommendationResponse (..)
  , callLLM
  ) where

import Data.Text (Text)
import qualified Data.Text as T
import Data.Aeson (ToJSON, FromJSON, Value, object, (.=), parseJSON, withObject, (.:), genericToJSON, defaultOptions, fieldLabelModifier)
import GHC.Generics (Generic)

-- | Request to parse a document
data AIDocumentParseRequest = AIDocumentParseRequest
  { aipDocContent :: Text  -- Raw document text (PDF extracted)
  , aipDocType :: Text     -- "invoice", "receipt", "contract", etc.
  } deriving (Show, Eq, Generic)

instance ToJSON AIDocumentParseRequest
instance FromJSON AIDocumentParseRequest

-- | Parsed document response
data AIDocumentParseResponse = AIDocumentParseResponse
  { aiprVendor :: Maybe Text
  , aiprInvoiceNumber :: Maybe Text
  , aiprInvoiceDate :: Maybe Text
  , aiprDueDate :: Maybe Text
  , aiprTotalAmount :: Maybe Double
  , aiprLineItems :: [Value]  -- Generic line items
  , aiprRawJson :: Value      -- Full extracted JSON
  } deriving (Show, Eq, Generic)

instance ToJSON AIDocumentParseResponse
instance FromJSON AIDocumentParseResponse

-- | Request for AI recommendations
data AIRecommendationRequest = AIRecommendationRequest
  { airQuery :: Text
  , airContext :: Value
  } deriving (Show, Eq, Generic)

instance ToJSON AIRecommendationRequest
instance FromJSON AIRecommendationRequest

-- | AI recommendation response
data AIRecommendationResponse = AIRecommendationResponse
  { airRecommendations :: [Text]
  , airConfidence :: Double
  } deriving (Show, Eq, Generic)

instance ToJSON AIRecommendationResponse
instance FromJSON AIRecommendationResponse

-- | LLM API client stub (to be implemented)
callLLM :: Text -> IO (Either Text AIDocumentParseResponse)
callLLM _ = pure $ Right $ AIDocumentParseResponse
  { aiprVendor = Nothing
  , aiprInvoiceNumber = Nothing
  , aiprInvoiceDate = Nothing
  , aiprDueDate = Nothing
  , aiprTotalAmount = Nothing
  , aiprLineItems = []
  , aiprRawJson = object []
  }