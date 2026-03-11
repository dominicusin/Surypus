{-# LANGUAGE OverloadedStrings #-}

module DB.PersonSnapshot
  ( runPersonSummarySnapshot
  , listPersonSummarySnapshots
  ) where

import Data.Int (Int64)
import Data.Text (Text)
import Data.Time.Clock (UTCTime)
import Data.UUID (UUID)
import Hasql.Pool (Pool, use)
import Hasql.Statement (Statement(..))
import qualified Hasql.Decoders as D
import qualified Hasql.Encoders as E
import qualified Hasql.Session as Session
import Domain.Person (PersonSnapshot(..))

snapshotRow :: D.Row PersonSnapshot
snapshotRow =
  PersonSnapshot
    <$> D.column (D.nonNullable D.int8)
    <*> D.column (D.nonNullable D.uuid)
    <*> D.column (D.nonNullable D.timestamptz)
    <*> D.column (D.nonNullable D.int4)
    <*> D.column (D.nonNullable D.int4)
    <*> D.column (D.nonNullable D.int8)
    <*> D.column (D.nonNullable D.numeric)
    <*> D.column (D.nonNullable D.numeric)

listPersonSummarySnapshots :: Pool -> IO [PersonSnapshot]
listPersonSummarySnapshots pool = use pool $ Session.statement () stmt
  where
    stmt = Statement
      "SELECT id, run_id, run_at, status, category, total_persons, total_credit_limit, avg_discount FROM person_summary_snapshot ORDER BY run_at DESC LIMIT 20"
      E.noParams
      (D.rowList snapshotRow)
      False

runPersonSummarySnapshot :: Pool -> IO (Maybe (UUID, UTCTime))
runPersonSummarySnapshot pool = use pool $ Session.statement () stmt
  where
    stmt = Statement
      "SELECT run_id, run_at FROM run_person_summary_snapshot()"
      E.noParams
      (D.rowMaybe $ (,) <$> D.column (D.nonNullable D.uuid) <*> D.column (D.nonNullable D.timestamptz))
      False
