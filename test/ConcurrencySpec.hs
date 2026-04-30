{-# LANGUAGE OverloadedStrings #-}
module ConcurrencySpec (spec) where

import Test.Hspec
import qualified Surypus.Domain.Concurrency.Domain as CD

spec :: Spec
spec = do
  describe "Concurrency Domain" $ do
    it "starts canonicalization workers (stub)" $ do
      CD.startCanonicalizeAll
      return ()
