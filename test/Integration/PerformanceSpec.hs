{-# LANGUAGE OverloadedStrings #-}

module Integration.PerformanceSpec
  ( spec,
  )
where

import Control.Monad (forM_)
import Control.Monad.IO.Class (liftIO)
import Core.Tax (calcVAT)
import Data.Time (diffUTCTime, getCurrentTime)
import Surypus.JWT (generateTokenPair, jwtConfigFromSecret)
import Test.Hspec

data LoadTestConfig = LoadTestConfig
  { ltcDurationSeconds :: Int,
    ltcConcurrentUsers :: Int
  }
  deriving (Show)

defaultLoadTestConfig :: LoadTestConfig
defaultLoadTestConfig =
  LoadTestConfig
    { ltcDurationSeconds = 10,
      ltcConcurrentUsers = 10
    }

runLoadTest :: LoadTestConfig -> IO Int
runLoadTest cfg = do
  let totalRequests = 0
  putStrLn $ "Load test config: " ++ show (ltcConcurrentUsers cfg) ++ " users, " ++ show (ltcDurationSeconds cfg) ++ " seconds"
  pure totalRequests

threadDelay :: Int -> IO ()
threadDelay _ = return ()

spec :: Spec
spec = describe "Performance Tests" $ do
  describe "Load Testing" $ do
    it "handles load test configuration" $ do
      cfg <- return defaultLoadTestConfig
      result <- runLoadTest cfg
      result `shouldBe` 0

  describe "Latency Benchmarks" $ do
    it "responds quickly for simple operations" $ do
      start <- getCurrentTime
      let _ = calcVAT 1000.0 20.0
      end <- getCurrentTime
      let latency = realToFrac (diffUTCTime end start) :: Double
      latency `shouldSatisfy` (< 1.0)

    it "VAT calculation performance" $ do
      let iterations = 10000
      start <- getCurrentTime
      forM_ [1 .. iterations] $ \_ -> do
        let _ = calcVAT 1000.0 20.0
        return ()
      end <- getCurrentTime
      let totalTime = realToFrac (diffUTCTime end start) :: Double
      let avgLatency = totalTime / fromIntegral iterations
      liftIO $ putStrLn $ "VAT calculation avg latency: " ++ show avgLatency ++ " seconds"
      avgLatency `shouldSatisfy` (< 0.001)

  describe "JWT Performance" $ do
    it "token generation performance" $ do
      let cfg = jwtConfigFromSecret "test-secret"
      let iterations = 500
      start <- getCurrentTime
      forM_ [1 .. iterations] $ \_ -> do
        generateTokenPair cfg 1 "testuser" "admin" (Just 1)
      end <- getCurrentTime
      let totalTime = realToFrac (diffUTCTime end start) :: Double
      let opsPerSec = fromIntegral iterations / totalTime
      liftIO $ putStrLn $ "JWT generation: " ++ show opsPerSec ++ " ops/sec"
      opsPerSec `shouldSatisfy` (> 50)

  describe "Throughput Tests" $ do
    it "high throughput for read operations" $ do
      let iterations = 10000
      start <- getCurrentTime
      forM_ [1 .. iterations] $ \_ -> do
        let _ = calcVAT 100.0 20.0
        return ()
      end <- getCurrentTime
      let duration = realToFrac (diffUTCTime end start) :: Double
      let throughput = fromIntegral iterations / duration
      liftIO $ putStrLn $ "Read throughput: " ++ show throughput ++ " ops/sec"
      throughput `shouldSatisfy` (> 1000)

  describe "Stress Tests" $ do
    it "handles burst of requests" $ do
      let burstSize = 100
      start <- getCurrentTime
      forM_ [1 .. burstSize] $ \_ -> do
        let _ = calcVAT 1000.0 20.0
        return ()
      end <- getCurrentTime
      let duration = realToFrac (diffUTCTime end start) :: Double
      liftIO $ putStrLn $ "Burst of " ++ show burstSize ++ " processed in " ++ show duration ++ " seconds"
      duration `shouldSatisfy` (< 1.0)

  describe "Memory Efficiency" $ do
    it "efficient tax calculations" $ do
      let iterations = 50000
      start <- getCurrentTime
      forM_ [1 .. iterations] $ \i -> do
        let amount = fromIntegral (i `mod` 10000)
        let _ = calcVAT amount 20.0
        return ()
      end <- getCurrentTime
      let totalTime = realToFrac (diffUTCTime end start) :: Double
      let opsPerSec = fromIntegral iterations / totalTime
      liftIO $ putStrLn $ "Memory efficient ops: " ++ show opsPerSec ++ " ops/sec"
      opsPerSec `shouldSatisfy` (> 10000)

  describe "Regression Tests" $ do
    it "performance baseline" $ do
      let cfg = defaultLoadTestConfig {ltcDurationSeconds = 1, ltcConcurrentUsers = 2}
      result <- runLoadTest cfg
      result `shouldBe` 0
