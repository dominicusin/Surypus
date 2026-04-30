{-# LANGUAGE OverloadedStrings #-}
module RBACCanonSpec (spec) where

import Test.Hspec
import qualified Data.Text as T
import qualified Surypus.Domain.RBACCanon.Types as RT
import qualified Surypus.Domain.RBACCanon.Migration as M
import qualified Surypus.Infra.SqlGen.DSL as DSL
import Data.List (isInfixOf)

spec :: Spec
spec = do
  describe "RBACCanon.Types" $ do
    it "mkCanon sets name" $ do
      let name = T.pack "example"
          canon = RT.mkCanon name
      RT.cName canon `shouldBe` name
  describe "RBACCanon.Migrations" $ do
    it "generateV001 is non-empty" $ do
      M.generateV001 `shouldSatisfy` (not . null)
    it "generateV019 is non-empty" $ do
      M.generateV019 `shouldSatisfy` (not . null)
    it "generateV020 has CREATE VIEW" $ do
      M.generateV020 `shouldSatisfy` (isInfixOf "CREATE VIEW")
    it "generateV021 uses UNIQUE constraints" $ do
      M.generateV021 `shouldSatisfy` (isInfixOf "UNIQUE (name, owner_id)")
    it "DSL helpers render correctly" $ do
      DSL.render (DSL.dropTable "t1") `shouldBe` "DROP TABLE IF EXISTS t1;"
      DSL.render (DSL.renameTable "old" "new") `shouldBe` "ALTER TABLE old RENAME TO new;"
      DSL.render (DSL.addConstraint "t1" "cons1" "FOREIGN KEY (c) REFERENCES other(id)") `shouldBe` "ALTER TABLE t1 ADD CONSTRAINT cons1 FOREIGN KEY (c) REFERENCES other(id);"
      DSL.render (DSL.dropConstraint "t1" "cons1") `shouldBe` "ALTER TABLE t1 DROP CONSTRAINT cons1;"
    it "V025–V028 content checks" $ do
      M.generateV025 `shouldSatisfy` (isInfixOf "idx_rbac_canon_updated_at")
      M.generateV026 `shouldSatisfy` (isInfixOf "CREATE VIEW v_rbac_canon_log_summary2")
      M.generateV027 `shouldSatisfy` (isInfixOf "ck_rbac_canon_name")
      M.generateV028 `shouldSatisfy` (isInfixOf "v_rbac_canon_full_summary2")
    it "V023 adds notes" $ do
      M.generateV023 `shouldSatisfy` (isInfixOf "notes")
    it "V024 adds notes2" $ do
      M.generateV024 `shouldSatisfy` (isInfixOf "notes2")
    it "V029..V032 are non-empty" $ do
      mapM_ (\f -> f `shouldSatisfy` (not . null)) [ M.generateV029, M.generateV030, M.generateV031, M.generateV032 ]
    it "V030 content check" $ do
      M.generateV030 `shouldSatisfy` (isInfixOf "rbac_canon_summary_30")
    it "V031 content check" $ do
      M.generateV031 `shouldSatisfy` (isInfixOf "ck_rbac_canon_name_31")
    it "V032 content check" $ do
      M.generateV032 `shouldSatisfy` (isInfixOf "annotation for tooling")
    it "V033..V036 are non-empty" $ do
      mapM_ (\f -> f `shouldSatisfy` (not . null)) [ M.generateV033, M.generateV034, M.generateV035, M.generateV036 ]
    it "V037..V040 are non-empty" $ do
      mapM_ (\f -> f `shouldSatisfy` (not . null)) [ M.generateV037, M.generateV038, M.generateV039, M.generateV040 ]
    it "V033 content check" $ do
      M.generateV033 `shouldSatisfy` (isInfixOf "MV033")
    it "V034 content check" $ do
      M.generateV034 `shouldSatisfy` (isInfixOf "MV034")
    it "V035 content check" $ do
      M.generateV035 `shouldSatisfy` (isInfixOf "MV035")
    it "V036 content check" $ do
      M.generateV036 `shouldSatisfy` (isInfixOf "MV036")
