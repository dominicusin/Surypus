{-# LANGUAGE OverloadedStrings #-}
module Domain.ProductionSpec where

import Test.Hspec
import Test.QuickCheck
import Data.Either (isLeft, isRight)
import Domain.Production
import Data.Time (UTCTime(..), fromGregorian)

spec :: Spec
spec = do
  describe "WorkOrder validation" $ do
    it "rejects negative quantities" $ do
      let base = WorkOrder 1 "WO-01" 1 1 (-1) 0 WO_Draft (UTCTime (fromGregorian 2026 1 1) 0) Nothing Nothing
      validateWorkOrder base `shouldSatisfy` isLeft

    it "rejects released more than planned" $ do
      let base = WorkOrder 1 "WO-02" 1 1 10 20 WO_Released (UTCTime (fromGregorian 2026 1 1) 0) Nothing Nothing
      validateWorkOrder base `shouldSatisfy` isLeft

    it "accepts valid order" $ do
      let base = WorkOrder 1 "WO-03" 1 1 10 5 WO_Released (UTCTime (fromGregorian 2026 1 1) 0) Nothing Nothing
      validateWorkOrder base `shouldSatisfy` isRight

  describe "WorkOrder properties" $ do
    it "released never exceed planned" $ property $ 
      (Positive plan) (NonNegative released) ->
        released <= plan `implies` \
          let candidate = WorkOrder 1 "PROP" 1 1 plan released WO_Released (UTCTime (fromGregorian 2026 2 1) 0) Nothing Nothing
           in validateWorkOrder candidate `shouldSatisfy` isRight

implies :: Bool -> Bool -> Bool
implies a b = not a || b
