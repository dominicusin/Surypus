-- | Refresh Token Repository - Database operations for refresh tokens
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
module Surypus.RefreshTokenRepo
  ( storeRefreshToken,
    rotateStoredRefreshToken,
    validateRefreshToken,
    getRefreshToken,
    deleteRefreshToken,
  )
where

import DAL.Database (ConnectionPool, runDb)
import Data.Int (Int64)
import Data.Maybe (listToMaybe)
import Data.Text (Text)
import qualified Data.Text as T
import Database.Persist.Sql (PersistValue (..), Single (..), rawExecute, rawSql, SqlPersistT)

storeRefreshToken :: ConnectionPool -> Int64 -> Text -> Text -> IO (Either Text ())
storeRefreshToken pool userId token expiresAt =
  runDb pool $ do
    rawExecute
      "INSERT INTO user_sessions (user_id, token, expires_at) VALUES (?, ?, ?)"
      [PersistInt64 userId, PersistText token, PersistText expiresAt]
    pure $ Right ()

rotateStoredRefreshToken :: ConnectionPool -> Text -> Text -> Text -> IO (Either Text Int64)
rotateStoredRefreshToken pool oldToken newToken expiresAt =
  runDb pool $ do
    uidResult <-
      rawSql "SELECT user_id FROM user_sessions WHERE token = ?" [PersistText oldToken] ::
        SqlPersistT IO [Single Int64]
    case uidResult of
      [Single userId] -> do
        rawExecute "DELETE FROM user_sessions WHERE user_id = ?" [PersistInt64 userId]
        rawExecute
          "INSERT INTO user_sessions (user_id, token, expires_at) VALUES (?, ?, ?)"
          [PersistInt64 userId, PersistText newToken, PersistText expiresAt]
        pure $ Right userId
      [] -> pure $ Left "Old token not found"
      _ -> pure $ Left "Multiple sessions found"

validateRefreshToken :: ConnectionPool -> Text -> IO (Either Text Int64)
validateRefreshToken pool token =
  runDb pool $ do
    result <-
      rawSql
        "SELECT user_id FROM user_sessions WHERE token = ? AND expires_at > CURRENT_TIMESTAMP"
        [PersistText token] ::
        SqlPersistT IO [Single Int64]
    case listToMaybe result of
      Just (Single userId) -> pure $ Right userId
      Nothing -> pure $ Left "Invalid or expired token"

getRefreshToken :: ConnectionPool -> Text -> IO (Either Text (Int64, Text))
getRefreshToken pool token =
  runDb pool $ do
    rows <-
      rawSql
        "SELECT user_id, expires_at FROM user_sessions WHERE token = ?"
        [PersistText token] ::
        SqlPersistT IO [(Single Int64, Single Text)]
    case listToMaybe rows of
      Just (Single userId, Single expiresAt) -> pure $ Right (userId, expiresAt)
      Nothing -> pure $ Left "Token not found"

deleteRefreshToken :: ConnectionPool -> Text -> IO (Either Text ())
deleteRefreshToken pool token =
  runDb pool $ do
    rawExecute "DELETE FROM user_sessions WHERE token = ?" [PersistText token]
    pure $ Right ()
