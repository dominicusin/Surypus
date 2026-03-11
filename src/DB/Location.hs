{-# LANGUAGE OverloadedStrings #-}

module DB.Location
  ( listLocations
  , getLocation
  , createLocation
  , updateLocation
  , deleteLocation
  ) where

import Data.Int (Int64)
import Data.Text (Text)
import Hasql.Pool (Pool, use)
import Hasql.Statement (Statement (..))
import qualified Hasql.Encoders as E
import qualified Hasql.Decoders as D
import qualified Hasql.Session as Session
import Domain.Location
import Domain.Types

locationRowDecoder :: D.Row Location
locationRowDecoder =
  Location
    <$> D.column (D.nonNullable D.int8)
    <*> D.column (D.nullable D.text)
    <*> D.column (D.nonNullable D.text)
    <*> D.column (D.nonNullable D.int4)
    <*> D.column (D.nullable D.text)
    <*> D.column (D.nonNullable D.int4)
    <*> D.column (D.nullable D.float8)
    <*> D.column (D.nullable D.int8)

listLocations :: Pool -> Pagination -> LocationFilter -> IO [Location]
listLocations pool (Pagination limit offset) LocationFilter{..} = use pool $
  Session.statement (limit, offset, lfName, lfType) stmt
  where
    stmt = Statement
      "SELECT id, code, name, ltype, address, status, capacity, parent_id FROM location WHERE ($3 IS NULL OR name ILIKE $3) AND ($4 IS NULL OR ltype = $4) ORDER BY id LIMIT $1 OFFSET $2"
      (  E.param (E.nonNullable E.int4)
      <> E.param (E.nonNullable E.int4)
      <> E.param (E.nullable E.text)
      <> E.param (E.nullable E.int4)
      )
      (D.rowList locationRowDecoder)
      False

getLocation :: Pool -> Int64 -> IO (Maybe Location)
getLocation pool lid = use pool $
  Session.statement lid stmt
  where
    stmt = Statement
      "SELECT id, code, name, ltype, address, status, capacity, parent_id FROM location WHERE id = $1"
      (E.param (E.nonNullable E.int8))
      (D.rowMaybe locationRowDecoder)
      False

createLocation :: Pool -> Location -> IO Int64
createLocation pool Location{..} = use pool $
  Session.statement
    ( locationCode
    , locationName
    , locationType
    , locationAddress
    , locationStatus
    , locationCapacity
    , locationParent
    ) stmt
  where
    stmt = Statement
      "INSERT INTO location (code, name, ltype, address, status, capacity, parent_id) VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING id"
      (  E.param (E.nullable E.text)
      <> E.param (E.nonNullable E.text)
      <> E.param (E.nonNullable E.int4)
      <> E.param (E.nullable E.text)
      <> E.param (E.nonNullable E.int4)
      <> E.param (E.nullable E.float8)
      <> E.param (E.nullable E.int8)
      )
      (D.singleRow $ D.column (D.nonNullable D.int8))
      False

updateLocation :: Pool -> Int64 -> Location -> IO Bool
updateLocation pool lid Location{..} = use pool $
  Session.statement
    ( lid
    , locationCode
    , locationName
    , locationType
    , locationAddress
    , locationStatus
    , locationCapacity
    , locationParent
    ) stmt
  where
    stmt = Statement
      "UPDATE location SET code = $2, name = $3, ltype = $4, address = $5, status = $6, capacity = $7, parent_id = $8, flags = flags WHERE id = $1"
      (  E.param (E.nonNullable E.int8)
      <> E.param (E.nullable E.text)
      <> E.param (E.nonNullable E.text)
      <> E.param (E.nonNullable E.int4)
      <> E.param (E.nullable E.text)
      <> E.param (E.nonNullable E.int4)
      <> E.param (E.nullable E.float8)
      <> E.param (E.nullable E.int8)
      )
      D.noResult
      False

deleteLocation :: Pool -> Int64 -> IO Bool
deleteLocation pool lid = use pool $
  Session.statement lid stmt *> pure True
  where
    stmt = Statement
      "DELETE FROM location WHERE id = $1"
      (E.param (E.nonNullable E.int8))
      D.noResult
      False
