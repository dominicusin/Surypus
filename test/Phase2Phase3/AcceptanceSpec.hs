module Phase2Phase3.AcceptanceSpec where

import Test.Hspec
import Test.Hspec.Expectations

main :: IO ()
main = hspec spec

spec :: Spec
spec = do
  describe "Phase 2-3 Acceptance (Stub)" $ do
    it "login works with valid credentials" $ Pending
    it "create account succeeds" $ Pending
    it "read accounts returns data" $ Pending
    it "create journal entry updates balance" $ Pending
    it "account_balances read-model updates after journal entry" $ Pending
    it "rbac blocks unauthorized create" $ Pending
    it "health endpoint returns ok" $ Pending
    it "readiness endpoint returns ready" $ Pending
    it "accounts ES replay works" $ Pending
    it "GraphQL proxy returns data for bills" $ Pending
    it "GraphQL proxy balance query returns data" $ Pending
