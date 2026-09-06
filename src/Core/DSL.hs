-- | Core DSL (Phase 1: stub)
module Core.DSL
  ( DSLExpr(..)
  , parseDSL
  ) where

import Data.Text (Text)

-- | DSL expression
data DSLExpr
  = DSLSelect !Text
  | DSLInsert !Text
  | DSLUpdate !Text
  deriving (Show, Eq)

-- | Parse DSL expression (stub)
parseDSL :: Text -> Maybe DSLExpr
parseDSL _ = Nothing
