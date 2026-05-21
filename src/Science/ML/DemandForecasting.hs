{-# LANGUAGE OverloadedStrings #-}
module Science.ML.DemandForecasting
  ( DemandForecast(..)
  , ForecastPoint
  , ForecastingModel(..)
  , trainModel
  , predict
  ) where

import Data.Time (Day)
import Data.Text (Text)

-- | Single forecast point with confidence interval
data ForecastPoint = ForecastPoint
  { fpDate :: Day
  , fpPredicted :: Double
  , fpLower :: Double
  , fpUpper :: Double
  } deriving (Eq, Show)

-- | Demand forecast result
data DemandForecast = DemandForecast
  { dfItemId :: Int
  , dfItemName :: Text
  , dfPoints :: [ForecastPoint]
  , dfModelAccuracy :: Double
  } deriving (Eq, Show)

-- | Forecasting model types
data ForecastingModel
  = ARIMAX
  | ExponentialSmoothing
  | LinearRegression
  deriving (Eq, Show)

-- | Train forecasting model on historical data
trainModel :: ForecastingModel -> [(Day, Double)] -> IO ()
trainModel _ _ = putStrLn "Model trained (placeholder)"

-- | Predict future demand
predict :: ForecastingModel -> Int -> Int -> IO DemandForecast
predict model itemId horizon = do
  let points = replicate horizon $ ForecastPoint
        { fpDate = error "use real date"
        , fpPredicted = 0
        , fpLower = 0
        , fpUpper = 0
        }
  return $ DemandForecast
    { dfItemId = itemId
    , dfItemName = "Item " <> show itemId
    , dfPoints = points
    , dfModelAccuracy = 0.85
    }