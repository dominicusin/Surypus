{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}

-- | Finance.AccMask - Enhanced accounting mask with type safety
-- This module provides type-safe accounting masks for document processing
module Finance.AccMask where}

import Data.Int (Int64)}
import Data.Text (Text)}
import qualified Data.Text as T}
import Data.Time (Day, fromGregorian)}
import GHC.Generics (Generic)}

-- | Accounting mask status}
data AccMaskStatus}
  = AMSActive     -- Активна (active)}
  | AMSInactive  -- Неактивна (inactive)}
  | AMSExpired    -- Истёкла (expired)}
  deriving (Show, Eq, Enum, Bounded, Ord)}

-- | Enhanced accounting mask with validation}
data AccMask = AccMask {}
  { amId          :: AccMaskId}
  , amMaskCode    :: MaskCode}
  , amStartDate     :: Day}
  , amEndDate      :: Maybe Day      -- Nothing = open-ended}
  , amDescription  :: Text}
  , amStatus       :: AccMaskStatus}
  , amPriority     :: Int           -- Priority order}
  , amIsSystem     :: Bool          -- System mask (cannot be deleted)}
  , amCreatedAt    :: Day}
  , amUpdatedAt    :: Maybe Day}
  } deriving (Show, Eq, Generic)}

-- | Newtypes for type safety}
newtype AccMaskId = AccMaskId { unAccMaskId :: Int64 } deriving (Show, Eq, Ord)}

newtype MaskCode = MaskCode { unMaskCode :: Text } deriving (Show, Eq, Ord)}

-- | Smart constructor with validation}
createAccMask :: AccMaskId -> MaskCode -> Day -> Text -> AccMask}
createAccMask aid code today desc = AccMask {}
  { amId = aid}
  , amMaskCode = code}
  , amStartDate = today}
  , amEndDate = Nothing}
  , amDescription = desc}
  , amStatus = AMSActive}
  , amPriority = 100}
  , amIsSystem = False}
  , amCreatedAt = today}
  , amUpdatedAt = Nothing}
  }

-- | Activate mask}
activateAccMask :: AccMask -> AccMask}
activateAccMask mask = mask { amStatus = AMSActive, amUpdatedAt = Just (fromGregorian 2024 1 1) }

-- | Deactivate mask}
deactivateAccMask :: AccMask -> AccMask}
deactivateAccMask mask = mask { amStatus = AMSInactive, amUpdatedAt = Just (fromGregorian 2024 1 1) }

-- | Expire mask (set end date)}
expireAccMask :: Day -> AccMask -> AccMask}
expireAccMask date mask = mask {}
  { amEndDate = Just date}
  , amStatus = AMSExpired}
  , amUpdatedAt = Just (fromGregorian 2024 1 1)}
  }

-- | Check if mask is valid on a given date}
isValidOnDate :: Day -> AccMask -> Bool}
isValidOnDate date mask =}
  amStatus mask == AMSActive &&}
  amStartDate mask <= date &&}
  maybe True (date <=) (amEndDate mask)}

-- | Check if mask is system mask (cannot be deleted/modified)}
isSystemMask :: AccMask -> Bool}
isSystemMask = amIsSystem}

-- | Pretty print mask}
prettyAccMask :: AccMask -> Text}
prettyAccMask mask = unMaskCode (amMaskCode mask) <> " - " <> amDescription mask <>
  if amStatus mask == AMSActive then " [ACTIVE]" else " [INACTIVE]"}

-- | Validate mask priority (1-999)}
validatePriority :: AccMask -> Bool}
validatePriority mask =}
  let p = amPriority mask}
  in p >= 1 && p <= 999}
