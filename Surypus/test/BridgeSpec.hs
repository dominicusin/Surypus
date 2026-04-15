{-# LANGUAGE OverloadedStrings #-}

module BridgeSpec where

import Surypus.API.Bridge (Bridge (..), bridgeToCore, toCore)
import Test.Hspec

spec :: Spec
spec = describe "Bridge" $ do
  it "wraps and unwraps values via bridging" $ do
    let v = 42 :: Int
        b = bridgeToCore v
    toCore b `shouldBe` v
