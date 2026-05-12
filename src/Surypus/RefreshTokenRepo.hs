-- | Refresh Token Repository - Database operations for refresh tokens
{-# LANGUAGE OverloadedStrings #-}
module Surypus.RefreshTokenRepo
  ( storeRefreshToken,
    rotateStoredRefreshToken,
    validateRefreshToken,
    getRefreshToken,
    deleteRefreshToken,
  )
where

import Data.Functor.Contravariant ((>$<))
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import qualified Hasql.Decoders as D
import qualified Hasql.Encoders as E
import Hasql.Pool (Pool, use)
import qualified Hasql.Session as Session
import qualified Hasql.Statement as S

-- | Helper to create statements using the surypus-api pattern
unpreparable :: T.Text -> E.Params params -> D.Result result -> S.Statement params result
unpreparable sql encoder decoder = S.Statement (TE.encodeUtf8 sql) encoder decoder True

-- | Store a new refresh token
storeRefreshToken :: Pool -> Int64 -> Text -> Text -> IO (Either Text ())
storeRefreshToken pool userId token expiresAtText = do
  let stmt = unpreparable
        "INSERT INTO user_sessions (user_id, token, expires_at) VALUES ($1, $2, $3)"
        ( (fst3 >$< E.param (E.nonNullable E.int8))
            <> (snd3 >$< E.param (E.nonNullable E.text))
            <> (trd3 >$< E.param (E.nonNullable E.text))
        )
        D.noResult
  res <- use pool $ Session.statement (userId, token, expiresAtText) stmt
  case res of
    Right () -> pure $ Right ()
    Left err -> pure $ Left $ T.pack $ show err
  where
    fst3 :: (a, b, c) -> a
    fst3 (x, _, _) = x
    snd3 :: (a, b, c) -> b
    snd3 (_, x, _) = x
    trd3 :: (a, b, c) -> c
    trd3 (_, _, x) = x

-- | Rotate a refresh token (delete old, insert new) - returns the user_id
rotateStoredRefreshToken :: Pool -> Text -> Text -> Text -> IO (Either Text Int64)
rotateStoredRefreshToken pool oldToken newToken expiresAtText = do
  -- First delete the old token and get the user_id
  let deleteStmt = unpreparable
        "DELETE FROM user_sessions WHERE token = $1 RETURNING user_id"
        (E.param (E.nonNullable E.text))
        (D.rowMaybe (D.column (D.nonNullable D.int8)))
  deleteRes <- use pool $ Session.statement oldToken deleteStmt
  case deleteRes of
    Left err -> pure $ Left $ T.pack $ show err
    Right (Just userId) -> do
      -- Insert the new token
      let insertStmt = unpreparable
            "INSERT INTO user_sessions (user_id, token, expires_at) VALUES ($1, $2, $3)"
            ( (fst3 >$< E.param (E.nonNullable E.int8))
                <> (snd3 >$< E.param (E.nonNullable E.text))
                <> (trd3 >$< E.param (E.nonNullable E.text))
            )
            D.noResult
      insertRes <- use pool $ Session.statement (userId, newToken, expiresAtText) insertStmt
      case insertRes of
        Left err -> pure $ Left $ T.pack $ show err
        Right () -> pure $ Right userId
    Right Nothing -> pure $ Left "Refresh token not found"
  where
    fst3 :: (a, b, c) -> a
    fst3 (x, _, _) = x
    snd3 :: (a, b, c) -> b
    snd3 (_, x, _) = x
    trd3 :: (a, b, c) -> c
    trd3 (_, _, x) = x

-- | Validate a refresh token and return user_id
validateRefreshToken :: Pool -> Text -> IO (Either Text Int64)
validateRefreshToken pool token = do
  let stmt = unpreparable
        "SELECT user_id FROM user_sessions WHERE token = $1 AND expires_at > CURRENT_TIMESTAMP"
        (E.param (E.nonNullable E.text))
        (D.rowMaybe (D.column (D.nonNullable D.int8)))
  res <- use pool $ Session.statement token stmt
  case res of
    Left err -> pure $ Left $ T.pack $ show err
    Right (Just userId) -> pure $ Right userId
    Right Nothing -> pure $ Left "Invalid or expired token"

-- | Get refresh token info (for debugging)
getRefreshToken :: Pool -> Text -> IO (Either Text (Int64, Text))
getRefreshToken pool token = do
  let stmt = unpreparable
        "SELECT user_id, expires_at FROM user_sessions WHERE token = $1"
        (E.param (E.nonNullable E.text))
        (D.rowMaybe $ (,) <$> D.column (D.nonNullable D.int8) <*> D.column (D.nonNullable D.text))
  res <- use pool $ Session.statement token stmt
  case res of
    Left err -> pure $ Left $ T.pack $ show err
    Right (Just (userId, expiresAt)) -> pure $ Right (userId, expiresAt)
    Right Nothing -> pure $ Left "Token not found"

-- | Delete a refresh token (logout)
deleteRefreshToken :: Pool -> Text -> IO (Either Text ())
deleteRefreshToken pool token = do
  let stmt = unpreparable
        "DELETE FROM user_sessions WHERE token = $1"
        (E.param (E.nonNullable E.text))
        D.noResult
  res <- use pool $ Session.statement token stmt
  case res of
    Left err -> pure $ Left $ T.pack $ show err
    Right () -> pure $ Right ()