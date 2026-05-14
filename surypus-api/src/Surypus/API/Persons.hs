{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE OverloadedStrings #-}

module Surypus.API.Persons
  ( listPersons,
    createPerson,
    getPerson,
    updatePerson,
    deletePerson,
    searchPersons,
  )
where

import DAL.Types (Person (..), PersonInput (..), QueryResult (..))
import Data.Functor.Contravariant ((>$<))
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import qualified Hasql.Decoders as D
import qualified Hasql.Encoders as E
import Hasql.Pool (Pool, use)
import qualified Hasql.Session as Session
import qualified Hasql.Statement as S

listPersons :: Pool -> Maybe Text -> Maybe Text -> Maybe Int -> Maybe Int -> Maybe Int -> IO (QueryResult [Person])
listPersons pool _ _ _ _ _ = do
  result <- use pool $ Session.statement () selectPersonsStmt
  return $ case result of
    Left err -> QueryError (T.pack $ show err)
    Right persons -> QuerySuccess persons

createPerson :: Pool -> PersonInput -> IO (QueryResult Person)
createPerson pool input = do
  result <- use pool $ Session.statement (pInputName input, pInputCode input, pInputStatus input) insertPersonStmt
  return $ case result of
    Left err -> QueryError (T.pack $ show err)
    Right p -> QuerySuccess p

getPerson :: Pool -> Int64 -> IO (QueryResult Person)
getPerson pool pid = do
  result <- use pool $ Session.statement pid selectPersonStmt
  return $ case result of
    Left err -> QueryError (T.pack $ show err)
    Right p -> QuerySuccess p

updatePerson :: Pool -> Int64 -> PersonInput -> IO (QueryResult Person)
updatePerson pool pid input = do
  result <- use pool $ Session.statement (input, pid) updatePersonStmt
  return $ case result of
    Left err -> QueryError (T.pack $ show err)
    Right p -> QuerySuccess p

deletePerson :: Pool -> Int64 -> IO (QueryResult ())
deletePerson pool pid = do
  result <- use pool $ Session.statement pid deletePersonStmt
  return $ case result of
    Left err -> QueryError (T.pack $ show err)
    Right () -> QuerySuccess ()

searchPersons :: Pool -> Text -> IO (QueryResult [Person])
searchPersons pool query = do
  result <- use pool $ Session.statement (T.append "%" (T.append query "%")) searchPersonsStmt
  return $ case result of
    Left err -> QueryError (T.pack $ show err)
    Right persons -> QuerySuccess persons

selectPersonsStmt :: S.Statement () [Person]
selectPersonsStmt = S.Statement sql encoder decoder True
  where
    sql = "SELECT id, name, code, status FROM persons ORDER BY id LIMIT 50"
    encoder = E.noParams
    decoder = D.rowList personDecoder

selectPersonStmt :: S.Statement Int64 Person
selectPersonStmt = S.Statement sql encoder decoder True
  where
    sql = "SELECT id, name, code, status FROM persons WHERE id = $1"
    encoder = ((\(pid) -> pid) >$< E.param (E.nonNullable E.int8))
    decoder = D.singleRow personDecoder

insertPersonStmt :: S.Statement (Text, Maybe Text, Maybe Int) Person
insertPersonStmt = S.Statement sql encoder decoder True
  where
    sql = "INSERT INTO persons (name, code, status) VALUES ($1, $2, $3) RETURNING id, name, code, status"
    encoder =
      ((\(name, _, _) -> name) >$< E.param (E.nonNullable E.text))
        <> ((\(_, code, _) -> code) >$< E.param (E.nullable E.text))
        <> ((\(_, _, status) -> maybe 0 (fromIntegral . fromEnum) status) >$< E.param (E.nonNullable E.int4))
    decoder = D.singleRow personDecoder

updatePersonStmt :: S.Statement (PersonInput, Int64) Person
updatePersonStmt = S.Statement sql encoder decoder True
  where
    sql = "UPDATE persons SET name = $1, code = $2, status = $3 WHERE id = $4 RETURNING id, name, code, status"
    encoder =
      ((\(pi, _) -> pInputName pi) >$< E.param (E.nonNullable E.text))
        <> ((\(pi, _) -> pInputCode pi) >$< E.param (E.nullable E.text))
        <> ((\(pi, _) -> maybe 0 (fromIntegral . fromEnum) (pInputStatus pi)) >$< E.param (E.nonNullable E.int4))
        <> ((\(_, pid) -> pid) >$< E.param (E.nonNullable E.int8))
    decoder = D.singleRow personDecoder

deletePersonStmt :: S.Statement Int64 ()
deletePersonStmt = S.Statement sql encoder decoder True
  where
    sql = "DELETE FROM persons WHERE id = $1"
    encoder = ((\(pid) -> pid) >$< E.param (E.nonNullable E.int8))
    decoder = D.noResult

searchPersonsStmt :: S.Statement Text [Person]
searchPersonsStmt = S.Statement sql encoder decoder True
  where
    sql = "SELECT id, name, code, status FROM persons WHERE name ILIKE $1 OR code ILIKE $1 LIMIT 50"
    encoder = ((\(query) -> query) >$< E.param (E.nonNullable E.text))
    decoder = D.rowList personDecoder

personDecoder :: D.Row Person
personDecoder = Person
  <$> D.column (D.nonNullable D.int8)
  <*> D.column (D.nonNullable D.text)
  <*> D.column (D.nullable D.text)
  <*> (Just . fromIntegral <$> D.column (D.nonNullable D.int4))