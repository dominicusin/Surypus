-- | Shared CRM types - newtype wrappers and enumerations
module CRM.Types
  ( ContactId (..),
    CompanyId (..),
    DealId (..),
    ActivityId (..),
    PipelineStageId (..),
    Priority (..),
    ActivityType (..),
    arbUUID,
  )
where

import Data.UUID (UUID, fromWords)
import Test.QuickCheck

newtype ContactId = ContactId UUID
  deriving (Show, Eq, Ord)

newtype CompanyId = CompanyId UUID
  deriving (Show, Eq, Ord)

newtype DealId = DealId UUID
  deriving (Show, Eq, Ord)

newtype ActivityId = ActivityId UUID
  deriving (Show, Eq, Ord)

newtype PipelineStageId = PipelineStageId UUID
  deriving (Show, Eq, Ord)

data Priority
  = Low
  | Medium
  | High
  | Urgent
  deriving (Show, Eq, Ord, Enum, Bounded)

data ActivityType
  = Call
  | Meeting
  | Email
  | Note
  | Task
  | Lunch
  deriving (Show, Eq, Enum, Bounded)

arbUUID :: Gen UUID
arbUUID = fromWords <$> arbitrary <*> arbitrary <*> arbitrary <*> arbitrary

instance Arbitrary ContactId where
  arbitrary = ContactId <$> arbUUID

instance Arbitrary CompanyId where
  arbitrary = CompanyId <$> arbUUID

instance Arbitrary DealId where
  arbitrary = DealId <$> arbUUID

instance Arbitrary ActivityId where
  arbitrary = ActivityId <$> arbUUID

instance Arbitrary PipelineStageId where
  arbitrary = PipelineStageId <$> arbUUID

instance Arbitrary Priority where
  arbitrary = elements [Low, Medium, High, Urgent]

instance Arbitrary ActivityType where
  arbitrary = elements [Call, Meeting, Email, Note, Task, Lunch]
