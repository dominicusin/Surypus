-- | Backup module - Database backup
module Core.Backup where

import           Data.Int  (Int64)
import           Data.Text (Text)
import qualified Data.Text as Data.Text
import           Data.Time (UTCTime)

-- | Backup - Database backup
data Backup = Backup
  { bkId      :: Int64
  , bkCode    :: Text
  , bkPath    :: Text
  , bkSize    :: Int64
  , bkType    :: BackupType
  , bkStatus  :: BackupStatus
  , bkCreated :: UTCTime
  , bkFlags   :: Int
  } deriving (Show, Eq)

data BackupType = BT_Full | BT_Incremental | BT_Config
  deriving (Show, Eq)

data BackupStatus = BS_Pending | BS_InProgress | BS_Completed | BS_Failed
  deriving (Show, Eq)

-- | Backup settings
data BackupSettings = BackupSettings
  { bsPath          :: Text
  , bsRetentionDays :: Int
  , bsSchedule      :: Text  -- cron
  , bsCompress      :: Bool
  , bsEncrypt       :: Bool
  } deriving (Show, Eq)

-- | Validate backup path
validateBackupPath :: Backup -> Bool
validateBackupPath b = not (Data.Text.null (bkPath b))
