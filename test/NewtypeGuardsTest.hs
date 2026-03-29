module NewtypeGuardsTest where

import Surypus.Types
import Test.Hspec

-- Test newtype guards for AccountBalance, StockQty, TaxRate

spec :: Spec
spec = do
  describe "Newtype Guards" $ do
    describe "AccountBalance" $ do
      it "can be created from Integer" $ do
        let balance = AccountBalance 1000
        unAccountBalance balance `shouldBe` 1000

      it "supports Num operations" $ do
        let balance1 = AccountBalance 1000
            balance2 = AccountBalance 500
        unAccountBalance (balance1 + balance2) `shouldBe` 1500
        unAccountBalance (balance1 - balance2) `shouldBe` 500
        unAccountBalance (balance1 * balance2) `shouldBe` 50000 -- 1000 * 500 / 100
    describe "StockQty" $ do
      it "can be created from Integer" $ do
        let qty = StockQty 100
        unStockQty qty `shouldBe` 100

      it "supports Num operations" $ do
        let qty1 = StockQty 100
            qty2 = StockQty 50
        unStockQty (qty1 + qty2) `shouldBe` 150
        unStockQty (qty1 - qty2) `shouldBe` 50
        unStockQty (qty1 * qty2) `shouldBe` 50000 -- 100 * 50 / 100
    describe "TaxRate" $ do
      it "can be created from Integer" $ do
        let rate = TaxRate 20 -- 20%
        unTaxRate rate `shouldBe` 20

      it "supports Num operations" $ do
        let rate1 = TaxRate 10 -- 10%
            rate2 = TaxRate 5 -- 5%
        unTaxRate (rate1 + rate2) `shouldBe` 15
        unTaxRate (rate1 - rate2) `shouldBe` 5
        unTaxRate (rate1 * rate2) `shouldBe` 500 -- 10 * 5 / 100 = 0.5 -> 50 (since we store as hundredths)
