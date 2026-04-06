{-# LANGUAGE OverloadedStrings #-}

module DAL.Repository.RBAC
  ( RBACRepository (..),
    mkRBACRepository,
    listRoleNamesRepo,
    listPermissionNamesRepo,
    getUserRoleNamesRepo,
    assignRoleToUserRepo,
    revokeRoleFromUserRepo,
    checkUserPermissionRepo,
    checkUserAppPermissionRepo,
  )
where

import Control.Monad.IO.Class (liftIO)
import Control.Monad.Trans.Except (ExceptT, throwE)
import DAL.Repository (RepositoryError (..))
import Data.Functor.Contravariant ((>$<))
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Text.Encoding (encodeUtf8)
import qualified Hasql.Decoders as D
import qualified Hasql.Encoders as E
import Hasql.Pool (Pool, use)
import qualified Hasql.Session as Session
import Hasql.Statement (Statement (..))
import qualified Surypus.RBAC as AppRBAC

newtype RBACRepository = RBACRepository
  { rrPool :: Pool
  }

mkRBACRepository :: Pool -> RBACRepository
mkRBACRepository = RBACRepository

mkStatement :: Text -> E.Params params -> D.Result result -> Statement params result
mkStatement sql encoder decoder = Statement (encodeUtf8 sql) encoder decoder True

listRoleNamesRepo :: RBACRepository -> ExceptT RepositoryError IO [Text]
listRoleNamesRepo repo = do
  let stmt = mkStatement "SELECT name::text FROM role ORDER BY name" E.noParams (D.rowList (D.column (D.nonNullable D.text)))
  result <- liftIO . use (rrPool repo) $ Session.statement () stmt
  either (throwE . DatabaseError . T.pack . show) pure result

listPermissionNamesRepo :: RBACRepository -> ExceptT RepositoryError IO [Text]
listPermissionNamesRepo repo = do
  let stmt = mkStatement "SELECT name::text FROM permission ORDER BY name" E.noParams (D.rowList (D.column (D.nonNullable D.text)))
  result <- liftIO . use (rrPool repo) $ Session.statement () stmt
  either (throwE . DatabaseError . T.pack . show) pure result

getUserRoleNamesRepo :: RBACRepository -> Int64 -> ExceptT RepositoryError IO [Text]
getUserRoleNamesRepo repo userId = do
  let stmt =
        mkStatement
          "SELECT r.name::text FROM user_role ur JOIN role r ON r.id = ur.role_id WHERE ur.user_id = $1 ORDER BY r.name"
          (E.param (E.nonNullable E.int8))
          (D.rowList (D.column (D.nonNullable D.text)))
  result <- liftIO . use (rrPool repo) $ Session.statement userId stmt
  either (throwE . DatabaseError . T.pack . show) pure result

assignRoleToUserRepo :: RBACRepository -> Int64 -> Text -> ExceptT RepositoryError IO ()
assignRoleToUserRepo repo userId roleName = do
  let stmt =
        mkStatement
          "INSERT INTO user_role (user_id, role_id) SELECT $1, r.id FROM role r WHERE r.name = $2 ON CONFLICT DO NOTHING"
          ( (fst >$< E.param (E.nonNullable E.int8))
              <> (snd >$< E.param (E.nonNullable E.text))
          )
          D.noResult
  result <- liftIO . use (rrPool repo) $ Session.statement (userId, roleName) stmt
  either (throwE . DatabaseError . T.pack . show) pure result

revokeRoleFromUserRepo :: RBACRepository -> Int64 -> Text -> ExceptT RepositoryError IO ()
revokeRoleFromUserRepo repo userId roleName = do
  let stmt =
        mkStatement
          "DELETE FROM user_role WHERE user_id = $1 AND role_id = (SELECT id FROM role WHERE name = $2)"
          ( (fst >$< E.param (E.nonNullable E.int8))
              <> (snd >$< E.param (E.nonNullable E.text))
          )
          D.noResult
  result <- liftIO . use (rrPool repo) $ Session.statement (userId, roleName) stmt
  either (throwE . DatabaseError . T.pack . show) pure result

checkUserPermissionRepo :: RBACRepository -> Int64 -> Text -> ExceptT RepositoryError IO Bool
checkUserPermissionRepo repo userId permissionName = do
  let stmt =
        mkStatement
          "SELECT EXISTS (SELECT 1 FROM user_role ur JOIN role_permission rp ON rp.role_id = ur.role_id JOIN permission p ON p.id = rp.permission_id WHERE ur.user_id = $1 AND p.name = $2)"
          ( (fst >$< E.param (E.nonNullable E.int8))
              <> (snd >$< E.param (E.nonNullable E.text))
          )
          (D.singleRow (D.column (D.nonNullable D.bool)))
  result <- liftIO . use (rrPool repo) $ Session.statement (userId, permissionName) stmt
  either (throwE . DatabaseError . T.pack . show) pure result

checkUserAppPermissionRepo :: RBACRepository -> Int64 -> AppRBAC.Permission -> ExceptT RepositoryError IO Bool
checkUserAppPermissionRepo repo userId permission =
  checkUserPermissionRepo repo userId (AppRBAC.permissionToDbName permission)
