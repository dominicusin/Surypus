-- | Contact domain type
module CRM.Contact
  ( Contact   (..),
  )
where

import CRM.Types (CompanyId, ContactId)
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time.Calendar (fromGregorian)
import Data.Time.Clock (UTCTime   (..), secondsToDiffTime)
import Test.QuickCheck

data Contact = Contact
  { cId :: ContactId,
    cFirstName :: Text,
    cLastName :: Text,
    cEmail :: Maybe Text,
    cPhone :: Maybe Text,
    cMobilePhone :: Maybe Text,
    cPosition :: Maybe Text,
    cCompanyId :: Maybe CompanyId,
    cPersonId :: Maybe Int64,
    cNotes :: Maybe Text,
    cIsActive :: Bool,
    cCreatedAt :: UTCTime,
    cUpdatedAt :: Maybe UTCTime
  }
  deriving (Show, Eq)

crmEpoch :: UTCTime
crmEpoch = UTCTime (fromGregorian 2024 1 1) (secondsToDiffTime 0)

instance Arbitrary Contact where
  arbitrary = do
    cid <- arbitrary
    firstName <- T.pack <$> suchThat arbitrary (not . null)
    lastName <- T.pack <$> suchThat arbitrary (not . null)
    pure
      Contact
        { cId = cid,
          cFirstName = firstName,
          cLastName = lastName,
          cEmail = Nothing,
          cPhone = Nothing,
          cMobilePhone = Nothing,
          cPosition = Nothing,
          cCompanyId = Nothing,
          cPersonId = Nothing,
          cNotes = Nothing,
          cIsActive = True,
          cCreatedAt = crmEpoch,
          cUpdatedAt = Nothing
        }
