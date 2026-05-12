{-# LANGUAGE OverloadedStrings #-}

module DAL.EventStoreSpec where

import DAL.EventStore
import Data.Aeson (Value (..))
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Hasql.Pool (Pool)
import Test.Hspec

spec :: Pool -> Spec
spec pool = do
  describe "DAL.EventStore" $ do
    it "can append and retrieve events" $ do
      let aggId = 1001 :: Int64
          aggType = "test-aggregate" :: Text
      
      -- Append an event
      res1 <- appendEvent pool aggId aggType "TestEvent" 1 (String "test-data") Nothing 1
      res1 `shouldBe` Right ()
      
      -- Get events
      res2 <- getEvents pool aggId aggType
      case res2 of
        Left err -> expectationFailure $ T.unpack err
        Right events -> do
          length events `shouldSatisfy` (> 0)
          let ev = head events
          eventAggregateId ev `shouldBe` aggId
          eventAggregateType ev `shouldBe` aggType
          eventEventType ev `shouldBe` "TestEvent"
          eventSequenceNumber ev `shouldBe` 1

    it "can get events starting from a sequence number" $ do
      let aggId = 1002 :: Int64
          aggType = "test-aggregate" :: Text
      
      _ <- appendEvent pool aggId aggType "Event1" 1 (String "data1") Nothing 1
      _ <- appendEvent pool aggId aggType "Event2" 1 (String "data2") Nothing 2
      _ <- appendEvent pool aggId aggType "Event3" 1 (String "data3") Nothing 3
      
      res <- getEventsFrom pool aggId aggType 2
      case res of
        Left err -> expectationFailure $ T.unpack err
        Right events -> do
          length events `shouldBe` 2
          eventSequenceNumber (head events) `shouldBe` 2
          eventSequenceNumber (events !! 1) `shouldBe` 3

    it "can get latest sequence number" $ do
      let aggId = 1003 :: Int64
          aggType = "test-aggregate" :: Text
      
      _ <- appendEvent pool aggId aggType "Event1" 1 (String "data1") Nothing 1
      _ <- appendEvent pool aggId aggType "Event2" 1 (String "data2") Nothing 5
      
      res <- getLatestSequence pool aggId aggType
      res `shouldBe` Right 5

    it "returns 0 for latest sequence when no events exist" $ do
      res <- getLatestSequence pool 9999 "non-existent"
      res `shouldBe` Right 0
