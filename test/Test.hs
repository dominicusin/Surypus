-- ============================================================================
-- SURYPUS TEST SUITE
-- ============================================================================

{-# LANGUAGE OverloadedStrings #-}

module Main where

import Test.Hspec
import Data.Text (Text)
import qualified Data.Text as T

-- ============================================================================
-- MAIN
-- ============================================================================

main :: IO ()
main = hspec $ do
    describe "Text utilities" $ do
        it "concatenation works" $ do
            let result = T.concat ["Hello", " ", "World"]
            result `shouldBe` "Hello World"

        it "empty check works" $ do
            T.null "" `shouldBe` True
            T.null "test" `shouldBe` False

        it "length check works" $ do
            T.length "hello" `shouldBe` 5
            T.length "" `shouldBe` 0
