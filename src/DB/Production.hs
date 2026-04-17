{-# LANGUAGE OverloadedStrings #-}

module DB.Production
  ( listTechs,
    getTech,
    listResources,
    calcTechTime,
    calcTechCost,
    listWorkOrders,
    createWorkOrder,
    releaseWorkOrder,
    completeWorkOrder,
    listBOMForProduct,
    calcMaterialNeed,
    runMRPCalc,
    listProductionPlanSnapshots,
    logProductionPlan,
  )
where

import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (Day, UTCTime)
import Domain.Production (BOMEntry (..), MRPNeed (..), MRPPlanItem (..), ProductionPlanSnapshot (..), Tech (..), TechFilter (..), WorkOrder (..))
import Hasql.Pool (Pool)

listTechs :: Pool -> TechFilter -> IO [Tech]
listTechs _ _ = pure []

getTech :: Pool -> Int64 -> IO (Maybe Tech)
getTech _ _ = pure Nothing

listResources :: Pool -> IO [()]
listResources _ = pure []

calcTechTime :: Pool -> Int64 -> IO (Maybe Double)
calcTechTime _ _ = pure Nothing

calcTechCost :: Pool -> Int64 -> IO (Maybe Double)
calcTechCost _ _ = pure Nothing

listWorkOrders :: Pool -> IO [WorkOrder]
listWorkOrders _ = pure []

createWorkOrder :: Pool -> WorkOrder -> IO (Either Text Int64)
createWorkOrder _ _ = pure $ Right 0

releaseWorkOrder :: Pool -> Int64 -> IO (Either Text ())
releaseWorkOrder _ _ = pure $ Right ()

completeWorkOrder :: Pool -> Int64 -> IO (Either Text ())
completeWorkOrder _ _ = pure $ Right ()

listBOMForProduct :: Pool -> Int64 -> IO [BOMEntry]
listBOMForProduct _ _ = pure []

calcMaterialNeed :: Pool -> Int64 -> Double -> IO [MRPNeed]
calcMaterialNeed _ _ _ = pure []

runMRPCalc :: Pool -> Int64 -> IO [MRPPlanItem]
runMRPCalc _ _ = pure []

listProductionPlanSnapshots :: Pool -> IO [ProductionPlanSnapshot]
listProductionPlanSnapshots _ = pure []

logProductionPlan :: Pool -> ProductionPlanSnapshot -> IO (Either Text ())
logProductionPlan _ _ = pure $ Right ()
