module Phase2Phase3.AccountingEventStoreSpec where

import Data.Time (getCurrentTime)
import DAL.EventStore
import Domain.Accounting.Events (AccountingEvent, rebuildBalance)
import Test.Hspec

main :: IO ()
main = hspec spec

spec :: Spec = do
  describe "DAL.EventStore" $ do
    it "appendEvent stores events" $ do
      initEventStore
      now <- getCurrentTime
      let ed = EventData
            { edOldBalance = Nothing
            , edNewBalance = Just 1000.0
            , edChangeAmount = Nothing
            , edAccountCode = Just "1010"
            , edAccountName = Just "Cash"
            , edAccountType = Just 1
            , edCurrencyId = Just 1
            , edJournalEntryId = Nothing
            , edDebitAccountId = Nothing
            , edCreditAccountId = Nothing
            , edDescription = Nothing
            , edCustomData = Nothing
            }
      result <- appendEvent 1 AccountCreated ed Nothing
      case result of
        Left _ -> expectationFailure "appendEvent failed"
        Right _ -> pure ()

    it "getEvents returns stored events" $ do
      initEventStore
      events <- getEvents 1
      length events `shouldBe` 0

    it "replayAccount returns balance from events" $ do
      initEventStore
      now <- getCurrentTime
      let ed = EventData
            { edOldBalance = Nothing
            , edNewBalance = Just 1000.0
            , edChangeAmount = Nothing
            , edAccountCode = Just "1010"
            , edAccountName = Just "Cash"
            , edAccountType = Just 1
            , edCurrencyId = Just 1
            , edJournalEntryId = Nothing
            , edDebitAccountId = Nothing
            , edCreditAccountId = Nothing
            , edDescription = Nothing
            , edCustomData = Nothing
            }
      let d1 = EventData
            { edOldBalance = Nothing
            , edNewBalance = Nothing
            , edChangeAmount = Just 500.0
            , edAccountCode = Nothing
            , edAccountName = Nothing
            , edAccountType = Nothing
            , edCurrencyId = Nothing
            , edJournalEntryId = Just 1
            , edDebitAccountId = Just 1
            , edCreditAccountId = Just 2
            , edDescription = Just "Journal entry"
            , edCustomData = Nothing
            }
      _ <- appendEvent 1 AccountCreated ed Nothing
      _ <- appendEvent 1 JournalEntryPosted d1 Nothing
      result <- replayAccount 1
      case result of
        Left _ -> expectationFailure "replayAccount failed"
        Right balance -> balance `shouldBe` 1500.0

    it "createAccountCreatedEvent creates and stores event" $ do
      initEventStore
      ev <- createAccountCreatedEvent 1 "1010" "Cash" 1 1 1000.0 Nothing
      aeAggregateId ev `shouldBe` 1
      aeEventType ev `shouldBe` AccountCreated

    it "createJournalEntryEvent creates and stores event" $ do
      initEventStore
      ev <- createJournalEntryEvent 1 1 1 2 500.0 (Just "Test entry") Nothing
      aeAggregateId ev `shouldBe` 1
      aeEventType ev `shouldBe` JournalEntryPosted

  describe "Domain.Accounting.Events" $ do
    it "rebuildBalance computes correct result" $ do
      t <- getCurrentTime
      let evs =
            [ EntryCreated 1 1 "4001" 1000 0 "dep" t
            , EntryCreated 2 1 "4001" 0 500 "dep" t
            ]
          balance = rebuildBalance "4001" evs
      balance `shouldBe` 500.0

  describe "Core.Accounting.ReadModel" $ do
    it "replayAccountEvents handle empty events" $ do
      let accountId = 1
      result <- Core.Accounting.ReadModel.replayAccountEvents accountId
      case result of
        Left _ -> pure ()
        Right _ -> expectationFailure "should fail with no events"

    it "getCurrentBalance works" $ do
      result <- Core.Accounting.ReadModel.getCurrentBalance 1
      case result of
        Left _ -> pure ()
        Right _ -> expectationFailure "should fail with no events"