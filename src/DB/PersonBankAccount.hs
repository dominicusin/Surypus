{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}

module DB.PersonBankAccount
  ( listPersonBankAccounts,
    createPersonBankAccount,
    updatePersonBankAccount,
    deletePersonBankAccount,
  )
where

import Data.Functor.Contravariant ((>$<))
import Data.Int (Int64)
import Domain.Person (PersonBankAccount (..))
import qualified Hasql.Decoders as D
import qualified Hasql.Encoders as E
import Hasql.Pool (Pool, use)
import qualified Hasql.Session as Session
import Hasql.Statement (Statement)

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
      Statement
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
      Statement
        "INSERT INTO personbankaccount (person_id, bank_name, bank_bik, account, corr_account, is_default) VALUES ($1,$2,$3,$4,$5,$6) RETURNING id"
        ( ((\(a, _, _, _, _, _) -> a) >$< E.param (E.nonNullable E.int8))
            <> ((\(_, b, _, _, _, _) -> b) >$< E.param (E.nonNullable E.text))
            <> ((\(_, _, c, _, _, _) -> c) >$< E.param (E.nonNullable E.text))
            <> ((\(_, _, _, d, _, _) -> d) >$< E.param (E.nonNullable E.text))
            <> ((\(_, _, _, _, e, _) -> e) >$< E.param (E.nullable E.text))
            <> ((\(_, _, _, _, _, f) -> f) >$< E.param (E.nonNullable E.bool))
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
        Statement
          "UPDATE personbankaccount SET person_id = $2, bank_name = $3, bank_bik = $4, account = $5, corr_account = $6, is_default = $7 WHERE id = $1"
          ( ((\(a, _, _, _, _, _, _) -> a) >$< E.param (E.nonNullable E.int8))
              <> ((\(_, b, _, _, _, _, _) -> b) >$< E.param (E.nonNullable E.int8))
              <> ((\(_, _, c, _, _, _, _) -> c) >$< E.param (E.nonNullable E.text))
              <> ((\(_, _, _, d, _, _, _) -> d) >$< E.param (E.nonNullable E.text))
              <> ((\(_, _, _, _, e, _, _) -> e) >$< E.param (E.nonNullable E.text))
              <> ((\(_, _, _, _, _, f, _) -> f) >$< E.param (E.nullable E.text))
              <> ((\(_, _, _, _, _, _, g) -> g) >$< E.param (E.nonNullable E.bool))
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
      Statement
        "DELETE FROM personbankaccount WHERE id = $1"
        (E.param (E.nonNullable E.int8))
        D.noResult
