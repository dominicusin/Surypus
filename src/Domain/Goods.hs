{-# LANGUAGE DeriveGeneric #-}

module Domain.Goods
  ( Goods (..),
    GoodsFilter (..),
  )
where

import Data.Aeson (FromJSON, ToJSON)
import Data.Int (Int64)
import Data.Text (Text)
import GHC.Generics (Generic)

data Goods = Goods
  { goodsId :: Maybe Int64,
    goodsCode :: Maybe Text,
    goodsName :: Text,
    goodsBarcode :: Maybe Text,
    goodsUnitId :: Int64,
    goodsParent :: Maybe Int64,
    goodsType :: Int,
    goodsTaxId :: Maybe Int64,
    goodsBrandId :: Maybe Int64,
    goodsStatus :: Int,
    goodsMinStock :: Double,
    goodsMaxStock :: Maybe Double,
    goodsWeight :: Maybe Double,
    goodsVolume :: Maybe Double
  }
  deriving (Eq, Show, Generic)

instance FromJSON Goods

instance ToJSON Goods

data GoodsFilter = GoodsFilter
  { gfName :: Maybe Text,
    gfBarcode :: Maybe Text,
    gfType :: Maybe Int,
    gfBrand :: Maybe Int64
  }
  deriving (Eq, Show, Generic)

instance FromJSON GoodsFilter

instance ToJSON GoodsFilter
