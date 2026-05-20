-- | Activity domain type - calls, meetings, notes, etc.
module CRM.Activity
  ( Activity (..),
  )
where

import CRM.Types (ActivityId, ActivityType (..), ContactId, DealId)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time.Calendar (fromGregorian)
import Data.Time.Clock (UTCTime (..), secondsToDiffTime)
import Test.QuickCheck

data Activity = Activity
  { aId :: ActivityId,
    aDealId :: Maybe DealId,
    aContactId :: Maybe ContactId,
    aType :: ActivityType,
    aSubject :: Text,
    aDescription :: Maybe Text,
    aDate :: UTCTime,
    aIsCompleted :: Bool,
    aCreatedAt :: UTCTime
  }
  deriving (Show, Eq)

crmEpoch :: UTCTime
crmEpoch = UTCTime (fromGregorian 2024 1 1) (secondsToDiffTime 0)

instance Arbitrary Activity where
  arbitrary = do
    aid <- arbitrary
    subject <- T.pack <$> suchThat arbitrary (not . null)
    pure
      Activity
        { aId = aid,
          aDealId = Nothing,
          aContactId = Nothing,
          aType = Note,
          aSubject = subject,
          aDescription = Nothing,
          aDate = crmEpoch,
          aIsCompleted = False,
          aCreatedAt = crmEpoch
        }
