{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}

module DB.PersonContact
  ( listPersonContacts,
    createPersonContact,
    updatePersonContact,
    deletePersonContact,
  )
where

import Data.Int (Int64)
import Domain.Person (PersonContact (..))
import qualified Hasql.Decoders as D
import qualified Hasql.Encoders as E
import Hasql.Pool (Pool, use)
import qualified Hasql.Session as Session
import Hasql.Statement (unpreparable)

personContactRowDecoder :: D.Row PersonContact
personContactRowDecoder =
  PersonContact
    <$> D.column (D.nullable D.int8)
    <*> D.column (D.nonNullable D.int8)
    <*> D.column (D.nullable D.text)
    <*> D.column (D.nullable D.text)
    <*> D.column (D.nullable D.text)
    <*> D.column (D.nullable D.text)
    <*> D.column (D.nullable D.text)
    <*> D.column (D.nullable D.text)
    <*> D.column (D.nullable D.text)
    <*> D.column (D.nullable D.text)
    <*> D.column (D.nonNullable D.bool)

listPersonContacts :: Pool -> Int64 -> IO [PersonContact]
listPersonContacts pool personId = do
  result <- use pool $ Session.statement personId stmt
  case result of
    Right x -> pure x
    Left _ -> pure []
  where
    stmt =
      unpreparable
        "SELECT id, person_id, phone, phone_add, email, email_add, website, fax, telegram, whatsapp, is_default FROM personcontact WHERE person_id = $1 ORDER BY id"
        (E.param (E.nonNullable E.int8))
        (D.rowList personContactRowDecoder)

createPersonContact :: Pool -> Int64 -> PersonContact -> IO Int64
createPersonContact pool personId PersonContact {..} = do
  result <- use pool $ Session.statement params stmt
  case result of
    Right x -> pure x
    Left _ -> pure 0
  where
    params =
      ( personId,
        pcPhone,
        pcPhoneAdd,
        pcEmail,
        pcEmailAdd,
        pcWebsite,
        pcFax,
        pcTelegram,
        pcWhatsapp,
        pcIsDefault
      )
    stmt =
      unpreparable
        "INSERT INTO personcontact (person_id, phone, phone_add, email, email_add, website, fax, telegram, whatsapp, is_default) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10) RETURNING id"
        ( E.param (E.nonNullable E.int8)
            <> E.param (E.nullable E.text)
            <> E.param (E.nullable E.text)
            <> E.param (E.nullable E.text)
            <> E.param (E.nullable E.text)
            <> E.param (E.nullable E.text)
            <> E.param (E.nullable E.text)
            <> E.param (E.nullable E.text)
            <> E.param (E.nullable E.text)
            <> E.param (E.nonNullable E.bool)
        )
        (D.singleRow $ D.column (D.nonNullable D.int8))

updatePersonContact :: Pool -> Int64 -> PersonContact -> IO Bool
updatePersonContact pool personId contact@PersonContact {..} = case pcId of
  Nothing -> pure False
  Just cid -> do
    result <- use pool $ Session.statement params stmt
    case result of
      Right _ -> pure True
      Left _ -> pure False
    where
      params =
        ( cid,
          personId,
          pcPhone,
          pcPhoneAdd,
          pcEmail,
          pcEmailAdd,
          pcWebsite,
          pcFax,
          pcTelegram,
          pcWhatsapp,
          pcIsDefault
        )
      stmt =
        unpreparable
          "UPDATE personcontact SET person_id = $2, phone = $3, phone_add = $4, email = $5, email_add = $6, website = $7, fax = $8, telegram = $9, whatsapp = $10, is_default = $11 WHERE id = $1"
          ( E.param (E.nonNullable E.int8)
              <> E.param (E.nonNullable E.int8)
              <> E.param (E.nullable E.text)
              <> E.param (E.nullable E.text)
              <> E.param (E.nullable E.text)
              <> E.param (E.nullable E.text)
              <> E.param (E.nullable E.text)
              <> E.param (E.nullable E.text)
              <> E.param (E.nullable E.text)
              <> E.param (E.nullable E.text)
              <> E.param (E.nonNullable E.bool)
          )
          D.noResult

deletePersonContact :: Pool -> Int64 -> IO Bool
deletePersonContact pool cid = do
  result <- use pool $ Session.statement cid stmt
  case result of
    Right _ -> pure True
    Left _ -> pure False
  where
    stmt =
      unpreparable
        "DELETE FROM personcontact WHERE id = $1"
        (E.param (E.nonNullable E.int8))
        D.noResult
