{-# LANGUAGE OverloadedStrings #-}

module DB.PersonSnapshot
  ( runPersonSummarySnapshot,
    listPersonSummarySnapshots,
  )
where

import Data.Int (Int64)
import Data.Text (Text)
import Data.Time.Clock (UTCTime)
import Data.UUID (UUID)
import Domain.Person (PersonSnapshot (..))
import qualified Hasql.Decoders as D
import qualified Hasql.Encoders as E
import Hasql.Pool (Pool, use)
import qualified Hasql.Session as Session
import Hasql.Statement (unpreparable)

snapshotRow :: D.Row PersonSnapshot
snapshotRow =
  PersonSnapshot
    <$> D.column (D.nonNullable D.int8)
    <*> D.column (D.nonNullable D.uuid)
    <*> D.column (D.nonNullable D.timestamptz)
    <*> (fromIntegral <$> D.column (D.nonNullable D.int4))
    <*> (fromIntegral <$> D.column (D.nonNullable D.int4))
    <*> D.column (D.nonNullable D.int8)
    <*> D.column (D.nonNullable D.numeric)
    <*> D.column (D.nonNullable D.numeric)

listPersonSummarySnapshots :: Pool -> IO [PersonSnapshot]
listPersonSummarySnapshots pool = do
  result <- use pool $ Session.statement () stmt
  case result of
    Right x -> pure x
    Left _ -> pure []
  where
    stmt =
      unpreparable
        "SELECT id, run_id, run_at, status, category, total_persons, total_credit_limit, avg_discount FROM person_summary_snapshot ORDER BY run_at DESC LIMIT 20"
        E.noParams
        (D.rowList snapshotRow)

runPersonSummarySnapshot :: Pool -> IO (Maybe (UUID, UTCTime))
runPersonSummarySnapshot pool = do
  result <- use pool $ Session.statement () stmt
  case result of
    Right x -> pure x
    Left _ -> pure Nothing
  where
    stmt =
      unpreparable
        "SELECT run_id, run_at FROM run_person_summary_snapshot()"
        E.noParams
        (D.rowMaybe $ (,) <$> D.column (D.nonNullable D.uuid) <*> D.column (D.nonNullable D.timestamptz))
