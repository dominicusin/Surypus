{-# LANGUAGE OverloadedStrings #-}
module ConfigSpec (spec) where

import Test.Hspec
import qualified Data.Text as T
import qualified Surypus.Domain.Config.Config as CFG

spec :: Spec
spec = do
  describe "Config" $ do
    it "has default values" $ do
      let RuntimeConfig{ rcLogLevel = lvl, rcMaxWorkers = w } = CFG.defaultConfig
      lvl `shouldBe` T.pack "INFO"
      w `shouldBe` 4
