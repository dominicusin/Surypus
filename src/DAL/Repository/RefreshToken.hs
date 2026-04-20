{-# LANGUAGE OverloadedStrings #-}

module DAL.Repository.RefreshToken
  ( storeRefreshToken,
    validateStoredRefreshToken,
    revokeRefreshToken,
    rotateStoredRefreshToken,
    cleanupExpiredRefreshTokens,
  )
where

import Data.Functor.Contravariant ((>$<))
import Data.Int (Int32, Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Text.Encoding (encodeUtf8)
import Data.Time (UTCTime)
import qualified Hasql.Decoders as D
import qualified Hasql.Encoders as E
import Hasql.Pool (Pool, use)
import qualified Hasql.Session as Session
import Hasql.Statement (Statement (..))

mkStatement :: Text -> E.Params params -> D.Result result -> Statement params result
mkStatement sql encoder decoder = Statement (encodeUtf8 sql) encoder decoder True

storeRefreshToken :: Pool -> Int64 -> Text -> UTCTime -> IO (Either Text ())
storeRefreshToken pool userId token expiresAt = do
  let stmt =
        mkStatement
          "INSERT INTO refresh_tokens (user_id, token, expires_at) VALUES ($1, $2, $3)"
          ( ((\(a, _, _) -> a) >$< E.param (E.nonNullable E.int8))
              <> ((\(_, b, _) -> b) >$< E.param (E.nonNullable E.text))
              <> ((\(_, _, c) -> c) >$< E.param (E.nonNullable E.timestamptz))
          )
          D.noResult
  res <- use pool $ Session.statement (userId, token, expiresAt) stmt
  pure $ case res of
    Right () -> Right ()
    Left err -> Left (T.pack (show err))

validateStoredRefreshToken :: Pool -> Text -> IO (Either Text (Maybe Int64))
validateStoredRefreshToken pool token = do
  let stmt =
        mkStatement
          "SELECT user_id FROM refresh_tokens WHERE token = $1 AND expires_at > CURRENT_TIMESTAMP"
          (E.param (E.nonNullable E.text))
          (D.rowMaybe (D.column (D.nonNullable D.int8)))
  res <- use pool $ Session.statement token stmt
  pure $ case res of
    Right userId -> Right userId
    Left err -> Left (T.pack (show err))

revokeRefreshToken :: Pool -> Text -> IO (Either Text ())
revokeRefreshToken pool token = do
  let stmt =
        mkStatement
          "DELETE FROM refresh_tokens WHERE token = $1"
          (E.param (E.nonNullable E.text))
          D.noResult
  res <- use pool $ Session.statement token stmt
  pure $ case res of
    Right () -> Right ()
    Left err -> Left (T.pack (show err))

rotateStoredRefreshToken :: Pool -> Text -> Text -> UTCTime -> IO (Either Text Int64)
rotateStoredRefreshToken _pool _oldToken _newToken _expiresAt = do
  pure $ Left "Token rotation requires PostgreSQL schema"

cleanupExpiredRefreshTokens :: Pool -> IO (Either Text Int64)
cleanupExpiredRefreshTokens pool = do
  let stmt :: Statement () [Int32]
      stmt =
        mkStatement
          "DELETE FROM refresh_tokens WHERE expires_at <= CURRENT_TIMESTAMP RETURNING 1"
          E.noParams
          (D.rowList (D.column (D.nonNullable D.int4)))
  res <- use pool $ Session.statement () stmt
  pure $ case res of
    Right rows -> Right (fromIntegral (length rows))
    Left err -> Left (T.pack (show err))
