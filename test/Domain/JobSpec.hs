{-# LANGUAGE OverloadedStrings #-}

module Domain.JobSpec (spec_jobDomain) where

import Test.Hspec
import Test.QuickCheck
import Domain.Job
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time.Calendar (fromGregorian)
import Data.Time.Clock (UTCTime(..), secondsToDiffTime)
import Data.Either (isRight, isLeft)

spec_jobDomain :: Spec
spec_jobDomain = describe "Domain.Job" $ do
  it "parses statuses case-insensitively" $ do
    jobStatusFromText "Pending" `shouldBe` JobPending
    jobStatusFromText "RUNNING" `shouldBe` JobRunning
    jobStatusFromText "CancELLed" `shouldBe` JobCancelled

  it "validates a proper job request" $ do
    let req = JobRequest
          { jrCode = "ETL-IMPORT"
          , jrName = "Import товарных остатков"
          , jrType = "import"
          , jrPriority = 3
          , jrPayload = Just "{\"source\":\"legacy\"}"
          , jrScheduled = Just $ UTCTime (fromGregorian 2026 3 9) (secondsToDiffTime 0)
          }
    validateJobRequest req `shouldBe` Right req

  it "rejects empty mandatory fields" $ do
    let req = JobRequest "" "" "" 3 Nothing Nothing
    validateJobRequest req `shouldSatisfy` isLeft

  it "enforces priority range" $ do
    let req = JobRequest "code" "name" "type" 11 Nothing Nothing
    validateJobRequest req `shouldSatisfy` isLeft

  it "round-trips statuses via text" $ property $
    \status -> jobStatusFromText (jobStatusText (status :: JobStatus)) === status

  it "accepts validated requests created with arbitrary non-empty fields" $ property $
    \req -> isRight (validateJobRequest (withCleanText req))
  where
    withCleanText r =
      r
        { jrCode = T.strip (jrCode r)
        , jrName = T.strip (jrName r)
        , jrType = T.strip (jrType r)
        }

instance Arbitrary JobStatus where
  arbitrary = elements [JobPending, JobRunning, JobCompleted, JobFailed, JobCancelled]

instance Arbitrary JobRequest where
  arbitrary = JobRequest
    <$> genNonEmptyText
    <*> genNonEmptyText
    <*> genNonEmptyText
    <*> choose (1, 10)
    <*> arbitrary
    <*> pure Nothing

genNonEmptyText :: Gen Text
genNonEmptyText = T.pack <$> listOf1 (elements ['A'..'Z'])
