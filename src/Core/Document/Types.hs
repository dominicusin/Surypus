{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}

-- |
-- Module      : Core.Document.Types
-- Description : Domain types for document registers, counters and validation invariants
module Core.Document.Types
  ( DocumentRegister (..),
    DocumentRegisterType (..),
    DocumentRegisterFlag (..),
    DocumentOpCounter (..),
    DocumentRegisterStatus (..),
    validateDocumentRegister,
    validateDocumentRegisterType,
    validateDocumentOpCounter,
    documentRegisterTypeAllowsDuplicateNumbers,
    documentRegisterTypeForLocation,
    documentRegisterTypeInsertOnCreate,
    documentRegisterTypeOnlyNumber,
    documentRegisterTypeRequiresUnique,
    documentRegisterTypeWarnsAbsence,
    documentRegisterTypeWarnsExpiry,
    documentRegisterTypeHasFlag,
  )
where

import Data.Aeson (FromJSON, ToJSON)
import Data.Bits ((.&.))
import Data.Int (Int64)
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (Day)
import GHC.Generics (Generic)

{-@ type NonEmptyText = {v:Text | v /= \"\"} @-}
{-@ type SmallFlags = {v:Int | v >= 0 && v <= 4294967295} @-}

{-@ data DocumentRegister = DocumentRegister
  { drId         :: Maybe Int64
  , drPersonId   :: Int64
  , drTypeId     :: Int64
  , drSeries     :: Maybe Text
  , drNumber     :: NonEmptyText
  , drIssueDate  :: Day
  , drExpiryDate :: Maybe Day
  , drIssuer     :: Maybe Text
  , drFlags      :: SmallFlags
  , drAutoNumber :: Maybe Bool
  } @-}
data DocumentRegister = DocumentRegister
  { drId :: Maybe Int64,
    drPersonId :: Int64,
    drTypeId :: Int64,
    drSeries :: Maybe Text,
    drNumber :: Text,
    drIssueDate :: Day,
    drExpiryDate :: Maybe Day,
    drIssuer :: Maybe Text,
    drFlags :: Int,
    drAutoNumber :: Maybe Bool
  }
  deriving (Eq, Show, Generic)

instance FromJSON DocumentRegister

instance ToJSON DocumentRegister

{-@ data DocumentRegisterType = DocumentRegisterType
  { drtId    :: Maybe Int64
  , drtName  :: NonEmptyText
  , drtCode  :: Maybe Text
  , drtFlags :: SmallFlags
  } @-}
data DocumentRegisterType = DocumentRegisterType
  { drtId :: Maybe Int64,
    drtName :: Text,
    drtCode :: Maybe Text,
    drtFlags :: Int
  }
  deriving (Eq, Show, Generic)

instance FromJSON DocumentRegisterType

instance ToJSON DocumentRegisterType

{-@ data DocumentRegisterFlag = DocumentRegisterFlag @-}
data DocumentRegisterFlag
  = DocFlagUnique
  | DocFlagPrivate
  | DocFlagLegal
  | DocFlagWarnExpiry
  | DocFlagInsert
  | DocFlagWarnAbsence
  | DocFlagDuplicateNumber
  | DocFlagOnlyNumber
  | DocFlagLocation
  deriving (Eq, Show)

{-@ reflect documentRegisterFlagMask @-}
documentRegisterFlagMask :: DocumentRegisterFlag -> Int
documentRegisterFlagMask flag =
  case flag of
    DocFlagUnique -> 0x0001
    DocFlagPrivate -> 0x0002
    DocFlagLegal -> 0x0004
    DocFlagWarnExpiry -> 0x0008
    DocFlagInsert -> 0x0010
    DocFlagWarnAbsence -> 0x0020
    DocFlagDuplicateNumber -> 0x0040
    DocFlagOnlyNumber -> 0x0080
    DocFlagLocation -> 0x0100

{-@ reflect documentRegisterTypeHasFlag @-}
documentRegisterTypeHasFlag :: DocumentRegisterType -> DocumentRegisterFlag -> Bool
documentRegisterTypeHasFlag DocumentRegisterType {..} flag =
  (drtFlags .&. documentRegisterFlagMask flag) /= 0

documentRegisterTypeRequiresUnique :: DocumentRegisterType -> Bool
documentRegisterTypeRequiresUnique = flip documentRegisterTypeHasFlag DocFlagUnique

documentRegisterTypeAllowsDuplicateNumbers :: DocumentRegisterType -> Bool
documentRegisterTypeAllowsDuplicateNumbers = flip documentRegisterTypeHasFlag DocFlagDuplicateNumber

documentRegisterTypeOnlyNumber :: DocumentRegisterType -> Bool
documentRegisterTypeOnlyNumber = flip documentRegisterTypeHasFlag DocFlagOnlyNumber

documentRegisterTypeForLocation :: DocumentRegisterType -> Bool
documentRegisterTypeForLocation = flip documentRegisterTypeHasFlag DocFlagLocation

documentRegisterTypeWarnsExpiry :: DocumentRegisterType -> Bool
documentRegisterTypeWarnsExpiry = flip documentRegisterTypeHasFlag DocFlagWarnExpiry

documentRegisterTypeWarnsAbsence :: DocumentRegisterType -> Bool
documentRegisterTypeWarnsAbsence = flip documentRegisterTypeHasFlag DocFlagWarnAbsence

documentRegisterTypeInsertOnCreate :: DocumentRegisterType -> Bool
documentRegisterTypeInsertOnCreate = flip documentRegisterTypeHasFlag DocFlagInsert

{-@ validateDocumentRegisterType :: DocumentRegisterType -> Either Text DocumentRegisterType @-}
validateDocumentRegisterType :: DocumentRegisterType -> Either Text DocumentRegisterType
validateDocumentRegisterType drt@DocumentRegisterType {..}
  | T.null drtName =
      Left "register type name must not be empty"
  | Just code <- drtCode,
    T.length code > 32 =
      Left "register type code may contain at most 32 characters"
  | otherwise =
      Right drt

{-@ data DocumentOpCounter = DocumentOpCounter
  { docCounterId    :: Maybe Int64
  , docCounterName  :: NonEmptyText
  , docCounterOpKindId :: Int
  , docCounterPrefix    :: Maybe Text
  , docCounterFlags :: SmallFlags
  } @-}
data DocumentOpCounter = DocumentOpCounter
  { docCounterId :: Maybe Int64,
    docCounterName :: Text,
    docCounterOpKindId :: Int,
    docCounterPrefix :: Maybe Text,
    docCounterFlags :: Int
  }
  deriving (Eq, Show, Generic)

instance FromJSON DocumentOpCounter

instance ToJSON DocumentOpCounter

data DocumentRegisterStatus
  = DocumentStatusActive
  | DocumentStatusExpired
  | DocumentStatusUnlimited
  deriving (Eq, Show)

{-@ validateDocumentRegister :: DocumentRegister -> Either Text DocumentRegister @-}
validateDocumentRegister :: DocumentRegister -> Either Text DocumentRegister
validateDocumentRegister dr@DocumentRegister {..}
  | not (fromMaybe False drAutoNumber) && T.null drNumber =
      Left "register number must not be empty"
  | Just expiry <- drExpiryDate,
    expiry < drIssueDate =
      Left "expiry must not precede issue date"
  | otherwise =
      Right dr

{-@ validateDocumentOpCounter :: DocumentOpCounter -> Either Text DocumentOpCounter @-}
validateDocumentOpCounter :: DocumentOpCounter -> Either Text DocumentOpCounter
validateDocumentOpCounter doc@DocumentOpCounter {..}
  | T.length (fromMaybe T.empty docCounterPrefix) > 16 =
      Left "counter prefix may contain at most 16 characters"
  | otherwise =
      Right doc
