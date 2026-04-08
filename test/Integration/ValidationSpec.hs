{-# LANGUAGE OverloadedStrings #-}

-- | Validation layer QuickCheck properties
module Integration.ValidationSpec
  ( spec_validationProperties,
  )
where

import DAL.Types
import Data.Coerce (coerce)
import Data.Int (Int16)
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
    Gen,
    Property,
    choose,
    forAll,
    oneof,
    suchThat,
  )

-- | PersonInput generator - matches DAL.Types
instance Arbitrary PersonInput where
  arbitrary = do
    code <- oneof [pure Nothing, Just . T.pack <$> suchThat (arbitrary :: Gen String) (\s -> length s > 0)]
    name <- suchThat (T.pack <$> arbitrary) (\n -> T.length n > 0 && T.length n <= 255)
    inn <- oneof [pure Nothing, Just . T.pack <$> suchThat (arbitrary :: Gen String) (\s -> length s == 10 || length s == 12)]
    kpp <- oneof [pure Nothing, Just . T.pack <$> suchThat (arbitrary :: Gen String) (\s -> length s == 9)]
    ptype <- suchThat arbitrary (>= 0)
    status <- suchThat arbitrary (>= 0)
    pure $ PersonInput code name inn kpp (toEnum ptype) (toEnum status)

-- | GoodsInput generator - matches DAL.Types
instance Arbitrary GoodsInput where
  arbitrary = do
    code <- oneof [pure Nothing, Just . T.pack <$> suchThat arbitrary (\s -> length s > 0)]
    name <- suchThat (T.pack <$> arbitrary) (\n -> T.length n > 0 && T.length n <= 255)
    barcode <- oneof [pure Nothing, Just . T.pack <$> suchThat arbitrary (\s -> length s > 0)]
    unitId <- suchThat arbitrary (> 0)
    parentId <- oneof [pure Nothing, Just <$> suchThat arbitrary (> 0)]
    pure $ GoodsInput code name barcode unitId parentId

-- | BillInput generator - matches DAL.Types
instance Arbitrary BillInput where
  arbitrary = do
    code <- oneof [pure Nothing, Just . T.pack <$> suchThat arbitrary (\s -> length s > 0)]
    billType <- suchThat arbitrary (>= 0)
    status <- suchThat arbitrary (>= 0)
    date <- fromGregorian <$> choose (2020, 2025) <*> choose (1, 12) <*> choose (1, 28)
    personId <- oneof [pure Nothing, Just <$> suchThat arbitrary (> 0)]
    locationId <- oneof [pure Nothing, Just <$> suchThat arbitrary (> 0)]
    total <- arbitrary
    discount <- arbitrary
    tax <- arbitrary
    pure $ BillInput code billType status date personId locationId total discount tax

-- | LocationInput generator - matches DAL.Types
instance Arbitrary LocationInput where
  arbitrary = do
    code <- oneof [pure Nothing, Just . T.pack <$> suchThat arbitrary (\s -> length s > 0)]
    name <- suchThat (T.pack <$> arbitrary) (\n -> T.length n > 0 && T.length n <= 255)
    locType <- suchThat arbitrary (>= 0)
    pure $ LocationInput code name locType

-- | OrderInput generator - matches DAL.Types
instance Arbitrary OrderInput where
  arbitrary = do
    code <- oneof [pure Nothing, Just . T.pack <$> suchThat arbitrary (\s -> length s > 0)]
    name <- oneof [pure Nothing, Just . T.pack <$> suchThat arbitrary (\s -> length s > 0)]
    date <- fromGregorian <$> choose (2020, 2025) <*> choose (1, 12) <*> choose (1, 28)
    personId <- oneof [pure Nothing, Just <$> suchThat arbitrary (> 0)]
    locationId <- oneof [pure Nothing, Just <$> suchThat arbitrary (> 0)]
    status <- suchThat arbitrary (>= 0)
    total <- arbitrary
    discount <- arbitrary
    tax <- arbitrary
    pure $ OrderInput code name date personId locationId status total discount tax

-- | PaymentInput generator - matches DAL.Types
instance Arbitrary PaymentInput where
  arbitrary = do
    billId <- suchThat arbitrary (> 0)
    payDate <- fromGregorian <$> choose (2020, 2025) <*> choose (1, 12) <*> choose (1, 28)
    amount <- arbitrary `suchThat` (> 0)
    payMethod <- suchThat arbitrary (>= 0)
    payStatus <- suchThat arbitrary (>= 0)
    pure $ PaymentInput billId payDate amount payMethod payStatus

-- | PriceInput generator - matches DAL.Types
instance Arbitrary PriceInput where
  arbitrary = do
    goodsId <- suchThat arbitrary (> 0)
    priceType <- suchThat arbitrary (>= 0)
    price <- arbitrary
    currencyId <- suchThat arbitrary (> 0)
    fromDate <- fromGregorian <$> choose (2020, 2025) <*> choose (1, 12) <*> choose (1, 28)
    toDate <- oneof [pure Nothing, Just <$> (fromGregorian <$> choose (2025, 2030) <*> choose (1, 12) <*> choose (1, 28))]
    pure $ PriceInput goodsId priceType price currencyId fromDate toDate

-- | TaxInput generator
instance Arbitrary TaxInput where
  arbitrary = do
    name <- suchThat (T.pack <$> arbitrary) (\n -> T.length n > 0)
    rate <- suchThat arbitrary (\r -> r >= 0 && r <= 100)
    taxType <- suchThat arbitrary (>= 0)
    included <- arbitrary
    pure $ TaxInput name rate taxType included

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
    parentCode <- oneof [pure Nothing, Just . T.pack <$> suchThat (arbitrary :: Gen String) (\s -> length s > 0)]
    kind <- suchThat arbitrary (>= 0)
    isAnalytical <- arbitrary
    pure $ AccPlanInput code name accType parentCode kind isAnalytical

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
