-- | TagObject module - Object tagging
module Core.TagObject where

import           Data.Int  (Int64)
import           Data.Text (Text)

-- | Tag - Object tag
data Tag = Tag
  { tagId    :: Int64
  , tagName  :: Text
  , tagType  :: TagType
  , tagColor :: Text
  } deriving (Show, Eq)

data TagType = TT_General | TT_Status | TT_Priority | TT_Custom
  deriving (Show, Eq)

-- | TagObject - Tag assignment to object
data TagObject = TagObject
  { toTagId      :: Int64
  , toObjectType :: Int64
  , toObjectId   :: Int64
  } deriving (Show, Eq)
