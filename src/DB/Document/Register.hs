{-# LANGUAGE OverloadedStrings #-}

module DB.Document.Register
  ( listRegisters
  , getRegister
  , createRegister
  , updateRegister
  , deleteRegister
  ) where

import Core.Document.Types (DocumentRegister(..))
import Domain.Document (DocumentRegisterFilter(..))
import Domain.Types (Pagination(..))
import Data.Int (Int64)
import Hasql.Pool (Pool, use)
import Hasql.Statement (Statement(..))
import qualified Hasql.Decoders as D
import qualified Hasql.Encoders as E
import qualified Hasql.Session as Session

import DB.Document.RegisterRow (documentRegisterRow)

listRegisters :: Pool -> Pagination -> DocumentRegisterFilter -> IO [DocumentRegister]
listRegisters pool (Pagination limit offset) DocumentRegisterFilter{..} = use pool $
  Session.statement
    ( drfPersonId
    , drfTypeId
    , fmap (\txt -> "%" <> txt <> "%") drfNumber
    , limit
    , offset
    )
    stmt
  where
    stmt = Statement
      "SELECT id, person_id, type_id, series, number, issue_date, expiry_date, issuer, flags, auto_number \
      \FROM document_register \
      \WHERE ($1 IS NULL OR person_id = $1) \
        \AND ($2 IS NULL OR type_id = $2) \
        \AND ($3 IS NULL OR number ILIKE $3) \
      \ORDER BY id DESC LIMIT $4 OFFSET $5"
      (  E.param (E.nullable E.int8)
      <> E.param (E.nullable E.int8)
      <> E.param (E.nullable E.text)
      <> E.param (E.nonNullable E.int4)
      <> E.param (E.nonNullable E.int4)
      )
      (D.rowList documentRegisterRow)
      False

getRegister :: Pool -> Int64 -> IO (Maybe DocumentRegister)
getRegister pool rid = use pool $
  Session.statement rid stmt
  where
    stmt = Statement
      "SELECT id, person_id, type_id, series, number, issue_date, expiry_date, issuer, flags, auto_number FROM document_register WHERE id = $1"
      (E.param (E.nonNullable E.int8))
      (D.rowMaybe documentRegisterRow)
      False

createRegister :: Pool -> DocumentRegister -> IO Int64
createRegister pool DocumentRegister{..} =
  use pool $
    Session.statement
      ( drPersonId
      , drTypeId
      , drSeries
      , drNumber
      , drIssueDate
      , drExpiryDate
      , drIssuer
      , drFlags
      , drAutoNumber
      )
      stmt
  where
    stmt = Statement
      "SELECT create_document_register_entry($1,$2,$3,$4,$5,$6,$7,$8,$9)"
      (  E.param (E.nonNullable E.int8)
      <> E.param (E.nonNullable E.int8)
      <> E.param (E.nullable E.text)
      <> E.param (E.nullable E.text)
      <> E.param (E.nonNullable E.date)
      <> E.param (E.nullable E.date)
      <> E.param (E.nullable E.text)
      <> E.param (E.nonNullable E.int4)
      <> E.param (E.nullable E.bool)
      )
      (D.singleRow $ D.column (D.nonNullable D.int8))
      False

updateRegister :: Pool -> Int64 -> DocumentRegister -> IO Bool
updateRegister pool rid DocumentRegister{..} =
  use pool $
    Session.statement
      ( rid
      , drPersonId
      , drTypeId
      , drSeries
      , drNumber
      , drIssueDate
      , drExpiryDate
      , drIssuer
      , drFlags
      , drAutoNumber
      )
      stmt
  where
    stmt = Statement
      "SELECT update_document_register_entry($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)"
      (  E.param (E.nonNullable E.int8)
      <> E.param (E.nonNullable E.int8)
      <> E.param (E.nonNullable E.int8)
      <> E.param (E.nullable E.text)
      <> E.param (E.nullable E.text)
      <> E.param (E.nonNullable E.date)
      <> E.param (E.nullable E.date)
      <> E.param (E.nullable E.text)
      <> E.param (E.nonNullable E.int4)
      <> E.param (E.nullable E.bool)
      )
      (D.singleRow $ D.column (D.nonNullable D.bool))
      False

deleteRegister :: Pool -> Int64 -> IO Bool
deleteRegister pool rid = do
  mb <- use pool $ Session.statement rid stmt
  return (mb /= Nothing)
  where
    stmt = Statement
      "DELETE FROM document_register WHERE id = $1 RETURNING id"
      (E.param (E.nonNullable E.int8))
      (D.rowMaybe (D.column (D.nonNullable D.int8)))
      False
