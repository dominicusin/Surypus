{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}

module DB.PersonAddress
  ( listPersonAddresses,
    createPersonAddress,
    updatePersonAddress,
    deletePersonAddress,
  )
where

import Data.Int (Int64)
import Domain.Person (PersonAddress (..))
import qualified Hasql.Decoders as D
import qualified Hasql.Encoders as E
import Hasql.Pool (Pool, use)
import qualified Hasql.Session as Session
import Hasql.Statement (unpreparable)

personAddressRowDecoder :: D.Row PersonAddress
personAddressRowDecoder =
  PersonAddress
    <$> D.column (D.nullable D.int8)
    <*> D.column (D.nonNullable D.int8)
    <*> (fromIntegral <$> D.column (D.nonNullable D.int4))
    <*> D.column (D.nullable D.int8)
    <*> D.column (D.nullable D.int8)
    <*> D.column (D.nullable D.text)
    <*> D.column (D.nullable D.text)
    <*> D.column (D.nullable D.text)
    <*> D.column (D.nullable D.text)
    <*> D.column (D.nullable D.text)
    <*> D.column (D.nullable D.text)
    <*> D.column (D.nullable D.text)
    <*> D.column (D.nonNullable D.bool)

listPersonAddresses :: Pool -> Int64 -> IO [PersonAddress]
listPersonAddresses pool personId = do
  result <- use pool $ Session.statement personId stmt
  case result of
    Right x -> pure x
    Left _ -> pure []
  where
    stmt =
      unpreparable
        "SELECT id, person_id, atype, country_id, region_id, district, city, town, street, house, flat, zip, is_default FROM personaddress WHERE person_id = $1 ORDER BY id"
        (E.param (E.nonNullable E.int8))
        (D.rowList personAddressRowDecoder)

createPersonAddress :: Pool -> Int64 -> PersonAddress -> IO Int64
createPersonAddress pool personId PersonAddress {..} = do
  result <- use pool $ Session.statement params stmt
  case result of
    Right x -> pure x
    Left _ -> pure 0
  where
    params =
      ( personId,
        fromIntegral paType :: Int,
        paCountryId,
        paRegionId,
        paDistrict,
        paCity,
        paTown,
        paStreet,
        paHouse,
        paFlat,
        paZip,
        paIsDefault
      )
    stmt =
      unpreparable
        "INSERT INTO personaddress (person_id, atype, country_id, region_id, district, city, town, street, house, flat, zip, is_default) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12) RETURNING id"
        ( E.param (E.nonNullable E.int8)
            <> E.param (E.nonNullable E.int4)
            <> E.param (E.nullable E.int8)
            <> E.param (E.nullable E.int8)
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

updatePersonAddress :: Pool -> Int64 -> PersonAddress -> IO Bool
updatePersonAddress pool personId addr@PersonAddress {..} = case paId of
  Nothing -> pure False
  Just aid -> do
    result <- use pool $ Session.statement params stmt
    case result of
      Right _ -> pure True
      Left _ -> pure False
    where
      params =
        ( aid,
          personId,
          fromIntegral paType :: Int,
          paCountryId,
          paRegionId,
          paDistrict,
          paCity,
          paTown,
          paStreet,
          paHouse,
          paFlat,
          paZip,
          paIsDefault
        )
      stmt =
        unpreparable
          "UPDATE personaddress SET person_id = $2, atype = $3, country_id = $4, region_id = $5, district = $6, city = $7, town = $8, street = $9, house = $10, flat = $11, zip = $12, is_default = $13 WHERE id = $1"
          ( E.param (E.nonNullable E.int8)
              <> E.param (E.nonNullable E.int8)
              <> E.param (E.nonNullable E.int4)
              <> E.param (E.nullable E.int8)
              <> E.param (E.nullable E.int8)
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

deletePersonAddress :: Pool -> Int64 -> IO Bool
deletePersonAddress pool aid = do
  result <- use pool $ Session.statement aid stmt
  case result of
    Right _ -> pure True
    Left _ -> pure False
  where
    stmt =
      unpreparable
        "DELETE FROM personaddress WHERE id = $1"
        (E.param (E.nonNullable E.int8))
        D.noResult
