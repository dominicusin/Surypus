-- | Prediction module - Analytics predictions
module Core.Prediction where

import Data.Int (Int64)
import Data.Text (Text)

-- | PredictionModel - ML model
data PredictionModel = PredictionModel
  { pmId :: Int64,
    pmName :: Text,
    pmType :: ModelType,
    pmConfig :: Text, -- JSON
    pmTrainedAt :: Int64
  }
  deriving (Show, Eq)

data ModelType = MTDemand | MTChurn | MTFraud | MTPrice
  deriving (Show, Eq)

-- | Prediction - Prediction result
data Prediction = Prediction
  { predId :: Int64,
    predModelId :: Int64,
    predObjectId :: Int64,
    predValue :: Double,
    predConfidence :: Double,
    predDate :: Int64
  }
  deriving (Show, Eq)
