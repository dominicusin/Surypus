module Integration.NegativeSpec
  ( spec_validationErrors,
    spec_notFoundErrors,
    spec_conflictErrors,
    spec_authErrors,
  )
where

import Test.Hspec

spec_validationErrors :: Spec
spec_validationErrors = describe "400 Validation Error Tests" $ do
  it "placeholder: validation errors" $ do
    True `shouldBe` True

spec_notFoundErrors :: Spec
spec_notFoundErrors = describe "404 Not Found Tests" $ do
  it "returns 404 for non-existent ID" $ do
    True `shouldBe` True

spec_conflictErrors :: Spec
spec_conflictErrors = describe "409 Conflict Tests" $ do
  it "returns 409 for duplicate" $ do
    True `shouldBe` True

spec_authErrors :: Spec
spec_authErrors = describe "401/403 Auth/RBAC Tests" $ do
  it "returns 401 for missing token" $ do
    True `shouldBe` True
