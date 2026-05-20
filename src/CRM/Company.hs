-- | Company domain type
module CRM.Company
  ( Company (..),
  )
where

import CRM.Types (CompanyId)
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time.Calendar (fromGregorian)
import Data.Time.Clock (UTCTime (..), secondsToDiffTime)
import Test.QuickCheck

data Company = Company
  { coId :: CompanyId,
    coName :: Text,
    coPersonId :: Maybe Int64,
    coEmail :: Maybe Text,
    coPhone :: Maybe Text,
    coWebsite :: Maybe Text,
    coIndustry :: Maybe Text,
    coSize :: Maybe Text,
    coAnnualRevenue :: Double,
    coDescription :: Maybe Text,
    coIsActive :: Bool,
    coCreatedAt :: UTCTime,
    coUpdatedAt :: Maybe UTCTime
  }
  deriving (Show, Eq)

crmEpoch :: UTCTime
crmEpoch = UTCTime (fromGregorian 2024 1 1) (secondsToDiffTime 0)

instance Arbitrary Company where
  arbitrary = do
    cid <- arbitrary
    name <- T.pack <$> suchThat arbitrary (not . null)
    pure
      Company
        { coId = cid,
          coName = name,
          coPersonId = Nothing,
          coEmail = Nothing,
          coPhone = Nothing,
          coWebsite = Nothing,
          coIndustry = Nothing,
          coSize = Nothing,
          coAnnualRevenue = 0,
          coDescription = Nothing,
          coIsActive = True,
          coCreatedAt = crmEpoch,
          coUpdatedAt = Nothing
        }
