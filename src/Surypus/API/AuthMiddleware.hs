{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Surypus.API.AuthMiddleware
  ( withAuthAndPermission,
    withAuthAndPermissionAdvanced,
    withAuthzResolverAdvanced,
    PermissionRequired (..),
    extractUserIdFromRequest,
    extractRoleFromRequest,
  )
where

import Control.Monad (when)
import Data.Aeson (decode)
import Data.ByteString.Lazy (fromStrict)
-- removed unused roleFromText to satisfy -Werror

import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import Data.Time (getCurrentTime)
import Network.HTTP.Types (status401, status403)
import Network.Wai (Middleware, Request, rawPathInfo, requestHeaders, responseLBS)
import qualified Network.Wai as Wai
import Surypus.API.Authorization (normalizeResourcePath)
import Surypus.JWT (JWTConfig (..), JWTPayload (..))
import Surypus.RBAC
  ( AuditEntry,
    DynamicRole,
    Permission,
    PermissionGrant,
    checkPermission,
    checkPermissionWithCustom,
    hasDelegatedPermission,
    logAccessDecision,
  )
import System.Environment (lookupEnv)
import Text.Read (readMaybe)

-- | Combined authentication and authorization middleware
-- Debug logger (enabled via OPENPAPYRUS_DEBUG=1)
debugLog :: String -> IO ()
debugLog msg = do
  m <- lookupEnv "OPENPAPYRUS_DEBUG"
  when (m == Just "1") $ putStrLn $ "[OPENPAPYRUS-DEBUG] " ++ msg

-- | Combined authentication and authorization middleware
withAuthAndPermission :: JWTConfig -> [Text] -> Permission -> Middleware
withAuthAndPermission jwtCfg publicPaths requiredPerm app req respond
  | isPublicPath = app req respond
  | otherwise = do
      debugLog $ "Auth check: path=" ++ show (pathInfo req) ++ ", method=" ++ show (Wai.requestMethod req)
      let authResult = validateJWT jwtCfg req
      case authResult of
        Left err -> respond $ unauthorizedResponse (T.pack err)
        Right payload -> do
          let userRoleText = jwtRole payload
          case checkPermission userRoleText requiredPerm of
            Left err -> respond $ forbiddenResponse (T.pack err)
            Right () -> do
              let req' =
                    req
                      { Wai.requestHeaders =
                          ("x-user-id", TE.encodeUtf8 (T.pack (show (jwtUserId payload))))
                            : ("x-user-role", TE.encodeUtf8 (jwtRole payload))
                            : requestHeaders req
                      }
              app req' respond
  where
    isPublicPath = pathInfo req `elem` publicPaths
    pathInfo = TE.decodeUtf8 . rawPathInfo

-- | Advanced middleware that supports dynamic roles, delegated permissions and audit logging
--   - dynamicRoles: custom roles with scoped permissions
--   - delegations: permission grants from one principal to another
--   - auditSink: function to persist/forward audit entries (no-op if you pass \_ -> pure ())
withAuthAndPermissionAdvanced ::
  JWTConfig ->
  [Text] ->
  Permission ->
  [DynamicRole] ->
  [PermissionGrant] ->
  (AuditEntry -> IO ()) ->
  Middleware
withAuthAndPermissionAdvanced jwtCfg publicPaths requiredPerm dynamicRoles delegations auditSink app req respond
  | isPublicPath = app req respond
  | otherwise = do
      let authResult = validateJWT jwtCfg req
      case authResult of
        Left err -> respond $ unauthorizedResponse (T.pack err)
        Right payload -> do
          now <- getCurrentTime
          let roleText = jwtRole payload
              principal = T.pack (show (jwtUserId payload))
              mResource = requestPathAsResource req

              baseAllowed =
                case checkPermissionWithCustom dynamicRoles roleText requiredPerm mResource of
                  Right () -> True
                  Left _ -> False

              delegatedAllowed =
                hasDelegatedPermission now delegations principal requiredPerm mResource

              allowed = baseAllowed || delegatedAllowed

          auditEntry <- logAccessDecision principal roleText requiredPerm mResource allowed
          auditSink auditEntry

          if allowed
            then do
              let req' =
                    req
                      { Wai.requestHeaders =
                          ("x-user-id", TE.encodeUtf8 (T.pack (show (jwtUserId payload))))
                            : ("x-user-role", TE.encodeUtf8 (jwtRole payload))
                            : requestHeaders req
                      }
              app req' respond
            else respond $ forbiddenResponse "Permission denied"
  where
    isPublicPath = pathInfo req `elem` publicPaths
    pathInfo = TE.decodeUtf8 . rawPathInfo

-- | Request-aware authorization middleware.
--   Authenticates every non-public request, then resolves the required permission
--   from the request path/method. If no permission is required, the authenticated
--   request proceeds with user headers attached.
withAuthzResolverAdvanced ::
  JWTConfig ->
  [Text] ->
  (Request -> Maybe Permission) ->
  IO [DynamicRole] ->
  IO [PermissionGrant] ->
  (Text -> Permission -> Maybe Text -> IO Bool) ->
  (AuditEntry -> IO ()) ->
  Middleware
withAuthzResolverAdvanced jwtCfg publicPaths resolvePermission loadRoles loadGrants checkStoredPermission auditSink app req respond
  | isPublicPath = do
      debugLog $ "Public endpoint (RBAC): path=" ++ show (pathInfo req) ++ ", method=" ++ show (Wai.requestMethod req)
      app req respond
  | otherwise = do
      let authResult = validateJWT jwtCfg req
      case authResult of
        Left err -> respond $ unauthorizedResponse (T.pack err)
        Right payload -> do
          let req' =
                req
                  { Wai.requestHeaders =
                      ("x-user-id", TE.encodeUtf8 (T.pack (show (jwtUserId payload))))
                        : ("x-user-role", TE.encodeUtf8 (jwtRole payload))
                        : requestHeaders req
                  }
          case resolvePermission req of
            Nothing -> app req' respond
            Just requiredPerm -> do
              dynamicRoles <- loadRoles
              delegations <- loadGrants
              now <- getCurrentTime
              let roleText = jwtRole payload
                  principal = T.pack (show (jwtUserId payload))
                  mResource = requestPathAsResource req
                  baseAllowed =
                    case checkPermissionWithCustom dynamicRoles roleText requiredPerm mResource of
                      Right () -> True
                      Left _ -> False
                  delegatedAllowed =
                    hasDelegatedPermission now delegations principal requiredPerm mResource
              storedAllowed <- checkStoredPermission principal requiredPerm mResource
              let allowed = baseAllowed || delegatedAllowed || storedAllowed
              auditEntry <- logAccessDecision principal roleText requiredPerm mResource allowed
              auditSink auditEntry
              if allowed
                then app req' respond
                else respond $ forbiddenResponse "Permission denied"
  where
    isPublicPath = pathInfo req `elem` publicPaths
    pathInfo = TE.decodeUtf8 . rawPathInfo

-- | Convert request path to a simple resource identifier (e.g., "/v1/persons/123")
requestPathAsResource :: Request -> Maybe Text
requestPathAsResource r =
  let p = normalizeResourcePath (TE.decodeUtf8 (rawPathInfo r))
   in if T.null p then Nothing else Just p

-- | Validate JWT token and extract payload
validateJWT :: JWTConfig -> Request -> Either String JWTPayload
validateJWT _ req = do
  let mAuthHeader = lookup "Authorization" (requestHeaders req)
  authHeader <- maybe (Left "Missing Authorization header") Right mAuthHeader
  token <- stripBearer (TE.decodeUtf8 authHeader)
  let tokenBS = TE.encodeUtf8 token
  case decode (fromStrict tokenBS) of
    Nothing -> Left "Invalid token format"
    Just p -> Right p

-- | Extract Bearer token from Authorization header
stripBearer :: Text -> Either String Text
stripBearer t = case T.stripPrefix "Bearer " t of
  Just rest -> if T.null rest then Left "Empty token" else Right rest
  Nothing -> Left "Invalid Authorization header format"

-- | Unauthorized response (401)
unauthorizedResponse :: Text -> Wai.Response
unauthorizedResponse msg =
  responseLBS
    status401
    [("Content-Type", "application/json")]
    (fromStrict . TE.encodeUtf8 $ ("{\"error\":\"" <> msg <> "\"}"))

-- | Forbidden response (403)
forbiddenResponse :: Text -> Wai.Response
forbiddenResponse msg =
  responseLBS
    status403
    [("Content-Type", "application/json")]
    (fromStrict . TE.encodeUtf8 $ ("{\"error\":\"" <> msg <> "\"}"))

-- | Extract user ID from request headers (set by JWT middleware)
extractUserIdFromRequest :: Request -> Maybe Int
extractUserIdFromRequest req = do
  mUserId <- lookup "x-user-id" (Wai.requestHeaders req)
  let userIdStr = TE.decodeUtf8 mUserId
  readMaybe (T.unpack userIdStr)

-- | Extract role from request headers (set by JWT middleware)
extractRoleFromRequest :: Request -> Maybe Text
extractRoleFromRequest req = do
  mRole <- lookup "x-user-role" (Wai.requestHeaders req)
  pure $ TE.decodeUtf8 mRole

-- | Data type for specifying required permission
data PermissionRequired = PermissionRequired
  { prPermission :: Permission,
    prDescription :: Text
  }
  deriving (Show, Eq)
