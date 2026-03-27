{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}

module DB.PersonBankAccount
  ( listPersonBankAccounts,
    createPersonBankAccount,
    updatePersonBankAccount,
    deletePersonBankAccount,
  )
where

import Data.Int (Int64)
import Domain.Person (PersonBankAccount (..))
import qualified Hasql.Decoders as D
import qualified Hasql.Encoders as E
import Hasql.Pool (Pool, use)
import qualified Hasql.Session as Session
import Hasql.Statement (unpreparable)

personBankAccountRowDecoder :: D.Row PersonBankAccount
personBankAccountRowDecoder =
  PersonBankAccount
    <$> D.column (D.nullable D.int8)
    <*> D.column (D.nonNullable D.int8)
    <*> D.column (D.nonNullable D.text)
    <*> D.column (D.nonNullable D.text)
    <*> D.column (D.nonNullable D.text)
    <*> D.column (D.nullable D.text)
    <*> D.column (D.nonNullable D.bool)

listPersonBankAccounts :: Pool -> Int64 -> IO [PersonBankAccount]
listPersonBankAccounts pool personId = do
  result <- use pool $ Session.statement personId stmt
  case result of
    Right x -> pure x
    Left _ -> pure []
  where
    stmt =
      unpreparable
        "SELECT id, person_id, bank_name, bank_bik, account, corr_account, is_default FROM personbankaccount WHERE person_id = $1 ORDER BY id"
        (E.param (E.nonNullable E.int8))
        (D.rowList personBankAccountRowDecoder)

createPersonBankAccount :: Pool -> Int64 -> PersonBankAccount -> IO Int64
createPersonBankAccount pool personId PersonBankAccount {..} = do
  result <- use pool $ Session.statement params stmt
  case result of
    Right x -> pure x
    Left _ -> pure 0
  where
    params =
      ( personId,
        pbaBankName,
        pbaBankBIK,
        pbaAccount,
        pbaCorrAccount,
        pbaIsDefault
      )
    stmt =
      unpreparable
        "INSERT INTO personbankaccount (person_id, bank_name, bank_bik, account, corr_account, is_default) VALUES ($1,$2,$3,$4,$5,$6) RETURNING id"
        ( E.param (E.nonNullable E.int8)
            <> E.param (E.nonNullable E.text)
            <> E.param (E.nonNullable E.text)
            <> E.param (E.nonNullable E.text)
            <> E.param (E.nullable E.text)
            <> E.param (E.nonNullable E.bool)
        )
        (D.singleRow $ D.column (D.nonNullable D.int8))

updatePersonBankAccount :: Pool -> Int64 -> PersonBankAccount -> IO Bool
updatePersonBankAccount pool personId ba@PersonBankAccount {..} = case pbaId of
  Nothing -> pure False
  Just bid -> do
    result <- use pool $ Session.statement params stmt
    case result of
      Right _ -> pure True
      Left _ -> pure False
    where
      params =
        ( bid,
          personId,
          pbaBankName,
          pbaBankBIK,
          pbaAccount,
          pbaCorrAccount,
          pbaIsDefault
        )
      stmt =
        unpreparable
          "UPDATE personbankaccount SET person_id = $2, bank_name = $3, bank_bik = $4, account = $5, corr_account = $6, is_default = $7 WHERE id = $1"
          ( E.param (E.nonNullable E.int8)
              <> E.param (E.nonNullable E.int8)
              <> E.param (E.nonNullable E.text)
              <> E.param (E.nonNullable E.text)
              <> E.param (E.nonNullable E.text)
              <> E.param (E.nullable E.text)
              <> E.param (E.nonNullable E.bool)
          )
          D.noResult

deletePersonBankAccount :: Pool -> Int64 -> IO Bool
deletePersonBankAccount pool bid = do
  result <- use pool $ Session.statement bid stmt
  case result of
    Right _ -> pure True
    Left _ -> pure False
  where
    stmt =
      unpreparable
        "DELETE FROM personbankaccount WHERE id = $1"
        (E.param (E.nonNullable E.int8))
        D.noResult
