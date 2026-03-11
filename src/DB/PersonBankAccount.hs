{-# LANGUAGE OverloadedStrings #-}

module DB.PersonBankAccount
  ( listPersonBankAccounts
  , createPersonBankAccount
  , updatePersonBankAccount
  , deletePersonBankAccount
  ) where

import Data.Int (Int64)
import Hasql.Pool (Pool, use)
import Hasql.Statement (Statement(..))
import qualified Hasql.Encoders as E
import qualified Hasql.Decoders as D
import qualified Hasql.Session as Session
import Domain.Person (PersonBankAccount(..))

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
listPersonBankAccounts pool personId = use pool $
  Session.statement personId stmt
  where
    stmt = Statement
      "SELECT id, person_id, bank_name, bank_bik, account, corr_account, is_default FROM personbankaccount WHERE person_id = $1 ORDER BY id"
      (E.param (E.nonNullable E.int8))
      (D.rowList personBankAccountRowDecoder)
      False

createPersonBankAccount :: Pool -> Int64 -> PersonBankAccount -> IO Int64
createPersonBankAccount pool personId PersonBankAccount{..} = use pool $
  Session.statement
    ( personId
    , pbaBankName
    , pbaBankBIK
    , pbaAccount
    , pbaCorrAccount
    , pbaIsDefault
    )
    stmt
  where
    stmt = Statement
      "INSERT INTO personbankaccount (person_id, bank_name, bank_bik, account, corr_account, is_default) VALUES ($1,$2,$3,$4,$5,$6) RETURNING id"
      (  E.param (E.nonNullable E.int8)
      <> E.param (E.nonNullable E.text)
      <> E.param (E.nonNullable E.text)
      <> E.param (E.nonNullable E.text)
      <> E.param (E.nullable E.text)
      <> E.param (E.nonNullable E.bool)
      )
      (D.singleRow $ D.column (D.nonNullable D.int8))
      False

updatePersonBankAccount :: Pool -> Int64 -> PersonBankAccount -> IO Bool
updatePersonBankAccount pool personId ba@PersonBankAccount{..} = case pbaId of
  Nothing -> pure False
  Just bid -> use pool $
    Session.statement
      ( bid
      , personId
      , pbaBankName
      , pbaBankBIK
      , pbaAccount
      , pbaCorrAccount
      , pbaIsDefault
      )
      stmt
  where
    stmt = Statement
      "UPDATE personbankaccount SET person_id = $2, bank_name = $3, bank_bik = $4, account = $5, corr_account = $6, is_default = $7 WHERE id = $1"
      (  E.param (E.nonNullable E.int8)
      <> E.param (E.nonNullable E.int8)
      <> E.param (E.nonNullable E.text)
      <> E.param (E.nonNullable E.text)
      <> E.param (E.nonNullable E.text)
      <> E.param (E.nullable E.text)
      <> E.param (E.nonNullable E.bool)
      )
      D.noResult
      False

deletePersonBankAccount :: Pool -> Int64 -> IO Bool
deletePersonBankAccount pool bid = use pool $
  Session.statement bid stmt *> pure True
  where
    stmt = Statement
      "DELETE FROM personbankaccount WHERE id = $1"
      (E.param (E.nonNullable E.int8))
      D.noResult
      False
