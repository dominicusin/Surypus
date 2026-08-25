{-# LANGUAGE OverloadedStrings #-}

-- | Orphan PersistField instances for Data.UUID (persistent lacks them out of the box).
module DAL.UUIDOrphans () where

import Data.Char (isHexDigit)
import Data.UUID (UUID)
import qualified Data.UUID as UUID
import Database.Persist
import Database.Persist.Sql

instance PersistField UUID where
  toPersistValue = PersistText . UUID.toText
  fromPersistValue (PersistText t) =
    maybe (Left ("UUID: invalid textual value: " ++ show t)) Right (UUID.fromText t)
  fromPersistValue (PersistByteString bs) =
    maybe (Left "UUID: invalid byte value") Right (UUID.fromASCIIBytes bs)
  fromPersistValue v = Left ("UUID: unexpected persist value: " ++ show v)

instance PersistFieldSql UUID where
  sqlType _ = SqlOther "uuid"
