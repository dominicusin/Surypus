module System.Transform where

import Control.Concurrent.STM (TVar, atomically, newTVarIO, readTVar, writeTVar)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import Data.Time.Clock (UTCTime, getCurrentTime)
import System.Validation (ValidationError, formatErrors)

-- | Transformation pipeline stage
data TransformStage a b = TransformStage
  { stageName :: Text,
    stageTransform :: a -> Either ValidationError b,
    stageNext :: Maybe (TransformStage b b),
    stageInput :: TVar [Either ValidationError a],
    stageOutput :: TVar [Either ValidationError b]
  }

-- | Transformation pipeline
data TransformPipeline a b = TransformPipeline
  { pipelineStages :: [TransformStage a b],
    pipelineInput :: TVar [Either ValidationError a],
    pipelineOutput :: TVar [Either ValidationError b],
    pipelineErrors :: TVar [(UTCTime, Text, [ValidationError])]
  }

-- | Initialize transformation pipeline
initTransformPipeline :: a -> IO (TransformPipeline a b)
initTransformPipeline _ = do
   inputTVar <- newTVarIO []
   outputTVar <- newTVarIO []
   errorsTVar <- newTVarIO []
   return $ TransformPipeline
      { pipelineStages = []
      , pipelineInput = inputTVar
      , pipelineOutput = outputTVar
      , pipelineErrors = errorsTVar
      }

-- | Add a transformation stage
addStage :: TransformStage a b -> TransformPipeline a b -> TransformPipeline a b
addStage stage pipeline =
  pipeline
    { pipelineStages = pipelineStages pipeline ++ [stage]
    }

-- | Execute transformation
executeTransform :: TransformPipeline a b -> a -> IO (Either [ValidationError] b)
executeTransform pipeline input = do
  -- Process through all stages
  result <- processStages (pipelineStages pipeline) (Right input)
  case result of
    Left errors -> do
      now <- getCurrentTime
      atomically $ do
        currentErrs <- readTVar (pipelineErrors pipeline)
        writeTVar (pipelineErrors pipeline) ((now, "transform_failed", errors) : currentErrs)
      return $ Left errors
    Right val -> return $ Right val
  where
    processStages [] acc = return acc
    processStages (stage : rest) acc = do
      newAcc <- traverse (stageTransform stage) acc
      processStages rest (Right newAcc)

-- | Get transformation errors
getTransformErrors :: TransformPipeline a b -> IO [(UTCTime, Text, [ValidationError])]
getTransformErrors pipeline = readTVarIO (pipelineErrors pipeline)

-- | Reset pipeline
resetPipeline :: TransformPipeline a b -> IO ()
resetPipeline pipeline = atomically $ do
  writeTVar (pipelineInput pipeline) []
  writeTVar (pipelineOutput pipeline) []
