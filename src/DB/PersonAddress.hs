{-# LANGUAGE OverloadedStrings #-}

module DB.PersonAddress
  ( listPersonAddresses
  , createPersonAddress
  , updatePersonAddress
  , deletePersonAddress
  ) where

import Data.Int (Int64)
import Hasql.Pool (Pool, use)
import Hasql.Statement (Statement(..))
import qualified Hasql.Encoders as E
import qualified Hasql.Decoders as D
import qualified Hasql.Session as Session
import Domain.Person (PersonAddress(..))

personAddressRowDecoder :: D.Row PersonAddress
personAddressRowDecoder =
  PersonAddress
    <$> D.column (D.nullable D.int8)
    <*> D.column (D.nonNullable D.int8)
    <*> D.column (D.nonNullable D.int4)
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
listPersonAddresses pool personId = use pool $
  Session.statement personId stmt
  where
    stmt = Statement
      "SELECT id, person_id, atype, country_id, region_id, district, city, town, street, house, flat, zip, is_default FROM personaddress WHERE person_id = $1 ORDER BY id"
      (E.param (E.nonNullable E.int8))
      (D.rowList personAddressRowDecoder)
      False

createPersonAddress :: Pool -> Int64 -> PersonAddress -> IO Int64
createPersonAddress pool personId PersonAddress{..} = use pool $
  Session.statement
    ( personId
    , paType
    , paCountryId
    , paRegionId
    , paDistrict
    , paCity
    , paTown
    , paStreet
    , paHouse
    , paFlat
    , paZip
    , paIsDefault
    )
    stmt
  where
    stmt = Statement
      "INSERT INTO personaddress (person_id, atype, country_id, region_id, district, city, town, street, house, flat, zip, is_default) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12) RETURNING id"
      (  E.param (E.nonNullable E.int8)
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
      False

updatePersonAddress :: Pool -> Int64 -> PersonAddress -> IO Bool
updatePersonAddress pool personId addr@PersonAddress{..} = case paId of
  Nothing -> pure False
  Just aid -> use pool $
    Session.statement
      ( aid
      , personId
      , paType
      , paCountryId
      , paRegionId
      , paDistrict
      , paCity
      , paTown
      , paStreet
      , paHouse
      , paFlat
      , paZip
      , paIsDefault
      )
      stmt
  where
    stmt = Statement
      "UPDATE personaddress SET person_id = $2, atype = $3, country_id = $4, region_id = $5, district = $6, city = $7, town = $8, street = $9, house = $10, flat = $11, zip = $12, is_default = $13 WHERE id = $1"
      (  E.param (E.nonNullable E.int8)
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
      False

deletePersonAddress :: Pool -> Int64 -> IO Bool
deletePersonAddress pool aid = use pool $
  Session.statement aid stmt *> pure True
  where
    stmt = Statement
      "DELETE FROM personaddress WHERE id = $1"
      (E.param (E.nonNullable E.int8))
      D.noResult
      False
