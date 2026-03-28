{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module DB.Document.Audit
  ( findExpiringRegisters,
    findDuplicateRegisterNumbers,
    DocumentRegisterDuplicate (..),
  )
where

import Core.Document.Types (DocumentRegister (..))
import DB.Document.RegisterRow (documentRegisterRow)
import Data.Aeson (ToJSON)
import Data.Int (Int32, Int64)
import Data.Text (Text)
import GHC.Generics (Generic)
import qualified Hasql.Decoders as D
import qualified Hasql.Encoders as E
import Hasql.Pool (Pool, use)
import qualified Hasql.Session as Session
import Hasql.Statement (Statement)

data DocumentRegisterDuplicate = DocumentRegisterDuplicate
  { drdTypeId :: Int64,
    drdNumber :: Text,
    drdCount :: Int64
  }
  deriving (Eq, Show, Generic)

instance ToJSON DocumentRegisterDuplicate

findExpiringRegisters :: Pool -> Int32 -> IO [DocumentRegister]
findExpiringRegisters pool lookaheadDays = do
  result <- use pool $ Session.statement lookaheadDays stmt
  case result of
    Right x -> pure x
    Left _ -> pure []
  where
    stmt :: Statement Int32 [DocumentRegister]
    stmt =
      Statement
        "SELECT id, person_id, type_id, series, number, issue_date, expiry_date, issuer, flags, auto_number \
        \FROM document_register \
        \WHERE expiry_date IS NOT NULL \
        \AND expiry_date <= CURRENT_DATE + ($1::int * INTERVAL '1 day') \
        \ORDER BY expiry_date ASC"
        (E.param (E.nonNullable E.int4))
        (D.rowList documentRegisterRow)
        True

findDuplicateRegisterNumbers :: Pool -> IO [DocumentRegisterDuplicate]
findDuplicateRegisterNumbers pool = do
  result <- use pool $ Session.statement () stmt
  case result of
    Right x -> pure x
    Left _ -> pure []
  where
    stmt :: Statement () [DocumentRegisterDuplicate]
    stmt =
      Statement
        "SELECT type_id, number, COUNT(*)::bigint AS total \
        \FROM document_register \
        \GROUP BY type_id, number \
        \HAVING COUNT(*) > 1 \
        \ORDER BY type_id, number"
        E.noParams
        (D.rowList duplicateRow)
        True

duplicateRow :: D.Row DocumentRegisterDuplicate
duplicateRow =
  DocumentRegisterDuplicate
    <$> D.column (D.nonNullable D.int8)
    <*> D.column (D.nonNullable D.text)
    <*> D.column (D.nonNullable D.int8)
