-- | Production service layer - Business logic for production module
module Production.Service
  ( releaseWorkOrder
  , completeWorkOrder
  , createTechCard
  , createTechLine
  ) where

import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (UTCTime)
import qualified Data.Text as T
import Production.Types
import qualified DAL.Production as DAL

-- | Release a work order for production
-- Validates that the work order can be released and updates status
releaseWorkOrder :: Int64 -> UTCTime -> Text -> IO (Either Text WorkOrder)
releaseWorkOrder woId releaseTime userId = do
  -- Fetch work order from DB
  mWo <- DAL.getWorkOrder woId
  case mWo of
    Nothing -> return $ Left "Work order not found"
    Just wo -> do
      -- Validate work order can be released
      case validateWorkOrderForRelease wo of
        Left err -> return $ Left err
        Right _ -> do
          -- Update work order status and released time
          let updatedWo = wo
                { woStatus = 1 -- WOReleased
                , woStartAt = Just releaseTime
                , woUpdatedAt = releaseTime
                , woUpdatedBy = Just userId
                }
          -- Save to DB
          result <- DAL.updateWorkOrder updatedWo
          case result of
            Left dbErr -> return $ Left ("Database error: " <> dbErr)
            Right savedWo -> return $ Right savedWo

-- | Complete a work order
completeWorkOrder :: Int64 -> UTCTime -> Text -> IO (Either Text WorkOrder)
completeWorkOrder woId completionTime userId = do
  mWo <- DAL.getWorkOrder woId
  case mWo of
    Nothing -> return $ Left "Work order not found"
    Just wo -> do
      case validateWorkOrderForCompletion wo of
        Left err -> return $ Left err
        Right _ -> do
          let updatedWo = wo
                { woStatus = 2 -- WOCompleted
                , woEndAt = Just completionTime
                , woUpdatedAt = completionTime
                , woUpdatedBy = Just userId
                }
          result <- DAL.updateWorkOrder updatedWo
          case result of
            Left dbErr -> return $ Left ("Database error: " <> dbErr)
            Right savedWo -> return $ Right savedWo

-- | Create a new tech card
createTechCard :: TechCard -> UTCTime -> Text -> IO (Either Text TechCard)
createTechCard techCard createTime userId = do
  case validateTechCard techCard of
    Left err -> return $ Left err
    Right _ -> do
      let cardToCreate = techCard
            { tcCreatedAt = createTime
            , tcUpdatedAt = createTime
            , tcCreatedBy = Just userId
            }
      result <- DAL.createTechCard cardToCreate
      case result of
        Left dbErr -> return $ Left ("Database error: " <> dbErr)
        Right savedCard -> return $ Right savedCard

-- | Create a new tech line
createTechLine :: TechLine -> UTCTime -> Text -> IO (Either Text TechLine)
createTechLine techLine createTime userId = do
  case validateTechLine techLine of
    Left err -> return $ Left err
    Right _ -> do
      let lineToCreate = techLine
            { tlCreatedAt = createTime
            , tlUpdatedAt = createTime
            , tlCreatedBy = Just userId
            }
      result <- DAL.createTechLine lineToCreate
      case result of
        Left dbErr -> return $ Left ("Database error: " <> dbErr)
        Right savedLine -> return $ Right savedLine

-- | Validate that a work order can be released
validateWorkOrderForRelease :: WorkOrder -> Either Text ()
validateWorkOrderForRelease wo =
  case validateWorkOrderCore wo of
    Left err -> Left err
    Right _ ->
      if woStatus wo /= 0 -- Not in draft status
        then Left "Work order must be in draft status to release"
        else if woQtyPlan wo <= 0
          then Left "Work order must have positive planned quantity"
          else if isNothing woTechCardId wo
            then Left "Work order must have an associated tech card"
            else Right ()

-- | Validate that a work order can be completed
validateWorkOrderForCompletion :: WorkOrder -> Either Text ()
validateWorkOrderForCompletion wo =
  case validateWorkOrderCore wo of
    Left err -> Left err
    Right _ ->
      if woStatus wo /= 1 -- Not in released status
        then Left "Work order must be in released status to complete"
        else if woQtyReleased wo < woQtyPlan wo
          then Left "Cannot complete work order: not all planned quantity has been released"
          else Right ()