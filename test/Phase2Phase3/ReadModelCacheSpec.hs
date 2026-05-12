module Phase2Phase3.ReadModelCacheSpec where

import Data.Time (getCurrentTime, diffUTCTime)
import DAL.EventStore (initEventStore, createAccountCreatedEvent, createJournalEntryEvent)
import qualified Core.Accounting.Cache as C
import qualified Core.Accounting.ReadModel as RM
import System.Cache (CacheStats(..))
import Test.Hspec

main :: IO ()
main = hspec spec

spec :: Spec = do
  describe "Core.Accounting.Cache (US-3-3)" $ do

    it "getCachedBalance returns correct balance" $ do
      initEventStore
      cache <- C.mkReadModelCache
      _ <- createAccountCreatedEvent 1 "1010" "Cash" 1 1 1000.0 Nothing
      bal <- C.getCachedBalance cache 1
      bal `shouldBe` 1000.0

    it "cache hits return same value as replayed" $ do
      initEventStore
      cache <- C.mkReadModelCache
      _ <- createAccountCreatedEvent 1 "1010" "Cash" 1 1 1000.0 Nothing
      _ <- createJournalEntryEvent 1 1 1 2 500.0 (Just "Sale") Nothing
      cached <- C.getCachedBalance cache 1
      direct <- RM.rebuildAccountBalance 1
      case direct of
        Left _ -> expectationFailure "rebuildAccountBalance failed"
        Right d -> cached `shouldBe` d

    it "invalidateCache forces fresh fetch" $ do
      initEventStore
      cache <- C.mkReadModelCache
      _ <- createAccountCreatedEvent 1 "1010" "Cash" 1 1 1000.0 Nothing
      _ <- C.getCachedBalance cache 1
      _ <- createJournalEntryEvent 1 1 1 2 500.0 (Just "Sale") Nothing
      C.invalidateCache cache 1
      bal <- C.getCachedBalance cache 1
      bal `shouldBe` 1500.0

    it "cacheStats tracks hits" $ do
      initEventStore
      cache <- C.mkReadModelCache
      _ <- createAccountCreatedEvent 1 "1010" "Cash" 1 1 1000.0 Nothing
      _ <- C.getCachedBalance cache 1
      _ <- C.getCachedBalance cache 1
      stats <- C.cacheStats cache
      csHits stats `shouldSatisfy` (>= 1)

    it "multiple accounts cached independently" $ do
      initEventStore
      cache <- C.mkReadModelCache
      _ <- createAccountCreatedEvent 1 "1010" "Cash" 1 1 1000.0 Nothing
      _ <- createAccountCreatedEvent 2 "3010" "Capital" 3 1 100000.0 Nothing
      b1 <- C.getCachedBalance cache 1
      b2 <- C.getCachedBalance cache 2
      b1 `shouldBe` 1000.0
      b2 `shouldBe` 100000.0

    it "clearCache resets all entries" $ do
      initEventStore
      cache <- C.mkReadModelCache
      _ <- createAccountCreatedEvent 1 "1010" "Cash" 1 1 1000.0 Nothing
      _ <- C.getCachedBalance cache 1
      C.clearCache cache
      stats <- C.cacheStats cache
      csSize stats `shouldBe` 0