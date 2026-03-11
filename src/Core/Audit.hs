-- | Audit module - Audit trail
module Core.Audit where

import           Data.Int  (Int64)
import           Data.Text (Text)
import           Data.Time (UTCTime)

-- | AuditRecord - Audit record
data AuditRecord = AuditRecord
  { arId         :: Int64
  , arUserId     :: Int64
  , arAction     :: AuditAction
  , arObjectType :: Int64
  , arObjectId   :: Int64
  , arOldValue   :: Maybe Text
  , arNewValue   :: Maybe Text
  , arTimestamp  :: UTCTime
  } deriving (Show, Eq)

data AuditAction = AA_Create | AA_Update | AA_Delete | AA_View | AA_Execute
  deriving (Show, Eq)
