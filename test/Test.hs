-- ============================================================================
-- SURYPUS TEST SUITE
-- ============================================================================

{-# LANGUAGE OverloadedStrings #-}

module Main where

import Test.Hspec
import APIServer
import DB
import Core.Document.Types
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (fromGregorian)
import Data.Either (isLeft, isRight)
import Domain.Inventory
import qualified Domain.Person as DomainPerson
import qualified Domain.DocumentSpec as DocumentSpec
import qualified Domain.HRSpec as HRSpec
import qualified Domain.HRPropertySpec as HRPropertySpec
import qualified Domain.JobSpec as JobSpec
import qualified Domain.ProductionSpec as ProductionSpec

-- ============================================================================
-- MAIN
-- ============================================================================

main :: IO ()
main = hspec $ do
    describe "Database Tests" $ do
        it "Database can be created" $ do
            db <- newDatabase
            persons <- queryPersons db 10 0
            length persons `shouldBe` 3

        it "Query persons returns test data" $ do
            db <- newDatabase
            persons <- queryPersons db 10 0
            case persons of
                (p:_) -> pName p `shouldBe` "Company A"
                [] -> expectationFailure "No persons returned"

        it "Query goods returns test data" $ do
            db <- newDatabase
            goods <- queryGoods db 10 0
            length goods `shouldBe` 3

        it "Query locations returns test data" $ do
            db <- newDatabase
            locations <- queryLocations db 10 0
            length locations `shouldBe` 3

        it "Query stock returns test data" $ do
            db <- newDatabase
            stock <- queryStock db Nothing Nothing
            length stock `shouldBe` 3

    describe "Data Types Tests" $ do
        it "Person can be created with valid fields" $ do
            let p = Person 
                    { pId = Just 1
                    , pCode = Just "001"
                    , pName = "Test Company"
                    , pINN = Just "1234567890"
                    , pKPP = Just "123456789"
                    , pPersonKind = 1
                    , pStatus = 0
                    , pPhone = Nothing
                    , pEmail = Nothing
                    , pAddress = Nothing
                    , pCreditLimit = 100000
                    , pDiscount = 5
                    }
            pName p `shouldBe` "Test Company"
            pId p `shouldBe` Just 1

        it "Goods can be created with valid fields" $ do
            let g = Goods
                    { gId = Just 1
                    , gCode = Just "001"
                    , gName = "Test Product"
                    , gBarcode = Just "1234567890123"
                    , gUnitId = 1
                    , gParentId = Nothing
                    , gGoodsType = 1
                    , gTaxId = Just 1
                    , gBrandId = Nothing
                    , gStatus = 0
                    , gMinStock = 10
                    , gMaxStock = Nothing
                    , gWeight = Nothing
                    , gVolume = Nothing
                    }
            gName g `shouldBe` "Test Product"
            gId g `shouldBe` Just 1

        it "Location can be created with valid fields" $ do
            let l = Location
                    { lId = Just 1
                    , lCode = Just "WH-01"
                    , lName = "Main Warehouse"
                    , lLocationType = 1
                    , lAddress = Nothing
                    , lStatus = 0
                    , lCapacity = Just 1000
                    , lParentId = Nothing
                    }
            lName l `shouldBe` "Main Warehouse"
            lId l `shouldBe` Just 1

        it "Stock can be created with valid fields" $ do
            let s = Stock
                    { sId = Just 1
                    , sGoodsId = 1
                    , sLocationId = 1
                    , sQtty = 100
                    , sCost = 100.0
                    , sPrice = 150.0
                    , sBatch = Just "BATCH-001"
                    }
            sQtty s `shouldBe` 100
            sCost s `shouldBe` 100.0

    describe "Domain.Inventory" $ do
        let line1 = InventoryLine 1 1 1 1 Nothing 10 12 2 200 100 0
            line2 = InventoryLine 2 1 2 2 Nothing 20 18 (-2) (-180) 90 0
            summary = inventorySummary [line1, line2]

        it "computes inventory diffs" $ do
            inventoryLineDiff 10 15 `shouldBe` 5
            inventoryLineResult line1 `shouldBe` IR_Overage
            inventoryLineResult line2 `shouldBe` IR_Shortage

        it "aggregates diff summary" $ do
            isSummaryDiff summary `shouldBe` 0
            isSummarySurplus summary `shouldBe` 2
            isSummaryShortage summary `shouldBe` 2
            isSummarySurplusCount summary `shouldBe` 1
            isSummaryShortageCount summary `shouldBe` 1

        it "validates inputs" $ do
            let docInput = InventoryDocumentInput "INV-001" (fromGregorian 2026 5 10) 1 Nothing (Just 1)
            validateInventoryDocumentInput docInput `shouldSatisfy` isRight
            validateInventoryDocumentInput docInput { idiCode = "" } `shouldSatisfy` isLeft

            let lineInput = InventoryLineInput 1 1 1 Nothing 5 10 100
            validateInventoryLineInput lineInput `shouldSatisfy` isRight
            validateInventoryLineInput lineInput { iliActualQtty = -1 } `shouldSatisfy` isLeft

    describe "Domain.Person validation" $ do
        let basePerson = DomainPerson.Person
                { DomainPerson.personId = Nothing
                , DomainPerson.personCode = Just "V001"
                , DomainPerson.personName = "Valid Person"
                , DomainPerson.personINN = Just "1234567890"
                , DomainPerson.personKPP = Just "123456789"
                , DomainPerson.personKind = 1
                , DomainPerson.personStatus = 0
                , DomainPerson.personPhone = Just "+78005553535"
                , DomainPerson.personEmail = Just "info@example.com"
                , DomainPerson.personAddress = Just "Lenin St"
                , DomainPerson.personCredit = 1000
                , DomainPerson.personDiscount = 5
                }

        it "accepts valid INN and KPP" $ do
            DomainPerson.validatePerson basePerson `shouldSatisfy` isRight

        it "rejects invalid INN formats" $ do
            let invalidINN = basePerson { DomainPerson.personINN = Just "ABC123" }
            DomainPerson.validatePerson invalidINN `shouldSatisfy` isLeft

        it "rejects invalid KPP formats" $ do
            let invalidKPP = basePerson { DomainPerson.personKPP = Just "XYZ" }
            DomainPerson.validatePerson invalidKPP `shouldSatisfy` isLeft

        let commonAddressInput = DomainPerson.PersonAddressInput
                { DomainPerson.paiType = 0
                , DomainPerson.paiCountryId = Nothing
                , DomainPerson.paiRegionId = Nothing
                , DomainPerson.paiDistrict = Nothing
                , DomainPerson.paiCity = Just "City"
                , DomainPerson.paiTown = Just "Town"
                , DomainPerson.paiStreet = Just "Street"
                , DomainPerson.paiHouse = Just "1"
                , DomainPerson.paiFlat = Nothing
                , DomainPerson.paiZip = Just "123456"
                , DomainPerson.paiIsDefault = True
                }

        it "rejects address without street or town" $ do
            let brokenInput = commonAddressInput { DomainPerson.paiStreet = Nothing, DomainPerson.paiTown = Nothing }
            let address = DomainPerson.mkPersonAddress 1 Nothing brokenInput
            DomainPerson.validatePersonAddress address `shouldSatisfy` isLeft

        it "validates contact channels" $ do
            let contactInput = DomainPerson.PersonContactInput
                    { DomainPerson.picPhone = Nothing
                    , DomainPerson.picPhoneAdd = Nothing
                    , DomainPerson.picEmail = Just "contact@company.com"
                    , DomainPerson.picEmailAdd = Nothing
                    , DomainPerson.picWebsite = Nothing
                    , DomainPerson.picFax = Nothing
                    , DomainPerson.picTelegram = Nothing
                    , DomainPerson.picWhatsapp = Nothing
                    , DomainPerson.picIsDefault = True
                    }
            let contact = DomainPerson.mkPersonContact 1 Nothing contactInput
            DomainPerson.validatePersonContact contact `shouldSatisfy` isRight

        it "rejects bank accounts with invalid BIK" $ do
            let badBankInput = DomainPerson.PersonBankAccountInput
                    { DomainPerson.pbiBankName = "Bank"
                    , DomainPerson.pbiBankBIK = "123"
                    , DomainPerson.pbiAccount = T.replicate 20 "1"
                    , DomainPerson.pbiCorrAccount = Nothing
                    , DomainPerson.pbiIsDefault = False
                    }
            let bank = DomainPerson.mkPersonBankAccount 1 Nothing badBankInput
            DomainPerson.validatePersonBankAccount bank `shouldSatisfy` isLeft

    describe "Document types" $ do
        let sampleDate = fromGregorian 2025 1 1
        it "accepts valid register payloads" $ do
            let reg = DocumentRegister
                    { drId = Nothing
                    , drPersonId = 1
                    , drTypeId = 1
                    , drSeries = Just "A"
                    , drNumber = "001"
                    , drIssueDate = sampleDate
                    , drExpiryDate = Just sampleDate
                    , drIssuer = Just "Authority"
                    , drFlags = 0
                    , drAutoNumber = Nothing
                    }
            validateDocumentRegister reg `shouldBe` Right reg

        it "rejects registers with empty numbers" $ do
            let reg = DocumentRegister
                    { drId = Nothing
                    , drPersonId = 1
                    , drTypeId = 1
                    , drSeries = Nothing
                    , drNumber = ""
                    , drIssueDate = sampleDate
                    , drExpiryDate = Just sampleDate
                    , drIssuer = Nothing
                    , drFlags = 0
                    , drAutoNumber = Nothing
                    }
            validateDocumentRegister reg `shouldSatisfy` isLeft

        it "allows empty numbers when auto-numbering is enabled" $ do
            let reg = DocumentRegister
                    { drId = Nothing
                    , drPersonId = 1
                    , drTypeId = 1
                    , drSeries = Nothing
                    , drNumber = ""
                    , drIssueDate = sampleDate
                    , drExpiryDate = Just sampleDate
                    , drIssuer = Nothing
                    , drFlags = 0
                    , drAutoNumber = Just True
                    }
            validateDocumentRegister reg `shouldBe` Right reg

        it "rejects registers where expiry predates issue" $ do
            let reg = DocumentRegister
                    { drId = Nothing
                    , drPersonId = 1
                    , drTypeId = 1
                    , drSeries = Nothing
                    , drNumber = "001"
                    , drIssueDate = sampleDate
                    , drExpiryDate = Just (fromGregorian 2024 12 31)
                    , drIssuer = Nothing
                    , drFlags = 0
                    , drAutoNumber = Nothing
                    }
            validateDocumentRegister reg `shouldSatisfy` isLeft

        it "enforces counter prefix length" $ do
            let counter = DocumentOpCounter
                    { docCounterId = 1
                    , docCounterName = "Billing"
                    , docCounterOpKindId = 1
                    , docCounterPrefix = Just "PREFIX"
                    , docCounterFlags = 0
                    }
            validateDocumentOpCounter counter `shouldBe` Right counter

        it "rejects counter prefixes exceeding 16 chars" $ do
            let counter = DocumentOpCounter
                    { docCounterId = 1
                    , docCounterName = "Billing"
                    , docCounterOpKindId = 1
                    , docCounterPrefix = Just "THIS-IS-WAY-TOO-LONG"
                    , docCounterFlags = 0
                    }
            validateDocumentOpCounter counter `shouldSatisfy` isLeft

        it "rejects register types with empty names" $ do
            let drt = DocumentRegisterType
                    { drtId = Nothing
                    , drtName = ""
                    , drtCode = Just "REG"
                    , drtFlags = 0
                    }
            validateDocumentRegisterType drt `shouldSatisfy` isLeft

        it "rejects register type codes longer than 32 characters" $ do
            let drt = DocumentRegisterType
                    { drtId = Nothing
                    , drtName = "Passport"
                    , drtCode = Just (T.replicate 33 "X")
                    , drtFlags = 0
                    }
            validateDocumentRegisterType drt `shouldSatisfy` isLeft

    DocumentSpec.spec_documentStatus
    HRSpec.spec
    HRPropertySpec.spec_salaryProperties
    ProductionSpec.spec
    JobSpec.spec_jobDomain
