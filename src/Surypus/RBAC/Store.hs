
module Surypus.RBAC.Store
  ( RBACStore (..),
    newRBACStore,
    listRoles,
    upsertRole,
    deleteRole,
    listGrants,
    listActiveGrants,
    addGrant,
    removeGrant,
    cleanupExpiredGrants,
    activeDelegations,
    listAuditEntries,
    cleanupAuditEntries,
    writeAuditEntry,
  )
where

import Data.IORef
import Data.Text (Text)
import Data.Time (UTCTime, getCurrentTime)
import Surypus.RBAC
  ( AuditEntry,
    DynamicRole (..),
    PermissionGrant (..),
    delegationActive,
  )

-- | In-memory store for dynamic roles, delegation grants and an audit sink
data RBACStore = RBACStore
  { rbacRoles :: IORef [DynamicRole],
    rbacGrants :: IORef [PermissionGrant],
    rbacAuditEntries :: IORef [AuditEntry],
    rbacAuditSink :: AuditEntry -> IO ()
  }

newRBACStore :: (AuditEntry -> IO ()) -> IO RBACStore
newRBACStore auditSink = do
  rolesRef <- newIORef []
  grantsRef <- newIORef []
  auditRef <- newIORef []
  pure
    RBACStore
      { rbacRoles = rolesRef,
        rbacGrants = grantsRef,
        rbacAuditEntries = auditRef,
        rbacAuditSink = auditSink
      }

listRoles :: RBACStore -> IO [DynamicRole]
listRoles store = readIORef (rbacRoles store)

upsertRole :: RBACStore -> DynamicRole -> IO ()
upsertRole store role = atomicModifyIORef' (rbacRoles store) $ \rs ->
  let rs' = role : filter ((/= drName role) . drName) rs
   in (rs', ())

deleteRole :: RBACStore -> Text -> IO ()
deleteRole store name = atomicModifyIORef' (rbacRoles store) (\rs -> (filter ((/= name) . drName) rs, ()))

listGrants :: RBACStore -> IO [PermissionGrant]
listGrants store = do
  pruneExpiredGrants store
  readIORef (rbacGrants store)

listActiveGrants :: RBACStore -> Maybe Text -> UTCTime -> IO [PermissionGrant]
listActiveGrants store mPrincipal now = do
  _ <- cleanupExpiredGrants store now
  gs <- readIORef (rbacGrants store)
  pure $ filter isActiveForPrincipal gs
  where
    isActiveForPrincipal g =
      delegationActive now g
        && case mPrincipal of
          Nothing -> True
          Just principal -> pgTo g == principal

addGrant :: RBACStore -> PermissionGrant -> IO ()
addGrant store g = do
  pruneExpiredGrants store
  atomicModifyIORef' (rbacGrants store) (\gs -> (g : gs, ()))

removeGrant :: RBACStore -> Text -> Text -> PermissionGrant -> IO ()
removeGrant store from to target =
  atomicModifyIORef' (rbacGrants store) $ \gs ->
    let keep x = ((pgFrom x /= from) || ((pgTo x /= to) || (pgPermission x /= pgPermission target)))
     in (filter keep gs, ())

cleanupExpiredGrants :: RBACStore -> UTCTime -> IO Int
cleanupExpiredGrants store now =
  atomicModifyIORef' (rbacGrants store) $ \gs ->
    let active = filter (delegationActive now) gs
        removed = length gs - length active
     in (active, removed)

-- | Return active delegations for a principal filtered by time and optional resource
activeDelegations :: RBACStore -> Text -> UTCTime -> IO [PermissionGrant]
activeDelegations store principal now = do
  _ <- cleanupExpiredGrants store now
  gs <- readIORef (rbacGrants store)
  pure $ filter (\g -> pgTo g == principal && delegationActive now g) gs

pruneExpiredGrants :: RBACStore -> IO ()
pruneExpiredGrants store = do
  now <- getCurrentTime
  _ <- cleanupExpiredGrants store now
  pure ()

listAuditEntries :: RBACStore -> IO [AuditEntry]
listAuditEntries store = readIORef (rbacAuditEntries store)

cleanupAuditEntries :: RBACStore -> Maybe Int -> IO Int
cleanupAuditEntries store mKeepLatest =
  atomicModifyIORef' (rbacAuditEntries store) $ \entries ->
    let kept = case mKeepLatest of
          Nothing -> []
          Just n -> take (max 0 n) entries
        removed = length entries - length kept
     in (kept, removed)

writeAuditEntry :: RBACStore -> AuditEntry -> IO ()
writeAuditEntry store entry = do
  atomicModifyIORef' (rbacAuditEntries store) (\es -> (entry : es, ()))
  rbacAuditSink store entry
