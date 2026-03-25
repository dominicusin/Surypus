{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}

module Domain.TechCard
  ( TechCardInput (..),
    TechLineInput (..),
    validateTechCardInput,
    validateTechLineInput,
  )
where

import Data.Aeson (FromJSON, ToJSON)
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import GHC.Generics (Generic)

data TechLineInput = TechLineInput
  { tliLineNo :: Maybe Int,
    tliGoodsId :: Int64,
    tliQtty :: Double,
    tliSign :: Int,
    tliLineTime :: Maybe Double,
    tliLineCost :: Maybe Double
  }
  deriving (Eq, Show, Generic)

instance ToJSON TechLineInput

instance FromJSON TechLineInput

data TechCardInput = TechCardInput
  { tciProcessorId :: Int64,
    tciGoodsGroupId :: Int64,
    tciKind :: Int,
    tciFormula :: Maybe Text,
    tciLines :: [TechLineInput]
  }
  deriving (Eq, Show, Generic)

instance ToJSON TechCardInput

instance FromJSON TechCardInput

validateTechLineInput :: TechLineInput -> Either Text TechLineInput
validateTechLineInput line@TechLineInput {..}
  | maybe False (<= 0) tliLineNo = Left "line number must be positive"
  | tliGoodsId <= 0 = Left "goods id must be positive"
  | tliQtty < 0 = Left "line quantity must be non-negative"
  | tliSign < -1 || tliSign > 1 = Left "line sign must be -1/0/1"
  | maybe False (< 0) tliLineTime = Left "line time must be non-negative"
  | maybe False (< 0) tliLineCost = Left "line cost must be non-negative"
  | otherwise = Right line

validateTechCardInput :: TechCardInput -> Either Text TechCardInput
validateTechCardInput card@TechCardInput {..}
  | tciProcessorId <= 0 = Left "processor id must be positive"
  | tciGoodsGroupId <= 0 = Left "goods group must be positive"
  | tciKind < 0 || tciKind > 1 = Left "kind must be 0 (manual) or 1 (auto)"
  | otherwise =
      case traverse validateTechLineInput tciLines of
        Left err -> Left err
        Right _ -> Right card
