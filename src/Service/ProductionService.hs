{-# LANGUAGE OverloadedStrings #-}

module Service.ProductionService
  ( ProductionService (..),
    createProductionService,
    createTechCard,
    createWorkOrder,
    releaseWorkOrder,
    completeWorkOrder,
  )
where

import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (getCurrentTime)
import Hasql.Pool (Pool)

data ProductionService = ProductionService
  { psPool :: Pool
  }

createProductionService :: Pool -> IO ProductionService
createProductionService pool = do
  pure $ ProductionService {psPool = pool}

createTechCard :: ProductionService -> Text -> Int64 -> IO (Either Text Int64)
createTechCard _ _ _ = pure $ Right 0

createWorkOrder :: ProductionService -> Text -> Int64 -> Double -> IO (Either Text Int64)
createWorkOrder _ _ _ _ = pure $ Right 0

releaseWorkOrder :: ProductionService -> Int64 -> IO (Either Text ())
releaseWorkOrder _ _ = pure $ Right ()

completeWorkOrder :: ProductionService -> Int64 -> IO (Either Text ())
completeWorkOrder _ _ = pure $ Right ()
