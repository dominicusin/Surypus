{-# LANGUAGE OverloadedStrings #-}

module RBACSpec where

import Data.Time (UTCTime (..), fromGregorian, secondsToDiffTime)
import Network.HTTP.Types.Method (methodDelete, methodGet, methodPut)
import Surypus.API.Authorization (normalizeResourcePath, requiredPermissionForPathMethod)
import Surypus.RBAC
import Surypus.RBAC.Store
import System.Environment (lookupEnv)
import Test.Hspec

main :: IO ()
main = do
  skip <- lookupEnv "OPENPAPYRUS_SKIP_RBAC_TESTS"
  case skip of
    Just v | v == "1" || v == "true" || v == "TRUE" ->
      hspec $ do
        it "RBAC tests are gated out in CI" $ pendingWith "OPENPAPYRUS_SKIP_RBAC_TESTS=1; RBAC tests skipped"
    _ -> hspec $ describe "RBAC" $ do
      it "admin has PersonRead" $
        hasPermission RoleAdmin PersonRead `shouldBe` True
      it "admin has BillWrite" $
        hasPermission RoleAdmin BillWrite `shouldBe` True
      it "viewer cannot PersonWrite" $
        hasPermission RoleViewer PersonWrite `shouldBe` False
      it "manager can PersonRead" $
        hasPermission RoleManager PersonRead `shouldBe` True
      it "user cannot BillDelete" $
        hasPermission RoleUser BillDelete `shouldBe` False
      it "checkPermission returns Right for admin AdminAccess" $
        checkPermission "admin" AdminAccess `shouldBe` Right ()
      it "checkPermission returns Left for viewer AdminAccess" $
        checkPermission "viewer" AdminAccess `shouldSatisfy` either (const True) (const False)
      it "roleFromText works for manager" $
        roleFromText "manager" `shouldBe` RoleManager
      it "roleFromText invalid defaults to viewer" $
        roleFromText "invalid" `shouldBe` RoleViewer
      it "admin has all permissions" $ do
        hasPermission RoleAdmin PersonRead `shouldBe` True
        hasPermission RoleAdmin PersonWrite `shouldBe` True
        hasPermission RoleAdmin AdminAccess `shouldBe` True
      it "viewer only has read permissions" $ do
        hasPermission RoleViewer PersonRead `shouldBe` True
        hasPermission RoleViewer PersonWrite `shouldBe` False
        hasPermission RoleViewer BillWrite `shouldBe` False
      it "dynamic role supports scoped permissions" $ do
        let role =
              mkDynamicRole
                "warehouse-manager"
                [ ScopedPermission GoodsWrite GlobalScope,
                  ScopedPermission LocationWrite (ResourceScope "/v1/locations/1")
                ]
        checkPermissionWithCustom [role] "warehouse-manager" GoodsWrite Nothing `shouldBe` Right ()
        checkPermissionWithCustom [role] "warehouse-manager" LocationWrite (Just "/v1/locations/1") `shouldBe` Right ()
        checkPermissionWithCustom [role] "warehouse-manager" LocationWrite (Just "/v1/locations/2")
          `shouldSatisfy` either (const True) (const False)
      it "delegation can grant temporary access" $ do
        let now = UTCTime (fromGregorian 2026 4 4) (secondsToDiffTime 0)
            later = UTCTime (fromGregorian 2026 4 4) (secondsToDiffTime 3600)
            grant = escalateTemporarily "admin" "42" (ScopedPermission ReportsWrite GlobalScope) later
        hasDelegatedPermission now [grant] "42" ReportsWrite Nothing `shouldBe` True
        hasDelegatedPermission now [grant] "42" ReportsRead Nothing `shouldBe` False
      it "temporary delegation expires after deadline" $ do
        let later = UTCTime (fromGregorian 2026 4 4) (secondsToDiffTime 3600)
            afterExpiry = UTCTime (fromGregorian 2026 4 4) (secondsToDiffTime 7200)
            grant = escalateTemporarily "admin" "42" (ScopedPermission ReportsWrite GlobalScope) later
        hasDelegatedPermission afterExpiry [grant] "42" ReportsWrite Nothing `shouldBe` False
      it "rbac store persists audit entries" $ do
        store <- newRBACStore (\_ -> pure ())
        entry <- logAccessDecision "42" "admin" AdminAccess Nothing True
        writeAuditEntry store entry
        entries <- listAuditEntries store
        length entries `shouldBe` 1
      it "rbac store returns active delegations for principal" $ do
        store <- newRBACStore (\_ -> pure ())
        let now = UTCTime (fromGregorian 2026 4 4) (secondsToDiffTime 0)
            later = UTCTime (fromGregorian 2026 4 4) (secondsToDiffTime 3600)
            grant = escalateTemporarily "admin" "42" (ScopedPermission ReportsWrite GlobalScope) later
        addGrant store grant
        active <- activeDelegations store "42" now
        length active `shouldBe` 1
      it "rbac store cleanup removes expired grants" $ do
        store <- newRBACStore (\_ -> pure ())
        let now = UTCTime (fromGregorian 2026 4 4) (secondsToDiffTime 0)
            expiredAt = UTCTime (fromGregorian 2026 4 4) (secondsToDiffTime 10)
            activeUntil = UTCTime (fromGregorian 2026 4 4) (secondsToDiffTime 7200)
            expiredGrant = escalateTemporarily "admin" "42" (ScopedPermission ReportsWrite GlobalScope) expiredAt
            activeGrant = escalateTemporarily "admin" "43" (ScopedPermission ReportsWrite GlobalScope) activeUntil
        addGrant store expiredGrant
        addGrant store activeGrant
        removed <- cleanupExpiredGrants store now
        removed `shouldBe` 1
        grants <- listGrants store
        length grants `shouldBe` 1
      it "listActiveGrants can filter by principal" $ do
        store <- newRBACStore (\_ -> pure ())
        let now = UTCTime (fromGregorian 2026 4 4) (secondsToDiffTime 0)
            activeUntil = UTCTime (fromGregorian 2026 4 4) (secondsToDiffTime 7200)
            grantA = escalateTemporarily "admin" "42" (ScopedPermission ReportsWrite GlobalScope) activeUntil
            grantB = escalateTemporarily "admin" "43" (ScopedPermission ReportsWrite GlobalScope) activeUntil
        addGrant store grantA
        addGrant store grantB
        active <- listActiveGrants store (Just "42") now
        length active `shouldBe` 1
      it "listGrants auto-cleans expired entries" $ do
        store <- newRBACStore (\_ -> pure ())
        let expiredAt = UTCTime (fromGregorian 2020 1 1) (secondsToDiffTime 0)
            activeUntil = UTCTime (fromGregorian 2099 1 1) (secondsToDiffTime 0)
            expiredGrant = escalateTemporarily "admin" "42" (ScopedPermission ReportsWrite GlobalScope) expiredAt
            activeGrant = escalateTemporarily "admin" "43" (ScopedPermission ReportsWrite GlobalScope) activeUntil
        addGrant store expiredGrant
        addGrant store activeGrant
        grants <- listGrants store
        length grants `shouldBe` 1
      it "audit cleanup keeps latest entries only" $ do
        store <- newRBACStore (\_ -> pure ())
        entry1 <- logAccessDecision "42" "admin" AdminAccess Nothing True
        entry2 <- logAccessDecision "43" "admin" UsersRead Nothing True
        entry3 <- logAccessDecision "44" "admin" ReportsRead Nothing True
        writeAuditEntry store entry1
        writeAuditEntry store entry2
        writeAuditEntry store entry3
        removed <- cleanupAuditEntries store (Just 2)
        removed `shouldBe` 1
        entries <- listAuditEntries store
        length entries `shouldBe` 2
      it "authorization resolver maps bill status update to BillPost" $
        requiredPermissionForPathMethod methodPut "/api/v1/bills/1/status" `shouldBe` Just BillPost
      it "authorization resolver maps persons delete to PersonDelete" $
        requiredPermissionForPathMethod methodDelete "/api/v1/persons/1" `shouldBe` Just PersonDelete
      it "authorization resolver maps report routes to ReportsRead" $
        requiredPermissionForPathMethod methodGet "/api/v1/reports/jrxml/sales" `shouldBe` Just ReportsRead
      it "resource normalization collapses search route to base resource" $
        normalizeResourcePath "/api/v1/persons/search/demo" `shouldBe` "person"
      it "resource normalization collapses status route to base resource" $
        normalizeResourcePath "/api/v1/bills/1/status" `shouldBe` "bill:1"
      it "resource normalization rewrites jrxml route to named report key" $
        normalizeResourcePath "/api/v1/reports/jrxml/sales" `shouldBe` "report:sales"
      it "resource normalization rewrites accounting entries to domain keys" $
        normalizeResourcePath "/api/v1/accounting/entries/17" `shouldBe` "accounting-entry:17"
      it "resource normalization rewrites stock pair route to domain key" $
        normalizeResourcePath "/api/v1/stock/10/20" `shouldBe` "stock:10:20"
