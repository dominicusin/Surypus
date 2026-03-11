-- | Dialog module - Dialog configuration
module Core.Dialog where

import           Data.Int  (Int64)
import           Data.Text (Text)

-- | Dialog - Dialog configuration
data Dialog = Dialog
  { dlgId         :: Int64
  , dlgObjectType :: Int64
  , dlgName       :: Text
  , dlgLayout     :: Text  -- JSON
  , dlgFlags      :: Int
  } deriving (Show, Eq)

-- | DialogField - Dialog field
data DialogField = DialogField
  { dfId       :: Int64
  , dfDialogId :: Int64
  , dfName     :: Text
  , dfType     :: FieldType
  , dfRequired :: Bool
  , dfDefault  :: Maybe Text
  } deriving (Show, Eq)

data FieldType = FT_String | FT_Int | FT_Double | FT_Date | FT_Bool | FT_Object
  deriving (Show, Eq)
