{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}

module DB.Person
  ( listPersons,
    getPerson,
    createPerson,
    updatePerson,
    deletePerson,
  )
where

import Data.Int (Int64)
import Data.Text (Text)
import Domain.Person
import Domain.Types
import qualified Hasql.Decoders as D
import qualified Hasql.Encoders as E
import Hasql.Pool (Pool, use)
import qualified Hasql.Session as Session
import Hasql.Statement (unpreparable)

personRowDecoder :: D.Row Person
personRowDecoder =
  Person
    <$> D.column (D.nonNullable D.int8)
    <*> D.column (D.nullable D.text)
    <*> D.column (D.nonNullable D.text)
    <*> D.column (D.nullable D.text)
    <*> D.column (D.nullable D.text)
    <*> D.column (D.nonNullable D.int4)
    <*> D.column (D.nonNullable D.int4)
    <*> D.column (D.nullable D.text)
    <*> D.column (D.nullable D.text)
    <*> D.column (D.nullable D.text)
    <*> D.column (D.nonNullable D.float8)
    <*> D.column (D.nonNullable D.float8)

listPersons :: Pool -> Pagination -> PersonFilter -> IO [Person]
listPersons pool (Pagination limit offset) PersonFilter {..} = do
  result <- use pool $ Session.statement (limit, offset, pfName, pfINN, pfKind, pfStatus) stmt
  case result of
    Right x -> pure x
    Left _ -> pure []
  where
    stmt =
      unpreparable
        "SELECT id, code, name, inn, kpp, ptype, status, phone, email, address, credit_limit, discount FROM person WHERE ($3 IS NULL OR name ILIKE $3) AND ($4 IS NULL OR inn = $4) AND ($5 IS NULL OR ptype = $5) AND ($6 IS NULL OR status = $6) ORDER BY id LIMIT $1 OFFSET $2"
        ( E.param (E.nonNullable E.int4)
            <> E.param (E.nonNullable E.int4)
            <> E.param (E.nullable E.text)
            <> E.param (E.nullable E.text)
            <> E.param (E.nullable E.int4)
            <> E.param (E.nullable E.int4)
        )
        (D.rowList personRowDecoder)

getPerson :: Pool -> Int64 -> IO (Maybe Person)
getPerson pool pid = do
  result <- use pool $ Session.statement pid stmt
  case result of
    Right x -> pure x
    Left _ -> pure Nothing
  where
    stmt =
      unpreparable
        "SELECT id, code, name, inn, kpp, ptype, status, phone, email, address, credit_limit, discount FROM person WHERE id = $1"
        (E.param (E.nonNullable E.int8))
        (D.rowMaybe personRowDecoder)

createPerson :: Pool -> Person -> IO Int64
createPerson pool Person {..} = do
  result <- use pool $ Session.statement params stmt
  case result of
    Right x -> pure x
    Left _ -> pure 0
  where
    params =
      ( personCode,
        personName,
        personINN,
        personKPP,
        personKind,
        personStatus,
        personPhone,
        personEmail,
        personAddress,
        personCredit,
        personDiscount
      )
    stmt =
      unpreparable
        "INSERT INTO person (code, name, inn, kpp, ptype, status, phone, email, address, credit_limit, discount) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11) RETURNING id"
        ( E.param (E.nullable E.text)
            <> E.param (E.nonNullable E.text)
            <> E.param (E.nullable E.text)
            <> E.param (E.nullable E.text)
            <> E.param (E.nonNullable E.int4)
            <> E.param (E.nonNullable E.int4)
            <> E.param (E.nullable E.text)
            <> E.param (E.nullable E.text)
            <> E.param (E.nullable E.text)
            <> E.param (E.nonNullable E.float8)
            <> E.param (E.nonNullable E.float8)
        )
        (D.singleRow $ D.column (D.nonNullable D.int8))

updatePerson :: Pool -> Int64 -> Person -> IO Bool
updatePerson pool pid Person {..} = do
  result <- use pool $ Session.statement params stmt
  case result of
    Right _ -> pure True
    Left _ -> pure False
  where
    params =
      ( pid,
        personCode,
        personName,
        personINN,
        personKPP,
        personKind,
        personStatus,
        personPhone,
        personEmail,
        personAddress,
        personCredit,
        personDiscount
      )
    stmt =
      unpreparable
        "UPDATE person SET code = $2, name = $3, inn = $4, kpp = $5, ptype = $6, status = $7, phone = $8, email = $9, address = $10, credit_limit = $11, discount = $12, updated_at = NOW() WHERE id = $1"
        ( E.param (E.nonNullable E.int8)
            <> E.param (E.nullable E.text)
            <> E.param (E.nonNullable E.text)
            <> E.param (E.nullable E.text)
            <> E.param (E.nullable E.text)
            <> E.param (E.nonNullable E.int4)
            <> E.param (E.nonNullable E.int4)
            <> E.param (E.nullable E.text)
            <> E.param (E.nullable E.text)
            <> E.param (E.nullable E.text)
            <> E.param (E.nonNullable E.float8)
            <> E.param (E.nonNullable E.float8)
        )
        D.noResult

deletePerson :: Pool -> Int64 -> IO Bool
deletePerson pool pid = do
  result <- use pool $ Session.statement pid stmt
  case result of
    Right _ -> pure True
    Left _ -> pure False
  where
    stmt =
      unpreparable
        "DELETE FROM person WHERE id = $1"
        (E.param (E.nonNullable E.int8))
        D.noResult
