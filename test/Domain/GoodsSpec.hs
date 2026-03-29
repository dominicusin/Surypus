{-# LANGUAGE OverloadedStrings #-}
module Domain.GoodsSpec where

import Test.Hspec
import Domain.Goods

spec :: Spec
spec = do
  describe "Goods" $ do
    it "creates goods with required fields" $ do
      let g = Goods
            { goodsId = Nothing
            , goodsCode = Just "001"
            , goodsName = "Test Product"
            , goodsBarcode = Nothing
            , goodsUnitId = 1
            , goodsParent = Nothing
            , goodsType = 0
            , goodsTaxId = Nothing
            , goodsBrandId = Nothing
            , goodsStatus = 0
            , goodsMinStock = 0
            , goodsMaxStock = Nothing
            , goodsWeight = Nothing
            , goodsVolume = Nothing
            }
      goodsName g `shouldBe` "Test Product"
