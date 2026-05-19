{-# LANGUAGE OverloadedStrings #-}
module Surypus.JWT.TokenSpec (spec) where

import Surypus.JWT.Token (verifyToken, UserClaims(..))
import Test.Hspec
import Data.Either (isLeft, isRight)

spec :: Spec
spec = describe "JWT Token" $ do

  describe "verifyToken" $ do

    it "rejects malformed tokens" $ do
      result <- verifyToken "not-a-jwt"
      result `shouldSatisfy` isLeft

    it "rejects empty tokens" $ do
      result <- verifyToken ""
      result `shouldSatisfy` isLeft

    it "rejects single-segment tokens" $ do
      result <- verifyToken "incomplete"
      result `shouldSatisfy` isLeft

    it "rejects two-segment tokens (no signature)" $ do
      result <- verifyToken "header.payload"
      result `shouldSatisfy` isLeft

    it "rejects tampered tokens" $ do
      -- A properly formatted JWT with wrong signature
      result <- verifyToken "eyJhbGciOiJIUzI1NiJ9.dGVzdA.tampered"
      result `shouldSatisfy` isLeft

  describe "generateToken" $ do
    it "requires database integration" $ do
      pendingWith "generateToken requires a real PostgreSQL pool - test via API integration"
