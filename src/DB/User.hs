{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}

module DB.User
  ( AppUser(..)
  , getUserByLogin
  , verifyUserCredentials
  , appUserRole
  ) where

import Control.Monad (guard)
import Crypto.Hash (Digest, SHA256, hash)
import Data.Bits ((.&.))
import Data.ByteArray (constEq, convert)
import Data.ByteString (ByteString)
import qualified Data.ByteString.Base16 as B16
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text.Encoding as TE
import Hasql.Decoders (Row, column, rowMaybe)
import qualified Hasql.Decoders as D
import Hasql.Encoders (param)
import qualified Hasql.Encoders as E
import Hasql.Pool (Pool, use)
import Hasql.Statement (Statement (..))

import qualified Hasql.Session as Session

data AppUser = AppUser
  { appUserId       :: Int64
  , appUserLogin    :: Text
  , appUserName     :: Text
  , appUserPassword :: Text
  , appUserFlags    :: Int
  , appUserStatus   :: Int
  }
  deriving (Eq, Show)

userRow :: Row AppUser
userRow =
  AppUser
    <$> column (D.nonNullable D.int8)
    <*> column (D.nonNullable D.text)
    <*> column (D.nonNullable D.text)
    <*> column (D.nonNullable D.text)
    <*> column (D.nonNullable D.int4)
    <*> column (D.nonNullable D.int4)

rolesFromFlags :: Int -> Text
rolesFromFlags flags
  | flags .&. 1 /= 0 = "admin"
  | otherwise = "user"

appUserRole :: AppUser -> Text
appUserRole usr
  | appUserStatus usr /= 0 = "guest"
  | otherwise = rolesFromFlags (appUserFlags usr)

getUserByLogin :: Pool -> Text -> IO (Maybe AppUser)
getUserByLogin pool login = use pool $
  Session.statement login stmt
  where
    stmt = Statement
      "SELECT id, login, name, password, flags, status FROM users WHERE login = $1 AND status >= 0"
      (param (E.nonNullable E.text))
      (rowMaybe userRow)
      False

verifyUserCredentials :: Pool -> Text -> Text -> IO (Maybe AppUser)
verifyUserCredentials pool login password = do
  user <- getUserByLogin pool login
  pure $ do
    u <- user
    guard (verifyPassword (appUserPassword u) password)
    pure u

verifyPassword :: Text -> Text -> Bool
verifyPassword stored input =
  let storedBytes = TE.encodeUtf8 stored
      candidatePlain = TE.encodeUtf8 input
      candidateHash = hashFor input
   in constEq storedBytes candidatePlain || constEq storedBytes candidateHash

hashFor :: Text -> ByteString
hashFor txt =
  B16.encode $
    convert (hash (TE.encodeUtf8 txt) :: Digest SHA256)
