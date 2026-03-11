-- | Editor module - Text editor
module Core.Editor where

import           Data.Int  (Int64)
import           Data.Text (Text)

-- | EditorDocument - Editor document
data EditorDocument = EditorDocument
  { edId      :: Int64
  , edName    :: Text
  , edContent :: Text
  , edType    :: EditorType
  , edOwnerId :: Int64
  } deriving (Show, Eq)

data EditorType = ET_Text | ET_HTML | ET_Markdown | ET_JSON | ET_XML
  deriving (Show, Eq)

-- | EditorSession - Edit session
data EditorSession = EditorSession
  { esId         :: Int64
  , esDocumentId :: Int64
  , esUserId     :: Int64
  , esCursorPos  :: Int
  , esSelection  :: Maybe (Int, Int)
  } deriving (Show, Eq)
