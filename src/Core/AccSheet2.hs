-- | AccSheet2 module - Extended accounting sheets
module Core.AccSheet2 where

import           Data.Int  (Int64)
import           Data.Text (Text)
import qualified Data.Text as T

-- | AccSheet2 - Extended accounting sheet
data AccSheet2 = AccSheet2
  { as2Id    :: Int64
  , as2Code  :: Text
  , as2Name  :: Text
  , as2Type  :: AccSheetType
  , as2Flags :: Int
  } deriving (Show, Eq)

data AccSheetType = AST_Assets | AST_Liabilities | AST_Income | AST_Expenses
  deriving (Show, Eq)

-- | Get sheet type name
getSheetTypeName :: AccSheet2 -> Text
getSheetTypeName a = case as2Type a of
  AST_Assets      -> T.pack "Assets"
  AST_Liabilities-> T.pack "Liabilities"
  AST_Income      -> T.pack "Income"
  AST_Expenses    -> T.pack "Expenses"
