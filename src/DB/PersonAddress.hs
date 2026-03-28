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
createPersonAddress _pool _personId _addr = pure 0

updatePersonAddress :: Pool -> Int64 -> PersonAddress -> IO Bool
updatePersonAddress _pool _personId _addr = pure False

deletePersonAddress :: Pool -> Int64 -> IO Bool
deletePersonAddress _pool _aid = pure False
