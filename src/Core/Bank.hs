-- | Bank module - Banks
module Core.Bank where

import           Data.Int  (Int64)
import           Data.Text (Text)
import qualified Data.Text as T

-- | Bank - Bank
data Bank = Bank
  { bnkId   :: Int64
  , bnkCode :: Text
  , bnkName :: Text
  , bnkBIC  :: Text
  , bnkINN  :: Text
  } deriving (Show, Eq)

-- | Validate BIC
validateBIC :: Bank -> Bool
validateBIC b = T.length (bnkBIC b) == 9
