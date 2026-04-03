module RBACSpec where

import Surypus.RBAC
import Test.Hspec

main :: IO ()
main = hspec $ do
  describe "RBAC" $ do
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
