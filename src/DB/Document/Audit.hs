{-# LANGUAGE OverloadedStrings #-}

module DB.Document.Audit
  ( findExpiringRegisters
  , findDuplicateRegisterNumbers
  , DocumentRegisterDuplicate(..)
  ) where

import Core.Document.Types (DocumentRegister(..))
import Data.Int (Int64)
import Data.Text (Text)
import GHC.Generics (Generic)
import Hasql.Pool (Pool, use)
import Hasql.Statement (Statement(..))
import qualified Hasql.Decoders as D
import qualified Hasql.Encoders as E
import qualified Hasql.Session as Session
import Data.Aeson (ToJSON)
import DB.Document.RegisterRow (documentRegisterRow)

data DocumentRegisterDuplicate = DocumentRegisterDuplicate
  { drdTypeId :: Int64
  , drdNumber :: Text
  , drdCount  :: Int
  } deriving (Eq, Show, Generic)

instance ToJSON DocumentRegisterDuplicate

findExpiringRegisters :: Pool -> Int -> IO [DocumentRegister]
findExpiringRegisters pool lookaheadDays = use pool $
  Session.statement lookaheadDays stmt
  where
    stmt = Statement
      "SELECT id, person_id, type_id, series, number, issue_date, expiry_date, issuer, flags, auto_number \
      \FROM document_register \
      \WHERE expiry_date IS NOT NULL \
        \AND expiry_date <= CURRENT_DATE + ($1::int * INTERVAL '1 day') \
      \ORDER BY expiry_date ASC"
      (E.param (E.nonNullable E.int4))
      (D.rowList documentRegisterRow)
      False

findDuplicateRegisterNumbers :: Pool -> IO [DocumentRegisterDuplicate]
findDuplicateRegisterNumbers pool = use pool $
  Session.statement () stmt
  where
    stmt = Statement
      "SELECT type_id, number, COUNT(*) AS total \
      \FROM document_register \
      \GROUP BY type_id, number \
      \HAVING COUNT(*) > 1 \
      \ORDER BY type_id, number"
      E.noParams
      (D.rowList duplicateRow)
      False

duplicateRow :: D.Row DocumentRegisterDuplicate
duplicateRow =
  DocumentRegisterDuplicate
    <$> D.column (D.nonNullable D.int8)
    <*> D.column (D.nonNullable D.text)
    <*> D.column (D.nonNullable D.int4)
