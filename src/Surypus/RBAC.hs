{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module Surypus.RBAC
  ( Role (..),
    Permission (..),
    RolePermission (..),
    PermissionScope (..),
    ScopedPermission (..),
    DynamicRole (..),
    PermissionGrant (..),
    AuditEntry (..),
    hasPermission,
    hasScopedPermission,
    checkPermission,
    checkPermissionScoped,
    checkPermissionWithCustom,
    grantDelegation,
    hasDelegatedPermission,
    escalateTemporarily,
    logAccessDecision,
    delegationActive,
    defaultPermissions,
    adminRole,
    managerRole,
    userRole,
    viewerRole,
    roleFromText,
    textToRole,
    permissionToText,
    permissionToDbName,
    mkDynamicRole,
  )
where

import Data.Aeson (FromJSON, ToJSON)
import Data.List (find)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (UTCTime, getCurrentTime)
import GHC.Generics (Generic)

data Role
  = RoleAdmin
  | RoleManager
  | RoleUser
  | RoleViewer
  deriving (Show, Eq, Generic)

instance ToJSON Role

instance FromJSON Role

-- roleToText :: Role -> Text
-- roleToText RoleAdmin = "admin"
-- roleToText RoleManager = "manager"
-- roleToText RoleUser = "user"
-- roleToText RoleViewer = "viewer"

textToRole :: Text -> Maybe Role
textToRole "admin" = Just RoleAdmin
textToRole "manager" = Just RoleManager
textToRole "user" = Just RoleUser
textToRole "viewer" = Just RoleViewer
textToRole _ = Nothing

data Permission
  = PersonRead
  | PersonWrite
  | PersonDelete
  | GoodsRead
  | GoodsWrite
  | GoodsDelete
  | BillRead
  | BillWrite
  | BillDelete
  | BillPost
  | PaymentRead
  | PaymentWrite
  | PaymentDelete
  | LocationRead
  | LocationWrite
  | LocationDelete
  | StockRead
  | StockWrite
  | AccountingRead
  | AccountingWrite
  | PayrollRead
  | PayrollWrite
  | ReportsRead
  | ReportsWrite
  | UsersRead
  | UsersWrite
  | SettingsRead
  | SettingsWrite
  | AdminAccess
  | BillsWrite
  | OrdersWrite
  | TaxesWrite
  | CurrenciesWrite
  | SalariesWrite
  | TaxRead
  | TaxWrite
  | TaxDelete
  | SyncRead
  | SyncWrite
  | SyncDelete
  | AuditRead
  | AuditWrite
  | AuditDelete
  | RBACRead
  | RBACWrite
  | RBACDelete
  | JDBCRead
  | JDBCWrite
  | JDBCDelete
  | CacheRead
  | CacheWrite
  | CacheDelete
  | MetricsRead
  | MetricsWrite
  | MetricsDelete
  | HealthRead
  | HealthWrite
  | HealthDelete
  | WSRead
  | WSWrite
  | WSDelete
  deriving (Show, Eq, Generic, Ord)

instance ToJSON Permission

instance FromJSON Permission

-- | Scope for a permission: either global or tied to a specific resource id
data PermissionScope
  = GlobalScope
  | ResourceScope Text
  deriving (Show, Eq, Generic)

instance ToJSON PermissionScope

instance FromJSON PermissionScope

-- | A permission optionally scoped to a resource (for resource-level ACL)
data ScopedPermission = ScopedPermission
  { spPermission :: Permission,
    spScope :: PermissionScope
  }
  deriving (Show, Eq, Generic)

instance ToJSON ScopedPermission

instance FromJSON ScopedPermission

-- | A dynamically defined role (created at runtime)
data DynamicRole = DynamicRole
  { drName :: Text,
    drPermissions :: [ScopedPermission]
  }
  deriving (Show, Eq, Generic)

instance ToJSON DynamicRole

instance FromJSON DynamicRole

-- | A delegated permission grant between principals (identified by Text, e.g. user ids or roles)
data PermissionGrant = PermissionGrant
  { pgFrom :: Text,
    pgTo :: Text,
    pgPermission :: ScopedPermission,
    pgExpiresAt :: Maybe UTCTime
  }
  deriving (Show, Eq, Generic)

instance ToJSON PermissionGrant

instance FromJSON PermissionGrant

-- | Audit log entry for permission checks
data AuditEntry = AuditEntry
  { aeTimestamp :: UTCTime,
    aePrincipal :: Text,
    aeRole :: Text,
    aePermission :: Permission,
    aeResource :: Maybe Text,
    aeAllowed :: Bool,
    aeReason :: Text
  }
  deriving (Show, Eq, Generic)

instance ToJSON AuditEntry

instance FromJSON AuditEntry

permissionToText :: Permission -> Text
permissionToText PersonRead = "person:read"
permissionToText PersonWrite = "person:write"
permissionToText PersonDelete = "person:delete"
permissionToText GoodsRead = "goods:read"
permissionToText GoodsWrite = "goods:write"
permissionToText GoodsDelete = "goods:delete"
permissionToText BillRead = "bill:read"
permissionToText BillWrite = "bill:write"
permissionToText BillDelete = "bill:delete"
permissionToText BillPost = "bill:post"
permissionToText PaymentRead = "payment:read"
permissionToText PaymentWrite = "payment:write"
permissionToText PaymentDelete = "payment:delete"
permissionToText LocationRead = "location:read"
permissionToText LocationWrite = "location:write"
permissionToText LocationDelete = "location:delete"
permissionToText StockRead = "stock:read"
permissionToText StockWrite = "stock:write"
permissionToText AccountingRead = "accounting:read"
permissionToText AccountingWrite = "accounting:write"
permissionToText PayrollRead = "payroll:read"
permissionToText PayrollWrite = "payroll:write"
permissionToText ReportsRead = "reports:read"
permissionToText ReportsWrite = "reports:write"
permissionToText UsersRead = "users:read"
permissionToText UsersWrite = "users:write"
permissionToText SettingsRead = "settings:read"
permissionToText SettingsWrite = "settings:write"
permissionToText AdminAccess = "admin:access"
permissionToText BillsWrite = "bills:write"
permissionToText OrdersWrite = "orders:write"
permissionToText TaxesWrite = "taxes:write"
permissionToText CurrenciesWrite = "currencies:write"
permissionToText SalariesWrite = "salaries:write"
permissionToText TaxRead = "tax:read"
permissionToText TaxWrite = "tax:write"
permissionToText TaxDelete = "tax:delete"
permissionToText SyncRead = "sync:read"
permissionToText SyncWrite = "sync:write"
permissionToText SyncDelete = "sync:delete"
permissionToText AuditRead = "audit:read"
permissionToText AuditWrite = "audit:write"
permissionToText AuditDelete = "audit:delete"
permissionToText RBACRead = "rbac:read"
permissionToText RBACWrite = "rbac:write"
permissionToText RBACDelete = "rbac:delete"
permissionToText JDBCRead = "jdbc:read"
permissionToText JDBCWrite = "jdbc:write"
permissionToText JDBCDelete = "jdbc:delete"
permissionToText CacheRead = "cache:read"
permissionToText CacheWrite = "cache:write"
permissionToText CacheDelete = "cache:delete"
permissionToText MetricsRead = "metrics:read"
permissionToText MetricsWrite = "metrics:write"
permissionToText MetricsDelete = "metrics:delete"
permissionToText HealthRead = "health:read"
permissionToText HealthWrite = "health:write"
permissionToText HealthDelete = "health:delete"
permissionToText WSRead = "ws:read"
permissionToText WSWrite = "ws:write"
permissionToText WSDelete = "ws:delete"

permissionToDbName :: Permission -> Text
permissionToDbName PersonRead = "read:persons"
permissionToDbName PersonWrite = "write:persons"
permissionToDbName PersonDelete = "delete:persons"
permissionToDbName GoodsRead = "read:goods"
permissionToDbName GoodsWrite = "write:goods"
permissionToDbName GoodsDelete = "delete:goods"
permissionToDbName BillRead = "read:bills"
permissionToDbName BillWrite = "write:bills"
permissionToDbName BillDelete = "delete:bills"
permissionToDbName BillPost = "post:bills"
permissionToDbName PaymentRead = "read:payments"
permissionToDbName PaymentWrite = "write:payments"
permissionToDbName PaymentDelete = "delete:payments"
permissionToDbName LocationRead = "read:locations"
permissionToDbName LocationWrite = "write:locations"
permissionToDbName LocationDelete = "delete:locations"
permissionToDbName StockRead = "read:stock"
permissionToDbName StockWrite = "write:stock"
permissionToDbName AccountingRead = "read:accounting"
permissionToDbName AccountingWrite = "write:accounting"
permissionToDbName PayrollRead = "read:payroll"
permissionToDbName PayrollWrite = "write:payroll"
permissionToDbName ReportsRead = "read:reports"
permissionToDbName ReportsWrite = "write:reports"
permissionToDbName UsersRead = "read:users"
permissionToDbName UsersWrite = "write:users"
permissionToDbName SettingsRead = "read:settings"
permissionToDbName SettingsWrite = "write:settings"
permissionToDbName AdminAccess = "admin:rbac"
permissionToDbName BillsWrite = "write:bills"
permissionToDbName OrdersWrite = "write:orders"
permissionToDbName TaxesWrite = "write:taxes"
permissionToDbName CurrenciesWrite = "write:currencies"
permissionToDbName SalariesWrite = "write:salaries"
permissionToDbName TaxRead = "read:tax"
permissionToDbName TaxWrite = "write:tax"
permissionToDbName TaxDelete = "delete:tax"
permissionToDbName SyncRead = "read:sync"
permissionToDbName SyncWrite = "write:sync"
permissionToDbName SyncDelete = "delete:sync"
permissionToDbName AuditRead = "read:audit"
permissionToDbName AuditWrite = "write:audit"
permissionToDbName AuditDelete = "delete:audit"
permissionToDbName RBACRead = "read:rbac"
permissionToDbName RBACWrite = "write:rbac"
permissionToDbName RBACDelete = "delete:rbac"
permissionToDbName JDBCRead = "read:jdbc"
permissionToDbName JDBCWrite = "write:jdbc"
permissionToDbName JDBCDelete = "delete:jdbc"
permissionToDbName CacheRead = "read:cache"
permissionToDbName CacheWrite = "write:cache"
permissionToDbName CacheDelete = "delete:cache"
permissionToDbName MetricsRead = "read:metrics"
permissionToDbName MetricsWrite = "write:metrics"
permissionToDbName MetricsDelete = "delete:metrics"
permissionToDbName HealthRead = "read:health"
permissionToDbName HealthWrite = "write:health"
permissionToDbName HealthDelete = "delete:health"
permissionToDbName WSRead = "read:ws"
permissionToDbName WSWrite = "write:ws"
permissionToDbName WSDelete = "delete:ws"

data RolePermission = RolePermission
  { rpRole :: Role,
    rpPermissions :: [Permission]
  }
  deriving (Show, Eq)

managerRole :: RolePermission
managerRole =
  RolePermission
    RoleManager
    [ PersonRead,
      PersonWrite,
      GoodsRead,
      GoodsWrite,
      BillRead,
      BillWrite,
      BillPost,
      PaymentRead,
      PaymentWrite,
      LocationRead,
      LocationWrite,
      StockRead,
      AccountingRead,
      PayrollRead,
      ReportsRead,
      BillsWrite,
      OrdersWrite,
      TaxesWrite,
      CurrenciesWrite
    ]

userRole :: RolePermission
userRole =
  RolePermission
    RoleUser
    [ PersonRead,
      GoodsRead,
      BillRead,
      PaymentRead,
      StockRead,
      AccountingRead,
      ReportsRead
    ]

viewerRole :: RolePermission
viewerRole =
  RolePermission
    RoleViewer
    [ PersonRead,
      GoodsRead,
      BillRead,
      ReportsRead
    ]

adminRole :: RolePermission
adminRole =
  RolePermission
    RoleAdmin
    [ AdminAccess,
      PersonRead,
      PersonWrite,
      PersonDelete,
      GoodsRead,
      GoodsWrite,
      GoodsDelete,
      BillRead,
      BillWrite,
      BillDelete,
      BillPost,
      LocationRead,
      LocationWrite,
      LocationDelete,
      UsersRead,
      UsersWrite,
      TaxRead,
      TaxWrite,
      TaxDelete,
      SyncRead,
      SyncWrite,
      SyncDelete,
      AuditRead,
      AuditWrite,
      AuditDelete,
      RBACRead,
      RBACWrite,
      RBACDelete,
      JDBCRead,
      JDBCWrite,
      JDBCDelete,
      CacheRead,
      CacheWrite,
      CacheDelete,
      MetricsRead,
      MetricsWrite,
      MetricsDelete,
      HealthRead,
      HealthWrite,
      HealthDelete,
      WSRead,
      WSWrite,
      WSDelete
    ]

defaultPermissions :: [RolePermission]
defaultPermissions = [adminRole, managerRole, userRole, viewerRole]

getRolePermissions :: Role -> [Permission]
getRolePermissions role = case role of
  RoleAdmin -> rpPermissions adminRole
  RoleManager -> rpPermissions managerRole
  RoleUser -> rpPermissions userRole
  RoleViewer -> rpPermissions viewerRole

hasPermission :: Role -> Permission -> Bool
hasPermission role perm = perm `elem` getRolePermissions role

checkPermission :: Text -> Permission -> Either String ()
checkPermission roleText perm = case textToRole roleText of
  Nothing -> Left $ "Unknown role: " <> T.unpack roleText
  Just role ->
    if hasPermission role perm
      then Right ()
      else Left $ "Permission denied: " <> T.unpack (permissionToText perm)

-- | Smart constructor for creating a dynamic role
mkDynamicRole :: Text -> [ScopedPermission] -> DynamicRole
mkDynamicRole name perms = DynamicRole {drName = name, drPermissions = perms}

-- | Check a scoped permission list against a target permission and optional resource id
hasScopedPermission :: [ScopedPermission] -> Permission -> Maybe Text -> Bool
hasScopedPermission scoped perm mRes = any matches scoped
  where
    matches (ScopedPermission p scope) =
      p == perm
        && case scope of
          GlobalScope -> True
          ResourceScope rid -> Just rid == mRes

-- | Check permission using built-in roles first, then fallback to dynamic roles
checkPermissionWithCustom :: [DynamicRole] -> Text -> Permission -> Maybe Text -> Either String ()
checkPermissionWithCustom customRoles roleText perm mRes =
  case textToRole roleText of
    Just r ->
      if hasPermission r perm
        then Right ()
        else Left $ "Permission denied: " <> T.unpack (permissionToText perm)
    Nothing ->
      case findRole of
        Just dr ->
          if hasScopedPermission (drPermissions dr) perm mRes
            then Right ()
            else Left $ "Permission denied: " <> T.unpack (permissionToText perm)
        Nothing -> Left $ "Unknown role: " <> T.unpack roleText
  where
    findRole = find ((== roleText) . drName) customRoles

-- | Scoped permission check: considers static and dynamic roles
checkPermissionScoped :: [DynamicRole] -> Text -> Permission -> Maybe Text -> Either String ()
checkPermissionScoped = checkPermissionWithCustom

-- | Grant a delegation (simple append helper)
grantDelegation :: PermissionGrant -> [PermissionGrant] -> [PermissionGrant]
grantDelegation grant grants = grant : grants

-- | Check whether a delegation is active at a given time
delegationActive :: UTCTime -> PermissionGrant -> Bool
delegationActive now grant =
  case pgExpiresAt grant of
    Nothing -> True
    Just expAt -> now <= expAt

-- | Determine if a principal has a delegated permission for an optional resource
hasDelegatedPermission :: UTCTime -> [PermissionGrant] -> Text -> Permission -> Maybe Text -> Bool
hasDelegatedPermission now grants principal perm mRes =
  any matches grants
  where
    matches g =
      pgTo g == principal
        && delegationActive now g
        && let ScopedPermission p scope = pgPermission g
            in p == perm
                 && case scope of
                   GlobalScope -> True
                   ResourceScope rid -> Just rid == mRes

-- | Create a temporary escalation as a delegation record
escalateTemporarily :: Text -> Text -> ScopedPermission -> UTCTime -> PermissionGrant
escalateTemporarily from to scoped end =
  PermissionGrant
    { pgFrom = from,
      pgTo = to,
      pgPermission = scoped,
      pgExpiresAt = Just end
    }

-- | Produce an audit entry for a permission decision
logAccessDecision :: Text -> Text -> Permission -> Maybe Text -> Bool -> IO AuditEntry
logAccessDecision principal role perm mRes allowed = do
  ts <- getCurrentTime
  let reason =
        if allowed
          then "allowed"
          else "denied: " <> permissionToText perm
  pure
    AuditEntry
      { aeTimestamp = ts,
        aePrincipal = principal,
        aeRole = role,
        aePermission = perm,
        aeResource = mRes,
        aeAllowed = allowed,
        aeReason = reason
      }

roleFromText :: Text -> Role
roleFromText t = case textToRole t of
  Just r -> r
  Nothing -> RoleViewer
