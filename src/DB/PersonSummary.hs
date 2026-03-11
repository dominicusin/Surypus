{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}

module DB.PersonSummary
  ( PersonSummary(..)
  , listPersonSummary
  ) where

import Data.Int (Int64)
import Hasql.Pool (Pool, use)
import Hasql.Statement (Statement(..))
import qualified Hasql.Encoders as E
import qualified Hasql.Decoders as D
import qualified Hasql.Session as Session
import Domain.Person (PersonSummary(..))

personSummaryRowDecoder :: D.Row PersonSummary
personSummaryRowDecoder =
  PersonSummary
    <$> D.column (D.nonNullable D.int4)
    <*> D.column (D.nonNullable D.int4)
    <*> D.column (D.nonNullable D.int8)
    <*> D.column (D.nonNullable D.numeric)
    <*> D.column (D.nonNullable D.numeric)

listPersonSummary :: Pool -> IO [PersonSummary]
listPersonSummary pool = use pool $ Session.statement () stmt
  where
    stmt = Statement
      "SELECT status, category, total_persons, total_credit_limit, avg_discount FROM get_person_summary()"
      E.noParams
      (D.rowList personSummaryRowDecoder)
      False
