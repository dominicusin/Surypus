{-# LANGUAGE OverloadedStrings #-}

-- | Tests for HR.Person module
module HR.PersonSpec (spec) where

import Test.Hspec
import Test.Hspec.QuickCheck
import Test.QuickCheck
import Data.Time (fromGregorian)
import Data.Text (Text)
import qualified Data.Text as T

import HR.Person

spec :: Spec
spec = do
  describe "HR.Person - Person Management" $ do

    describe "Person Type" $ do
      it "should create person with valid data" $ do
        let day = fromGregorian 2024 1 1
        case createPerson 1 "P001" "Test Company" PKCompany (Just "1234567890") (Just "123456789") day of
          Right p -> do
            pId p `shouldBe` 1
            pCode p `shouldBe` "P001"
            pName p `shouldBe` "Test Company"
            pPersonKindId p `shouldBe` PKCompany
            pStatusId p `shouldBe` PSActive
            pIsActive p `shouldBe` True
          Left err -> fail $ "Should create person: " ++ T.unpack err

    describe "PersonKind" $ do
      it "should have all kind values" $ do
        [PKCompany, PKIndividual, PKEntrepreneur] `shouldBe`
          [minBound .. maxBound] :: [PersonKind]

    describe "PersonStatus" $ do
      it "should have all status values" $ do
        [PSActive, PSInactive, PSBlocked, PSDeleted] `shouldBe`
          [minBound .. maxBound] :: [PersonStatus]

    describe "INN Validation" $ do
      it "should accept valid 10-digit INN" $ do
        validateINN "1234567890" `shouldBe` True

      it "should accept valid 12-digit INN" $ do
        validateINN "123456789012" `shouldBe` True

      it "should reject empty INN" $ do
        validateINN "" `shouldBe` False

      it "should reject invalid length INN" $ do
        validateINN "123456789" `shouldBe` False
        validateINN "1234567890123" `shouldBe` False

      it "should reject non-numeric INN" $ do
        validateINN "123456789A" `shouldBe` False
        validateINN "12345678A0" `shouldBe` False

    describe "KPP Validation" $ do
      it "should accept valid 9-digit KPP" $ do
        validateKPP "123456789" `shouldBe` True

      it "should reject empty KPP" $ do
        validateKPP "" `shouldBe` False

      it "should reject invalid length KPP" $ do
        validateKPP "12345678" `shouldBe` False
        validateKPP "1234567890" `shouldBe` False

      it "should reject non-numeric KPP" $ do
        validateKPP "12345678A" `shouldBe` False

    describe "Person Creation" $ do
      it "should fail on empty code" $ do
        let day = fromGregorian 2024 1 1
        createPerson 1 "" "Name" PKCompany Nothing Nothing day `shouldBe`
          Left "Code cannot be empty"

      it "should fail on empty name" $ do
        let day = fromGregorian 2024 1 1
        createPerson 1 "P001" "" PKCompany Nothing Nothing day `shouldBe`
          Left "Name cannot be empty"

      it "should fail on invalid INN" $ do
        let day = fromGregorian 2024 1 1
        createPerson 1 "P001" "Name" PKCompany (Just "123") Nothing day `shouldBe`
          Left "Invalid INN format"

      it "should fail on invalid KPP" $ do
        let day = fromGregorian 2024 1 1
        createPerson 1 "P001" "Name" PKCompany (Just "1234567890") (Just "12345") day `shouldBe`
          Left "Invalid KPP format"

      it "should create person with optional fields" $ do
        let day = fromGregorian 2024 1 1
        case createPerson 1 "P001" "Name" PKIndividual Nothing Nothing day of
          Right p -> do
            pINN p `shouldBe` Nothing
            pKPP p `shouldBe` Nothing
          Left err -> fail $ "Should create: " ++ T.unpack err

    describe "Person Status Operations" $ do
      it "should update person status" $ do
        let day = fromGregorian 2024 1 1
        case createPerson 1 "P001" "Name" PKCompany Nothing Nothing day of
          Right p -> do
            let updated = updatePersonStatus p PSBlocked
            pStatusId updated `shouldBe` PSBlocked
          Left err -> fail $ "Setup failed: " ++ T.unpack err

      it "should deactivate person" $ do
        let day = fromGregorian 2024 1 1
        case createPerson 1 "P001" "Name" PKCompany Nothing Nothing day of
          Right p -> do
            let deact = deactivatePerson p
            pStatusId deact `shouldBe` PSInactive
            pIsActive deact `shouldBe` False
          Left err -> fail $ "Setup failed: " ++ T.unpack err

      it "should reactivate person" $ do
        let day = fromGregorian 2024 1 1
        case createPerson 1 "P001" "Name" PKCompany Nothing Nothing day of
          Right p -> do
            let deact = deactivatePerson p
            let react = reactivatePerson deact
            pStatusId react `shouldBe` PSActive
            pIsActive react `shouldBe` True
          Left err -> fail $ "Setup failed: " ++ T.unpack err

      it "should block person" $ do
        let day = fromGregorian 2024 1 1
        case createPerson 1 "P001" "Name" PKCompany Nothing Nothing day of
          Right p -> do
            let blocked = blockPerson p
            pStatusId blocked `shouldBe` PSBlocked
            pIsActive blocked `shouldBe` False
          Left err -> fail $ "Setup failed: " ++ T.unpack err

      it "should soft delete person" $ do
        let day = fromGregorian 2024 1 1
        case createPerson 1 "P001" "Name" PKCompany Nothing Nothing day of
          Right p -> do
            let deleted = deletePerson p
            pStatusId deleted `shouldBe` PSDeleted
            pIsActive deleted `shouldBe` False
          Left err -> fail $ "Setup failed: " ++ T.unpack err

    describe "Person Summary" $ do
      it "should create summary from person" $ do
        let day = fromGregorian 2024 1 1
        case createPerson 1 "P001" "Test Name" PKCompany Nothing Nothing day of
          Right p -> do
            let summary = personSummary p
            psId summary `shouldBe` 1
            psCode summary `shouldBe` "P001"
            psName summary `shouldBe` "Test Name"
            psKind summary `shouldBe` PKCompany
            psStatus summary `shouldBe` PSActive
            psIsActive summary `shouldBe` True
          Left err -> fail $ "Setup failed: " ++ T.unpack err

    describe "Person Kinds" $ do
      it "should handle company kind" $ do
        let day = fromGregorian 2024 1 1
        case createPerson 1 "P001" "Company" PKCompany (Just "1234567890") (Just "123456789") day of
          Right p -> pPersonKindId p `shouldBe` PKCompany
          Left err -> fail $ "Setup failed: " ++ T.unpack err

      it "should handle individual kind" $ do
        let day = fromGregorian 2024 1 1
        case createPerson 1 "P001" "Individual" PKIndividual Nothing Nothing day of
          Right p -> pPersonKindId p `shouldBe` PKIndividual
          Left err -> fail $ "Setup failed: " ++ T.unpack err

      it "should handle entrepreneur kind" $ do
        let day = fromGregorian 2024 1 1
        case createPerson 1 "P001" "Entrepreneur" PKEntrepreneur (Just "1234567890") Nothing day of
          Right p -> pPersonKindId p `shouldBe` PKEntrepreneur
          Left err -> fail $ "Setup failed: " ++ T.unpack err

    describe "Person Properties" $ do
      it "should truncate short name to 20 chars" $ do
        let day = fromGregorian 2024 1 1
        case createPerson 1 "P001" (T.replicate 50 "A") PKCompany Nothing Nothing day of
          Right p -> T.length (pShortName p) `shouldBe` 20
          Left err -> fail $ "Setup failed: " ++ T.unpack err

      it "should set full name equal to name on creation" $ do
        let day = fromGregorian 2024 1 1
        case createPerson 1 "P001" "Test Name" PKCompany Nothing Nothing day of
          Right p -> pFullName p `shouldBe` pName p
          Left err -> fail $ "Setup failed: " ++ T.unpack err

      it "should set register date" $ do
        let day = fromGregorian 2024 5 15
        case createPerson 1 "P001" "Name" PKCompany Nothing Nothing day of
          Right p -> pRegisterDate p `shouldBe` day
          Left err -> fail $ "Setup failed: " ++ T.unpack err
