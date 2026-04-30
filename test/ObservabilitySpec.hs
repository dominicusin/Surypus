{-# LANGUAGE OverloadedStrings #-}
module ObservabilitySpec (spec) where

import Test.Hspec
import qualified Surypus.Domain.Observability.API as OAPI
import qualified Surypus.Domain.Observability.Types as OT

spec :: Spec
spec = do
  describe "Observability" $ do
    it "provides sample metrics" $ do
      OAPI.getSampleMetrics `shouldBe` [OT.Latency 0.0, OT.Backlog 0, OT.Throughput 0]
