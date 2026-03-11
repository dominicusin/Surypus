{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}

module DB.Document.Counter
  ( listDocumentCounters
  , getDocumentCounter
  , createDocumentCounter
  , updateDocumentCounter
  , deleteDocumentCounter
  , getNextDocumentNumber
  ) where

import Core.Document.Types (DocumentOpCounter(..))
import Data.Int (Int64)
import Data.Semigroup ((<>))
import Data.Text (Text)
import Domain.Types (Pagination(..))
import Hasql.Pool (Pool, use)
import Hasql.Statement (Statement(..))
import qualified Hasql.Decoders as D
import qualified Hasql.Encoders as E
import qualified Hasql.Session as Session

counterRow :: D.Row DocumentOpCounter
counterRow =
  DocumentOpCounter
    <$> (Just <$> D.column (D.nonNullable D.int8))
    <*> D.column (D.nonNullable D.text)
    <*> D.column (D.nonNullable D.int4)
    <*> D.column (D.nullable D.text)
    <*> D.column (D.nonNullable D.int4)

listDocumentCounters :: Pool -> Pagination -> IO [DocumentOpCounter]
listDocumentCounters pool (Pagination limit offset) = use pool $
  Session.statement
    (limit, offset)
    stmt
  where
    stmt = Statement
      "SELECT id, name, op_kind_id, prefix, flags FROM document_op_counter \
      \ORDER BY id LIMIT $1 OFFSET $2"
      (  E.param (E.nonNullable E.int4)
      <> E.param (E.nonNullable E.int4)
      )
      (D.rowList counterRow)
      False

getDocumentCounter :: Pool -> Int64 -> IO (Maybe DocumentOpCounter)
getDocumentCounter pool cid = use pool $
  Session.statement cid stmt
  where
    stmt = Statement
      "SELECT id, name, op_kind_id, prefix, flags FROM document_op_counter WHERE id = $1"
      (E.param (E.nonNullable E.int8))
      (D.rowMaybe counterRow)
      False

createDocumentCounter :: Pool -> DocumentOpCounter -> IO Int64
createDocumentCounter pool DocumentOpCounter{..} = use pool $
  Session.statement
    ( docCounterName
    , docCounterOpKindId
    , docCounterPrefix
    , docCounterFlags
    )
    stmt
  where
    stmt = Statement
      "INSERT INTO document_op_counter (name, op_kind_id, prefix, flags) VALUES ($1,$2,$3,$4) RETURNING id"
      (  E.param (E.nonNullable E.text)
      <> E.param (E.nonNullable E.int4)
      <> E.param (E.nullable E.text)
      <> E.param (E.nonNullable E.int4)
      )
      (D.singleRow $ D.column (D.nonNullable D.int8))
      False

updateDocumentCounter :: Pool -> Int64 -> DocumentOpCounter -> IO Bool
updateDocumentCounter pool cid DocumentOpCounter{..} = do
  mb <- use pool $ Session.statement
    ( cid
    , docCounterName
    , docCounterOpKindId
    , docCounterPrefix
    , docCounterFlags
    )
    stmt
  return (mb /= Nothing)
  where
    stmt = Statement
      "UPDATE document_op_counter SET name = $2, op_kind_id = $3, prefix = $4, flags = $5 WHERE id = $1 RETURNING id"
      (  E.param (E.nonNullable E.int8)
      <> E.param (E.nonNullable E.text)
      <> E.param (E.nonNullable E.int4)
      <> E.param (E.nullable E.text)
      <> E.param (E.nonNullable E.int4)
      )
      (D.rowMaybe (D.column (D.nonNullable D.int8)))
      False

deleteDocumentCounter :: Pool -> Int64 -> IO Bool
deleteDocumentCounter pool cid = do
  mb <- use pool $ Session.statement cid stmt
  return (mb /= Nothing)
  where
    stmt = Statement
      "DELETE FROM document_op_counter WHERE id = $1 RETURNING id"
      (E.param (E.nonNullable E.int8))
      (D.rowMaybe (D.column (D.nonNullable D.int8)))
      False

getNextDocumentNumber :: Pool -> Int -> IO Text
getNextDocumentNumber pool counterId = use pool $
  Session.statement counterId stmt
  where
    stmt = Statement
      "SELECT document_get_next_doc_number($1)"
      (E.param (E.nonNullable E.int4))
      (D.singleRow $ D.column (D.nonNullable D.text))
      False
