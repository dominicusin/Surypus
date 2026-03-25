{-# LANGUAGE DeriveGeneric #-}

-- | Production module - Manufacturing
module Core.Production where

import Data.Aeson (FromJSON, ToJSON)
import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (Day)
import GHC.Generics (Generic)

-- | Tech - Technology (recipe)
data Tech = Tech
  { techId :: Int64,
    techName :: Text,
    techParentId :: Maybe Int64,
    techGoodsId :: Int64, -- Output product
    techKind :: Int,
    techVersion :: Int,
    techFlags :: Int
  }
  deriving (Show, Eq, Generic)

instance ToJSON Tech

instance FromJSON Tech

-- | TechLine - Technology line (ingredient)
data TechLine = TechLine
  { tlId :: Int64,
    tlTechId :: Int64,
    tlGoodsId :: Int64, -- Input material
    tlQtty :: Double,
    tlFlags :: Int
  }
  deriving (Show, Eq, Generic)

instance ToJSON TechLine

instance FromJSON TechLine

-- | Processor - Processing line
data Processor = Processor
  { procId :: Int64,
    procCode :: Text,
    procName :: Int64,
    procFlags :: Int
  }
  deriving (Show, Eq, Generic)

instance ToJSON Processor

instance FromJSON Processor

-- | TSession - Processing session
data TSession = TSession
  { tsId :: Int64,
    tsProcessorId :: Int64,
    tsTechId :: Int64,
    tsStartTime :: Day,
    tsEndTime :: Maybe Day,
    tsOutputQtty :: Double,
    tsFlags :: Int
  }
  deriving (Show, Eq, Generic)

instance ToJSON TSession

instance FromJSON TSession

-- | Calculate material consumption
calcMaterialConsumption :: Tech -> [(Int64, Double)] -> Double
calcMaterialConsumption tech materials =
  sum (fmap snd materials)
