{-# LANGUAGE OverloadedStrings #-}

module DB.Document.RegisterType
  ( listRegisterTypes
  , getRegisterType
  , createRegisterType
  , updateRegisterType
  , deleteRegisterType
  ) where

import Core.Document.Types (DocumentRegisterType(..))
import Data.Int (Int64)
import Data.Text (Text)
import Hasql.Pool (Pool, use)
import Hasql.Statement (Statement(..))
import qualified Hasql.Decoders as D
import qualified Hasql.Encoders as E
import qualified Hasql.Session as Session
registerTypeRow :: D.Row DocumentRegisterType
registerTypeRow =
  DocumentRegisterType
    <$> (Just <$> D.column (D.nonNullable D.int8))
    <*> D.column (D.nonNullable D.text)
    <*> D.column (D.nullable D.text)
    <*> D.column (D.nonNullable D.int4)

listRegisterTypes :: Pool -> IO [DocumentRegisterType]
listRegisterTypes pool = use pool $
  Session.statement () stmt
  where
    stmt = Statement
      "SELECT id, name, code, flags FROM document_register_type ORDER BY id"
      E.noParams
      (D.rowList registerTypeRow)
      False

getRegisterType :: Pool -> Int64 -> IO (Maybe DocumentRegisterType)
getRegisterType pool rid = use pool $
  Session.statement rid stmt
  where
    stmt = Statement
      "SELECT id, name, code, flags FROM document_register_type WHERE id = $1"
      (E.param (E.nonNullable E.int8))
      (D.rowMaybe registerTypeRow)
      False

getRegisterTypeByCode :: Pool -> Text -> IO (Maybe DocumentRegisterType)
getRegisterTypeByCode pool code = use pool $
  Session.statement code stmt
  where
    stmt = Statement
      "SELECT id, name, code, flags FROM document_register_type WHERE upper(code) = upper($1)"
      (E.param (E.nonNullable E.text))
      (D.rowMaybe registerTypeRow)
      False

getNextRegisterNumber :: Pool -> Int64 -> IO Text
getNextRegisterNumber pool typeId = use pool $
  Session.statement typeId stmt
  where
  stmt = Statement
    "SELECT document_get_next_register_number($1)"
    (E.param (E.nonNullable E.int8))
    (D.singleRow $ D.column (D.nonNullable D.text))
    False

getRegisterTypeFlags :: Pool -> Int64 -> IO (Maybe Int)
getRegisterTypeFlags pool rid = use pool $
  Session.statement rid stmt
  where
    stmt = Statement
      "SELECT flags FROM document_register_type WHERE id = $1"
      (E.param (E.nonNullable E.int8))
      (D.rowMaybe (D.column (D.nonNullable D.int4)))
      False

createRegisterType :: Pool -> DocumentRegisterType -> IO Int64
createRegisterType pool DocumentRegisterType{..} = use pool $
  Session.statement
    ( drtName
    , drtCode
    , drtFlags
    )
    stmt
  where
    stmt = Statement
      "INSERT INTO document_register_type (name, code, flags) VALUES ($1, $2, $3) RETURNING id"
      (  E.param (E.nonNullable E.text)
      <> E.param (E.nullable E.text)
      <> E.param (E.nonNullable E.int4)
      )
      (D.singleRow $ D.column (D.nonNullable D.int8))
      False

updateRegisterType :: Pool -> Int64 -> DocumentRegisterType -> IO Bool
updateRegisterType pool rid DocumentRegisterType{..} = do
  mb <- use pool $ Session.statement
    ( rid
    , drtName
    , drtCode
    , drtFlags
    )
    stmt
  return (mb /= Nothing)
  where
    stmt = Statement
      "UPDATE document_register_type SET name = $2, code = $3, flags = $4 WHERE id = $1 RETURNING id"
      (  E.param (E.nonNullable E.int8)
      <> E.param (E.nonNullable E.text)
      <> E.param (E.nullable E.text)
      <> E.param (E.nonNullable E.int4)
      )
      (D.rowMaybe (D.column (D.nonNullable D.int8)))
      False

deleteRegisterType :: Pool -> Int64 -> IO Bool
deleteRegisterType pool rid = do
  mb <- use pool $ Session.statement rid stmt
  return (mb /= Nothing)
  where
    stmt = Statement
      "DELETE FROM document_register_type WHERE id = $1 RETURNING id"
      (E.param (E.nonNullable E.int8))
      (D.rowMaybe (D.column (D.nonNullable D.int8)))
      False
