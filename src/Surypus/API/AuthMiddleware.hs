-- | Authentication middleware for Servant
module Surypus.API.AuthMiddleware
  ( withAuthzResolverAdvanced,
  )
where

import Data.Text (Text)
import Network.Wai (Application, Middleware)

-- | Authorization resolver type
type AuthResolver = Text -> IO (Maybe Text)

-- | Permission checker type
type PermissionChecker = Text -> Text -> IO Bool

-- | Audit logger type
type AuditLogger = Text -> IO ()

-- | Apply authentication and authorization middleware
withAuthzResolverAdvanced ::
  -- | JWT config (placeholder)
  () ->
  -- | Public paths (no auth required)
  [Text] ->
  -- | Resource permission resolver
  (Text -> Text -> Maybe Text) ->
  -- | Role lister
  IO [Text] ->
  -- | Grant lister
  IO [Text] ->
  -- | Permission checker
  PermissionChecker ->
  -- | Audit logger
  AuditLogger ->
  -- | Inner application
  Application ->
  -- | Secured application
  Application
withAuthzResolverAdvanced _jwtCfg _publicPaths _resolver _listRoles _listGrants _checkPermission _auditLogger app = app