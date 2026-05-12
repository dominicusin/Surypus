module Phase2Phase3.AccountingReadModelSpec where

import Data.Time (getCurrentTime)
import DAL.EventStore
import qualified Core.Accounting.ReadModel as RM
import Test.Hspec

main :: IO ()
main = hspec spec

spec :: Spec = do
  describe "Core.Accounting.ReadModel (US-3-2)" $ do

    it "replayAccountEvents returns Left with no events" $ do
      initEventStore
      result <- RM.replayAccountEvents 1
      case result of
        Left _ -> pure ()
        Right _ -> expectationFailure "should fail with no events"

    it "rebuildAccountBalance returns correct balance after account creation" $ do
      initEventStore
      _ <- createAccountCreatedEvent 1 "1010" "Cash" 1 1 1000.0 Nothing
      result <- RM.rebuildAccountBalance 1
      case result of
        Left err -> expectationFailure ("rebuildAccountBalance failed: " <> err)
        Right balance -> balance `shouldBe` 1000.0

    it "rebuildAccountBalance includes journal entry changes" $ do
      initEventStore
      _ <- createAccountCreatedEvent 1 "1010" "Cash" 1 1 1000.0 Nothing
      _ <- createJournalEntryEvent 1 1 1 2 500.0 (Just "Sale") Nothing
      result <- RM.rebuildAccountBalance 1
      case result of
        Left err -> expectationFailure ("rebuildAccountBalance failed: " <> err)
        Right balance -> balance `shouldBe` 1500.0

    it "rebuildAccountBalance handles multiple entries" $ do
      initEventStore
      _ <- createAccountCreatedEvent 1 "1010" "Cash" 1 1 1000.0 Nothing
      _ <- createJournalEntryEvent 1 1 1 2 500.0 (Just "Sale") Nothing
      _ <- createJournalEntryEvent 1 2 1 2 200.0 (Just "Service") Nothing
      _ <- createJournalEntryEvent 1 3 1 2 300.0 (Just "Refund") Nothing
      result <- RM.rebuildAccountBalance 1
      case result of
        Left err -> expectationFailure ("rebuildAccountBalance failed: " <> err)
        Right balance -> balance `shouldBe` 2000.0

    it "multiple accounts have independent balances" $ do
      initEventStore
      _ <- createAccountCreatedEvent 1 "1010" "Cash" 1 1 1000.0 Nothing
      _ <- createAccountCreatedEvent 2 "3010" "Capital" 3 1 100000.0 Nothing
      _ <- createJournalEntryEvent 1 1 1 2 500.0 (Just "Sale") Nothing
      _ <- createJournalEntryEvent 2 2 2 1 500.0 (Just "Purchase") Nothing
      bal1 <- RM.rebuildAccountBalance 1
      bal2 <- RM.rebuildAccountBalance 2
      case (bal1, bal2) of
        (Right b1, Right b2) -> do
          b1 `shouldBe` 1500.0
          b2 `shouldBe` 100500.0
        _ -> expectationFailure "balances should be Right"

    it "replayAccountEvents returns full AccountReadModel" $ do
      initEventStore
      _ <- createAccountCreatedEvent 1 "1010" "Cash" 1 1 1000.0 Nothing
      _ <- createJournalEntryEvent 1 1 1 2 500.0 (Just "Sale") Nothing
      result <- RM.replayAccountEvents 1
      case result of
        Left err -> expectationFailure ("replayAccountEvents failed: " <> err)
        Right arm -> do
          RM.armAccountId arm `shouldBe` 1
          RM.armCode arm `shouldBe` Just "1010"
          RM.armName arm `shouldBe` Just "Cash"
          RM.bsCurrentBalance (RM.armBalanceState arm) `shouldBe` 1500.0
          RM.bsEventCount (RM.armBalanceState arm) `shouldBe` 2

    it "getCurrentBalance matches rebuildAccountBalance" $ do
      initEventStore
      _ <- createAccountCreatedEvent 1 "1010" "Cash" 1 1 1000.0 Nothing
      _ <- createJournalEntryEvent 1 1 1 2 500.0 Nothing
      rbResult <- RM.rebuildAccountBalance 1
      cbResult <- RM.getCurrentBalance 1
      case (rbResult, cbResult) of
        (Right rb, Right cb) -> rb `shouldBe` cb
        _ -> expectationFailure "both should succeed"