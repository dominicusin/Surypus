-- | Deal domain type - deals, stages, and stage transitions
module CRM.Deal
  ( Deal   (..),
    DealStage   (..),
    StageTransition   (..),
  )
where

import CRM.Types (ActivityId, CompanyId, ContactId, DealId, PipelineStageId, Priority   (..))
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time.Calendar (Day, fromGregorian)
import Data.Time.Clock (UTCTime   (..), secondsToDiffTime)
import Test.QuickCheck

data Deal = Deal
  { dId :: DealId,
    dName :: Text,
    dValue :: Double,
    dStageId :: PipelineStageId,
    dPersonId :: Maybe Int64,
    dCompanyId :: Maybe CompanyId,
    dContactId :: Maybe ContactId,
    dOwnerId :: Maybe Int64,
    dExpectedCloseDate :: Maybe Day,
    dPriority :: Priority,
    dProbability :: Double,
    dNotes :: Maybe Text,
    dTags :: [Text],
    dIsActive :: Bool,
    dCreatedAt :: UTCTime,
    dUpdatedAt :: Maybe UTCTime
  }
  deriving (Show, Eq)

data DealStage = DealStage
  { dsId :: PipelineStageId,
    dsName :: Text,
    dsOrder :: Int,
    dsProbability :: Double,
    dsColor :: Maybe Text
  }
  deriving (Show, Eq)

data StageTransition = StageTransition
  { stId :: ActivityId,
    stDealId :: DealId,
    stFromStageId :: Maybe PipelineStageId,
    stToStageId :: PipelineStageId,
    stChangedBy :: Maybe Int64,
    stReason :: Maybe Text,
    stChangedAt :: UTCTime
  }
  deriving (Show, Eq)

crmEpoch :: UTCTime
crmEpoch = UTCTime (fromGregorian 2024 1 1) (secondsToDiffTime 0)

instance Arbitrary Deal where
  arbitrary = do
    did <- arbitrary
    name <- suchThat (T.pack <$> arbitrary) (not . T.null)
    value <- suchThat arbitrary (>= 0)
    sid <- arbitrary
    probability <- choose (0, 100)
    pure
      Deal
        { dId = did,
          dName = name,
          dValue = value,
          dStageId = sid,
          dPersonId = Nothing,
          dCompanyId = Nothing,
          dContactId = Nothing,
          dOwnerId = Nothing,
          dExpectedCloseDate = Nothing,
          dPriority = Medium,
          dProbability = probability,
          dNotes = Nothing,
          dTags = [],
          dIsActive = True,
          dCreatedAt = crmEpoch,
          dUpdatedAt = Nothing
        }

instance Arbitrary DealStage where
  arbitrary = do
    sid <- arbitrary
    nm <- T.pack <$> arbitrary
    ord <- choose (1, 6)
    prob <- choose (0, 100)
    pure $ DealStage sid nm ord prob (Just (T.pack "#000000"))

instance Arbitrary StageTransition where
  arbitrary = do
    aid <- arbitrary
    did <- arbitrary
    toId <- arbitrary
    fids <- suchThat (Just <$> arbitrary) (\m -> m /= Just toId)
    cby <- Just <$> arbitrary
    rsn <- Just <$> (T.pack <$> arbitrary)
    pure $ StageTransition aid did fids toId cby rsn crmEpoch
