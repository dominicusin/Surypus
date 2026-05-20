-- | Pipeline and forecasting types
module CRM.Pipeline
  ( PipelineStage (..),
    Forecast (..),
    StageRule (..),
  )
where

import Data.Aeson (Value, object)
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Data.UUID (UUID)
import Test.QuickCheck
import CRM.Types (PipelineStageId, arbUUID)

data PipelineStage = PipelineStage
  { psId :: PipelineStageId,
    psName :: Text,
    psOrder :: Int,
    psProbability :: Double,
    psColor :: Maybe Text,
    psIsActive :: Bool,
    psEntryCriteria :: [StageRule],
    psExitCriteria :: [StageRule]
  }
  deriving (Show, Eq)

data Forecast = Forecast
  { fStage :: Text,
    fStageOrder :: Int,
    fProbability :: Double,
    fDealCount :: Int64,
    fPipelineValue :: Double,
    fWeightedForecast :: Double
  }
  deriving (Show, Eq)

data StageRule = StageRule
  { srId :: UUID,
    srStageId :: PipelineStageId,
    srRuleType :: Text,
    srCriteriaType :: Text,
    srCriteriaConfig :: Value
  }
  deriving (Show, Eq)

instance Arbitrary PipelineStage where
  arbitrary = do
    pid <- arbitrary
    psName <- T.pack <$> suchThat arbitrary (not . null)
    ord <- choose (1, 10)
    prob <- choose (0, 100)
    pure $ PipelineStage pid psName ord prob (Just (T.pack "#000000")) True [] []

instance Arbitrary Forecast where
  arbitrary = do
    fgStage <- T.pack <$> arbitrary
    ord <- choose (1, 6)
    prob <- choose (0, 100)
    dealCount <- choose (0, 100)
    pipeValue <- suchThat arbitrary (>= 0)
    pure
      Forecast
        { fStage = fgStage,
          fStageOrder = ord,
          fProbability = prob,
          fDealCount = dealCount,
          fPipelineValue = pipeValue,
          fWeightedForecast = pipeValue * prob / 100
        }

instance Arbitrary StageRule where
  arbitrary = do
    suid <- arbUUID
    psid <- arbitrary
    rtype <- elements [T.pack "entry", T.pack "exit"]
    ctype <- elements [T.pack "min_deal_value", T.pack "required_field", T.pack "document_uploaded"]
    pure $ StageRule suid psid rtype ctype (object [])
