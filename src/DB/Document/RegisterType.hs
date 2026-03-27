{-# LANGUAGE OverloadedStrings #-}

module DB.Document.RegisterType
  ( listRegisterTypes,
    getRegisterType,
    createRegisterType,
    updateRegisterType,
    deleteRegisterType,
  )
where

import Core.Document.Types (DocumentRegisterType (..))
import Data.Functor.Contravariant ((>$<))
import Data.Int (Int32, Int64)
import Data.Maybe (isJust)
import Data.Text (Text)
import qualified Hasql.Decoders as D
import qualified Hasql.Encoders as E
import Hasql.Pool (Pool, use)
import qualified Hasql.Session as Session
import Hasql.Statement (unpreparable)

registerTypeRow :: D.Row DocumentRegisterType
registerTypeRow =
  DocumentRegisterType
    <$> (Just <$> D.column (D.nonNullable D.int8))
    <*> D.column (D.nonNullable D.text)
    <*> D.column (D.nullable D.text)
    <*> (fromIntegral <$> D.column (D.nonNullable D.int4))

listRegisterTypes :: Pool -> IO [DocumentRegisterType]
listRegisterTypes pool = do
  result <- use pool $ Session.statement () stmt
  case result of
    Right x -> pure x
    Left _ -> pure []
  where
    stmt =
      unpreparable
        "SELECT id, name, code, flags FROM document_register_type ORDER BY id"
        E.noParams
        (D.rowList registerTypeRow)

getRegisterType :: Pool -> Int64 -> IO (Maybe DocumentRegisterType)
getRegisterType pool rid = do
  result <- use pool $ Session.statement rid stmt
  case result of
    Right x -> pure x
    Left _ -> pure Nothing
  where
    stmt =
      unpreparable
        "SELECT id, name, code, flags FROM document_register_type WHERE id = $1"
        (E.param (E.nonNullable E.int8))
        (D.rowMaybe registerTypeRow)

createRegisterType :: Pool -> DocumentRegisterType -> IO Int64
createRegisterType pool doc = do
  result <- use pool $ Session.statement params stmt
  case result of
    Right x -> pure x
    Left _ -> pure 0
  where
    params = (drtName doc, drtCode doc, fromIntegral (drtFlags doc) :: Int32)
    stmt =
      unpreparable
        "INSERT INTO document_register_type (name, code, flags) VALUES ($1, $2, $3) RETURNING id"
        ( ((\(a, _, _) -> a) >$< E.param (E.nonNullable E.text))
            <> ((\(_, b, _) -> b) >$< E.param (E.nullable E.text))
            <> ((\(_, _, c) -> c) >$< E.param (E.nonNullable E.int4))
        )
        (D.singleRow $ D.column (D.nonNullable D.int8))

updateRegisterType :: Pool -> Int64 -> DocumentRegisterType -> IO Bool
updateRegisterType pool rid doc = do
  result <- use pool $ Session.statement params stmt
  case result of
    Right mb -> pure $ isJust mb
    Left _ -> pure False
  where
    params = (rid, drtName doc, drtCode doc, drtFlags doc)
    stmt =
      unpreparable
        "UPDATE document_register_type SET name = $2, code = $3, flags = $4 WHERE id = $1 RETURNING id"
        ( ((\(a, _, _, _) -> a) >$< E.param (E.nonNullable E.int8))
            <> ((\(_, b, _, _) -> b) >$< E.param (E.nonNullable E.text))
            <> ((\(_, _, c, _) -> c) >$< E.param (E.nullable E.text))
            <> ((\(_, _, _, d) -> d) >$< E.param (E.nonNullable E.int4))
        )
        (D.rowMaybe (D.column (D.nonNullable D.int8)))

deleteRegisterType :: Pool -> Int64 -> IO Bool
deleteRegisterType pool rid = do
  result <- use pool $ Session.statement rid stmt
  case result of
    Right mb -> pure $ isJust mb
    Left _ -> pure False
  where
    stmt =
      unpreparable
        "DELETE FROM document_register_type WHERE id = $1 RETURNING id"
        (E.param (E.nonNullable E.int8))
        (D.rowMaybe (D.column (D.nonNullable D.int8)))
