{-# LANGUAGE OverloadedStrings #-}
-- | Domain Goods Tests
module Domain.GoodsSpec where

import Test.Hspec
import Test.QuickCheck
import Domain.Goods
import Data.Int (Int64)

spec :: Spec
spec = do
  describe "Goods" $ do
    it "creates goods with required fields" $ do
      let g = Goods
            { goodsId = Nothing
            , goodsName = "Test Product"
            , goodsParentId = Nothing
            , goodsKind = 0
            , goodsFlags = 0
            , goodsBrandId = Nothing
            , goodsManufId = Nothing
            , goodsTaxGrpId = Nothing
            , goodsUnitId = Nothing
            , goodsPhUnitId = Nothing
            , goodsStrucId = Nothing
            , goodsGdsClsId = Nothing
            , goodsGoodsTypeId = Nothing
            , goodsCode = Just "TEST001"
            , goodsPhCode = Nothing
            , goodsBarcode = Just "1234567890123"
            }
      goodsName g `shouldBe` "Test Product"
      goodsCode g `shouldBe` Just "TEST001"

    it "supports goods kinds" $ do
      let g = Goods Nothing "Test" Nothing 0 0 Nothing Nothing Nothing Nothing Nothing Nothing Nothing Nothing Nothing Nothing Nothing Nothing
      goodsKind g `shouldBe` 0

  describe "GoodsFilter" $ do
    it "has default values" $ do
      let f = GoodsFilter Nothing Nothing Nothing Nothing 100 0
      gfLimit f `shouldBe` 100
      gfOffset f `shouldBe` 0
      gfName f `shouldBe` Nothing

    it "supports name filter" $ do
      let f = GoodsFilter (Just "Test") Nothing Nothing Nothing 50 10
      gfName f `shouldBe` Just "Test"

  describe "GoodsStock" $ do
    it "creates stock record" $ do
      let s = GoodsStock
            { gsGoodsId = 1
            , gsGoodsName = "Product"
            , gsGoodsCode = Just "P001"
            , gsQuantity = 100
            , gsLocationId = 1
            , gsLocationName = "Warehouse"
            }
      gsQuantity s `shouldBe` 100

  describe "Barcode" $ do
    it "creates barcode" $ do
      let b = Barcode
            { bcId = Nothing
            , bcCode = "1234567890123"
            , bcGoodsId = 1
            , bcQtty = 1
            , bcBarcodeType = 0
            }
      bcCode b `shouldBe` "1234567890123"
