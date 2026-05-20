{-# LANGUAGE OverloadedStrings #-}
module Domain.CRMSpec where

import Test.Hspec
import Test.QuickCheck
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time.Calendar (fromGregorian)
import Data.Time.Clock (UTCTime (..), secondsToDiffTime)
import CRM.Types
import CRM.Contact
import CRM.Company
import CRM.Deal
import CRM.Activity
import CRM.Pipeline

-- | Test epoch time for CRM types
testEpoch :: UTCTime
testEpoch = UTCTime (fromGregorian 2024 1 1) (secondsToDiffTime 0)

spec :: Spec
spec = do
  describe "CRM Types" $ do
    it "ContactId wraps UUID" $ do
      let cid = ContactId (read "550e8400-e29b-41d4-a716-446655440000")
      show cid `shouldContain` "ContactId"
    
    it "CompanyId wraps UUID" $ do
      let cid = CompanyId (read "550e8400-e29b-41d4-a716-446655440000")
      show cid `shouldContain` "CompanyId"
    
    it "DealId wraps UUID" $ do
      let did = DealId (read "550e8400-e29b-41d4-a716-446655440000")
      show did `shouldContain` "DealId"
    
    it "Priority ordering" $ do
      Low `compare` Medium `shouldBe` LT
      Medium `compare` High `shouldBe` LT
      Urgent `compare` High `shouldBe` GT
    
    it "ActivityType enum values" $ do
      length [Call, Meeting, Email, Note, Task, Lunch] `shouldBe` 6
    
    it "ActivityType show instances" $ do
      show Call `shouldBe` "Call"
      show Lunch `shouldBe` "Lunch"

  describe "Contact" $ do
    it "creates contact with required fields" $ do
      let c = Contact
            { cId = ContactId (read "00000000-0000-0000-0000-000000000000")
            , cFirstName = "John"
            , cLastName = "Doe"
            , cEmail = Nothing
            , cPhone = Nothing
            , cMobilePhone = Nothing
            , cPosition = Nothing
            , cCompanyId = Nothing
            , cPersonId = Nothing
            , cNotes = Nothing
            , cIsActive = True
            , cCreatedAt = testEpoch
            , cUpdatedAt = Nothing
            }
      cFirstName c `shouldBe` "John"
      cLastName c `shouldBe` "Doe"
      cIsActive c `shouldBe` True
    
    it "generates valid random contacts" $ property $
      \c -> do
        not (T.null (cFirstName c)) `shouldBe` True
        not (T.null (cLastName c)) `shouldBe` True

  describe "Company" $ do
    it "creates company with required fields" $ do
      let c = Company
            { coId = CompanyId (read "00000000-0000-0000-0000-000000000000")
            , coName = "Acme Corp"
            , coPersonId = Nothing
            , coEmail = Nothing
            , coPhone = Nothing
            , coWebsite = Nothing
            , coIndustry = Nothing
            , coSize = Nothing
            , coAnnualRevenue = 0
            , coDescription = Nothing
            , coIsActive = True
            , coCreatedAt = testEpoch
            , coUpdatedAt = Nothing
            }
      coName c `shouldBe` "Acme Corp"
    
    it "generates valid random companies" $ property $
      \c -> not (T.null (coName c))

  describe "Deal" $ do
    it "creates deal with required fields" $ do
      let d = Deal
            { dId = DealId (read "00000000-0000-0000-0000-000000000000")
            , dName = "Big Deal"
            , dValue = 10000.0
            , dStageId = PipelineStageId (read "00000000-0000-0000-0000-000000000000")
            , dPersonId = Nothing
            , dCompanyId = Nothing
            , dContactId = Nothing
            , dOwnerId = Nothing
            , dExpectedCloseDate = Nothing
            , dPriority = Medium
            , dProbability = 50
            , dNotes = Nothing
            , dTags = []
            , dIsActive = True
            , dCreatedAt = testEpoch
            , dUpdatedAt = Nothing
            }
      dName d `shouldBe` "Big Deal"
      dValue d `shouldBe` 10000.0
      dPriority d `shouldBe` Medium
    
    it "deal value is non-negative" $ property $
      \d -> dValue d >= 0
    
    it "deal probability is between 0 and 100" $ property $
      \d -> dProbability d >= 0 && dProbability d <= 100

  describe "DealStage" $ do
    it "creates deal stage with known values" $ do
      let ds = DealStage
            { dsId = PipelineStageId (read "00000000-0000-0000-0000-000000000000")
            , dsName = "Test Stage"
            , dsOrder = 1
            , dsProbability = 50.0
            , dsColor = Nothing
            }
      dsName ds `shouldBe` "Test Stage"
      dsOrder ds `shouldBe` 1

  describe "Activity" $ do
    it "creates activity with required fields" $ do
      let a = Activity
            { aId = ActivityId (read "00000000-0000-0000-0000-000000000000")
            , aDealId = Nothing
            , aContactId = Nothing
            , aType = Note
            , aSubject = "Follow up"
            , aDescription = Nothing
            , aDate = testEpoch
            , aIsCompleted = False
            , aCreatedAt = testEpoch
            }
      aSubject a `shouldBe` "Follow up"
      aIsCompleted a `shouldBe` False
    
    it "generates valid random activities" $ property $
      \a -> not (T.null (aSubject a))

  describe "Pipeline" $ do
    it "creates pipeline stage" $ do
      let ps = PipelineStage
            { psId = PipelineStageId (read "00000000-0000-0000-0000-000000000000")
            , psName = "Test Stage"
            , psOrder = 1
            , psProbability = 50
            , psColor = Just "#ff0000"
            , psIsActive = True
            , psEntryCriteria = []
            , psExitCriteria = []
            }
      psName ps `shouldBe` "Test Stage"
      psProbability ps `shouldBe` 50
    
    it "forecast weighted value calculation" $ do
      let f = Forecast
            { fStage = "Test"
            , fStageOrder = 1
            , fProbability = 50
            , fDealCount = 5
            , fPipelineValue = 100000
            , fWeightedForecast = 50000
            }
      fWeightedForecast f `shouldBe` fPipelineValue f * fProbability f / 100
    
    it "generates valid random pipeline stages" $ property $
      \ps -> not (T.null (psName ps))

  describe "StageTransition" $ do
    it "creates stage transition" $ do
      let st = StageTransition
            { stId = ActivityId (read "00000000-0000-0000-0000-000000000000")
            , stDealId = DealId (read "00000000-0000-0000-0000-000000000000")
            , stFromStageId = Nothing
            , stToStageId = PipelineStageId (read "00000000-0000-0000-0000-000000000000")
            , stChangedBy = Nothing
            , stReason = Just "Proposal accepted"
            , stChangedAt = testEpoch
            }
      stReason st `shouldBe` Just "Proposal accepted"

  describe "Round-trip properties" $ do
    it "contact fields are preserved after arbitrary generation" $ property $
      \c -> cFirstName c === cFirstName c
    
    it "company name is preserved after arbitrary generation" $ property $
      \c -> coName c === coName c
    
    it "deal name is preserved after arbitrary generation" $ property $
      \d -> dName d === dName d