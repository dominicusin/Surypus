-- | Contact module - Contact information
module Core.Contact where

import           Data.Int  (Int64)
import           Data.Text (Text)
import qualified Data.Text as Data.Text

-- | Contact - Contact info
data Contact = Contact
  { conId       :: Int64
  , conPersonId :: Int64
  , conType     :: ContactType
  , conValue    :: Text
  , conPrimary  :: Bool
  } deriving (Show, Eq)

data ContactType = CT_Phone | CT_Email | CT_Address | CT_URL
  deriving (Show, Eq)

-- | Validate contact
validateContact :: Contact -> Bool
validateContact c = not (Data.Text.null (conValue c))
