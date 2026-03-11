{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}

module Domain.Stock
  ( Stock(..)
  , StockFilter(..)
  , availableStock
  , canReserveStock
  , normalizeStock
  , validateStock
  ) where

import Data.Aeson (FromJSON, ToJSON)
import Data.Int (Int64)
import Data.Text (Text)
import GHC.Generics (Generic)

import Core.Refined (clampNonNeg)

{-@ type NonNegDouble = {v:Double | v >= 0} @-}

{-@ data Stock = Stock
  { stockId        :: Maybe Int64
  , stockGoodsId   :: Int64
  , stockLocationId:: Int64
  , stockQuantity  :: NonNegDouble
  , stockReserved  :: NonNegDouble
  , stockCost      :: NonNegDouble
  , stockPrice     :: NonNegDouble
  , stockBatch     :: Maybe Text
  } @-}
data Stock = Stock
  { stockId        :: Maybe Int64
  , stockGoodsId   :: Int64
  , stockLocationId:: Int64
  , stockQuantity  :: Double
  , stockReserved  :: Double
  , stockCost      :: Double
  , stockPrice     :: Double
  , stockBatch     :: Maybe Text
  } deriving (Eq, Show, Generic)

instance FromJSON Stock
instance ToJSON Stock

{-@ data StockFilter = StockFilter
  { sfGoodsId    :: Maybe Int64
  , sfLocationId :: Maybe Int64
  } @-}
data StockFilter = StockFilter
  { sfGoodsId    :: Maybe Int64
  , sfLocationId :: Maybe Int64
  } deriving (Eq, Show, Generic)

instance FromJSON StockFilter
instance ToJSON StockFilter

availableStock :: Stock -> Double
availableStock Stock{..} = clampNonNeg (stockQuantity - stockReserved)

canReserveStock :: Stock -> Double -> Bool
canReserveStock stock qty = qty > 0 && availableStock stock >= qty

normalizeStock :: Stock -> Stock
normalizeStock stock@Stock{..} =
  stock { stockQuantity = clampNonNeg stockQuantity
        , stockReserved = clampNonNeg stockReserved
        , stockCost = clampNonNeg stockCost
        , stockPrice = clampNonNeg stockPrice
        }

validateStock :: Stock -> Either Text Stock
validateStock stock@Stock{..}
  | stockQuantity < 0 = Left \"stock quantity cannot be negative\"
  | stockReserved < 0 = Left \"reserved quantity cannot be negative\"
  | stockReserved > stockQuantity = Left \"reserved quantity exceeds stock on hand\"
  | otherwise = Right (normalizeStock stock)
