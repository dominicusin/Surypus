{-# LANGUAGE OverloadedStrings #-}

-- | Validation layer QuickCheck properties
module Integration.ValidationSpec
  ( spec_validationProperties,
  )
where

import DAL.Types
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (Day, fromGregorian)
import Surypus.Validation
  ( ValidationError (..),
    isValidINN,
    isValidKPP,
    isValidPhone,
    validateAccPlanInput,
    validateAccTurnInput,
    validateBillInput,
    validateCurrencyInput,
    validateGoodsInput,
    validateLocationInput,
    validateOrderInput,
    validatePaymentInput,
    validatePriceInput,
    validateTaxInput,
  )
import Test.Hspec
import Test.Hspec.QuickCheck (prop)
import Test.QuickCheck
  ( Arbitrary (..),
    Property,
    choose,
    forAll,
    suchThat,
  )

-- | PersonInput generator
instance Arbitrary PersonInput where
  arbitrary = do
    name <- suchThat (T.pack <$> arbitrary) (\n -> T.length n > 0 && T.length n <= 255)
    inn <- oneof [pure Nothing, Just . T.pack <$> suchThat arbitrary (\s -> T.length s == 10 || T.length s == 12)]
    kpp <- oneof [pure Nothing, Just . T.pack <$> suchThat arbitrary (T.length . T.pack >> (== 9))]
    ptype <- suchThat arbitrary (>= 0)
    status <- suchThat arbitrary (>= 0)
    pure $ PersonInput name inn kpp ptype status

-- | GoodsInput generator
instance Arbitrary GoodsInput where
  arbitrary = do
    name <- suchThat (T.pack <$> arbitrary) (\n -> T.length n > 0 && T.length n <= 255)
    unitId <- suchThat arbitrary (> 0)
    pure $ GoodsInput name unitId

-- | BillInput generator
instance Arbitrary BillInput where
  arbitrary = do
    billType <- suchThat arbitrary (>= 0)
    status <- suchThat arbitrary (>= 0)
    total <- arbitrary `suchThat` (>= 0)
    discount <- arbitrary `suchThat` (>= 0)
    tax <- arbitrary `suchThat` (>= 0)
    pure $ BillInput billType status total discount tax (fromGregorian 2024 1 1)

-- | LocationInput generator
instance Arbitrary LocationInput where
  arbitrary = do
    name <- suchThat (T.pack <$> arbitrary) (\n -> T.length n > 0 && T.length n <= 255)
    locType <- suchThat arbitrary (>= 0)
    pure $ LocationInput name locType

-- | OrderInput generator
instance Arbitrary OrderInput where
  arbitrary = do
    status <- suchThat arbitrary (>= 0)
    total <- arbitrary `suchThat` (>= 0)
    discount <- arbitrary `suchThat` (>= 0)
    tax <- arbitrary `suchThat` (>= 0)
    pure $ OrderInput status total discount tax (fromGregorian 2024 1 1)

-- | PaymentInput generator
instance Arbitrary PaymentInput where
  arbitrary = do
    billId <- suchThat arbitrary (> 0)
    amount <- arbitrary `suchThat` (> 0)
    payMethod <- suchThat arbitrary (>= 0)
    payStatus <- suchThat arbitrary (>= 0)
    pure $ PaymentInput billId amount payMethod payStatus (fromGregorian 2024 1 1)

-- | PriceInput generator
instance Arbitrary PriceInput where
  arbitrary = do
    goodsId <- suchThat arbitrary (> 0)
    priceType <- suchThat arbitrary (>= 0)
    price <- arbitrary `suchThat` (>= 0)
    currencyId <- suchThat arbitrary (> 0)
    pure $ PriceInput goodsId priceType price currencyId

-- | TaxInput generator
instance Arbitrary TaxInput where
  arbitrary = do
    name <- suchThat (T.pack <$> arbitrary) (\n -> T.length n > 0)
    rate <- suchThat arbitrary (\r -> r >= 0 && r <= 100)
    taxType <- suchThat arbitrary (>= 0)
    pure $ TaxInput name rate taxType

-- | CurrencyInput generator
instance Arbitrary CurrencyInput where
  arbitrary = do
    code <- suchThat (T.pack <$> arbitrary) (\c -> T.length c == 3)
    name <- suchThat (T.pack <$> arbitrary) (\n -> T.length n > 0)
    symbol <- suchThat (T.pack <$> arbitrary) (\n -> T.length n > 0)
    rate <- arbitrary `suchThat` (> 0)
    pure $ CurrencyInput code name symbol rate

-- | AccPlanInput generator
instance Arbitrary AccPlanInput where
  arbitrary = do
    code <- suchThat (T.pack <$> arbitrary) (\n -> T.length n > 0)
    name <- suchThat (T.pack <$> arbitrary) (\n -> T.length n > 0)
    accType <- suchThat arbitrary (\t -> t >= 0 && t <= 4)
    kind <- suchThat arbitrary (>= 0)
    pure $ AccPlanInput code name accType kind

-- | AccTurnInput generator
instance Arbitrary AccTurnInput where
  arbitrary = do
    dbtAccId <- suchThat arbitrary (> 0)
    crdAccId <- suchThat arbitrary (> 0)
    amount <- arbitrary `suchThat` (> 0)
    date <- fromGregorian <$> choose (2020, 2025) <*> choose (1, 12) <*> choose (1, 28)
    billId <- oneof [pure Nothing, Just <$> suchThat arbitrary (> 0)]
    pure $ AccTurnInput dbtAccId crdAccId amount date billId

spec_validationProperties :: Spec
spec_validationProperties = describe "Validation Properties" $ do
  -- INN validation
  prop "valid INN (10 digits) passes" $
    forAll (T.pack <$> suchThat arbitrary (\s -> length s == 10 && all (`elem` ['0' .. '9']) s)) $ \inn ->
      isValidINN inn `shouldBe` True

  prop "valid INN (12 digits) passes" $
    forAll (T.pack <$> suchThat arbitrary (\s -> length s == 12 && all (`elem` ['0' .. '9']) s)) $ \inn ->
      isValidINN inn `shouldBe` True

  prop "invalid INN fails" $
    forAll (T.pack <$> suchThat arbitrary (\s -> length s > 0 && length s /= 10 && length s /= 12)) $ \inn ->
      isValidINN inn `shouldBe` False

  -- KPP validation
  prop "valid KPP (9 digits) passes" $
    forAll (T.pack <$> suchThat arbitrary (\s -> length s == 9 && all (`elem` ['0' .. '9']) s)) $ \kpp ->
      isValidKPP kpp `shouldBe` True

  prop "invalid KPP fails" $
    forAll (T.pack <$> suchThat arbitrary (\s -> length s /= 9)) $ \kpp ->
      isValidKPP kpp `shouldBe` False

  -- Phone validation
  prop "valid phone (10+ digits) passes" $
    forAll (T.pack <$> suchThat arbitrary (\s -> length (filter (`elem` ['0' .. '9']) s) >= 10)) $ \phone ->
      isValidPhone phone `shouldBe` True

  -- Bill validation
  prop "valid BillInput passes" $
    forAll arbitrary $ \input ->
      case validateBillInput input of
        Right _ -> True
        Left _ -> False

  -- Goods validation
  prop "valid GoodsInput passes" $
    forAll arbitrary $ \input ->
      case validateGoodsInput input of
        Right _ -> True
        Left _ -> False

  -- Location validation
  prop "valid LocationInput passes" $
    forAll arbitrary $ \input ->
      case validateLocationInput input of
        Right _ -> True
        Left _ -> False

  -- Order validation
  prop "valid OrderInput passes" $
    forAll arbitrary $ \input ->
      case validateOrderInput input of
        Right _ -> True
        Left _ -> False

  -- Payment validation
  prop "valid PaymentInput passes" $
    forAll arbitrary $ \input ->
      case validatePaymentInput input of
        Right _ -> True
        Left _ -> False

  -- Price validation
  prop "valid PriceInput passes" $
    forAll arbitrary $ \input ->
      case validatePriceInput input of
        Right _ -> True
        Left _ -> False

  -- Tax validation
  prop "valid TaxInput passes" $
    forAll arbitrary $ \input ->
      case validateTaxInput input of
        Right _ -> True
        Left _ -> False

  -- Currency validation
  prop "valid CurrencyInput passes" $
    forAll arbitrary $ \input ->
      case validateCurrencyInput input of
        Right _ -> True
        Left _ -> False

  -- AccPlan validation
  prop "valid AccPlanInput passes" $
    forAll arbitrary $ \input ->
      case validateAccPlanInput input of
        Right _ -> True
        Left _ -> False

  -- AccTurn validation
  prop "valid AccTurnInput passes" $
    forAll arbitrary $ \input ->
      case validateAccTurnInput input of
        Right _ -> True
        Left _ -> False
