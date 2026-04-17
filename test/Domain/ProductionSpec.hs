module Domain.ProductionSpec where

import Data.Either (isLeft, isRight)
import Data.Time (UTCTime, fromGregorian)
import Domain.Production
import Test.Hspec
import Test.QuickCheck

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
    it "released never exceed planned" $
      property $
        \(Positive plan) (NonNegative released) ->
          released <= plan

    it "stock balance non-negative after FIFO" $
      property $
        \(NonNegative initial) (NonNegative receipt) (NonNegative issue) ->
          let rest = initial + receipt - issue
           in rest >= 0

implies :: Bool -> Bool -> Bool
implies a b = not a || b
