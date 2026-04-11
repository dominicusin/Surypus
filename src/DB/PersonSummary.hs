{-# LANGUAGE OverloadedStrings #-}

module DB.PersonSummary
  ( PersonSummary (..),
    listPersonSummary,
  )
where

import Data.Int (Int64)
import Domain.Person (PersonSummary (..))
import qualified Hasql.Decoders as D
import qualified Hasql.Encoders as E
import Hasql.Pool (Pool, use)
import qualified Hasql.Session as Session
import Hasql.Statement (Statement)

personSummaryRowDecoder :: D.Row PersonSummary
personSummaryRowDecoder =
  (PersonSummary . fromIntegral <$> D.column (D.nonNullable D.int4))
    <*> (fromIntegral <$> D.column (D.nonNullable D.int4))
    <*> D.column (D.nonNullable D.int8)
    <*> D.column (D.nonNullable D.numeric)
    <*> D.column (D.nonNullable D.numeric)

listPersonSummary :: Pool -> IO [PersonSummary]
listPersonSummary pool = do
  result <- use pool $ Session.statement () stmt
  case result of
    Right x -> pure x
    Left _ -> pure []
  where
    stmt =
      Statement
        "SELECT status, category, total_persons, total_credit_limit, avg_discount FROM get_person_summary()"
        E.noParams
        (D.rowList personSummaryRowDecoder)
