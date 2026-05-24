{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE OverloadedStrings #-}

module Surypus.API.Workflow
  ( Workflow(..)
  , WorkflowInstance(..)
  , WorkflowStatus(..)
  , WorkflowInput(..)
  , listWorkflows
  , createWorkflow
  , startWorkflow
  , getWorkflowInstance
  , listWorkflowInstances
  , completeWorkflowStep
  , completeWorkflow
  ) where

import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Aeson (ToJSON, FromJSON, parseJSON)
import Data.Aeson.Types (parseMaybe)
import GHC.Generics (Generic)
import Data.Functor.Contravariant ((>$<))
import qualified Opaleye as OE
import qualified Opaleye.Internal.HaskellDB.PrimQuery as OPQ
import qualified Opaleye.Internal.PGTypes as OPG
import qualified Opaleye.Internal.Tag as OITag
import DAL.Database (Pool, runQuery, runCommand)
import DAL.Types (QueryResult(..), Workflow(..), WorkflowInstance(..), WorkflowStatus(..), WorkflowInput(..))

-- These decoders are no longer needed as we're using Opaleye
-- workflowDecoder :: D.Row Workflow
-- workflowDecoder = Workflow
--    <$> (fromIntegral <$> D.column (D.nonNullable D.int8))
--    <*> D.column (D.nonNullable D.text)
--    <*> D.column (D.nullable D.text)
--    <*> D.column (D.nonNullable D.text)
--    <*> D.column (D.nonNullable D.bool)
--    <*> D.column (D.nonNullable D.text)

-- workflowInstanceDecoder :: D.Row WorkflowInstance
-- workflowInstanceDecoder = WorkflowInstance
--    <$> (fromIntegral <$> D.column (D.nonNullable D.int8))  -- wiId - will need int8 from db
--    <*> (fromIntegral <$> D.column (D.nonNullable D.int8))  -- wiWorkflowId
--    <*> ((\n -> case n of
--            0 -> WorkflowPending
--            1 -> WorkflowRunning
--            2 -> WorkflowCompleted
--            _ -> WorkflowFailed) <$> D.column (D.nonNullable D.int2))
--    <*> D.column (D.nullable D.text)  -- wiCurrentStep
--     <*> ((>>= parseMaybe parseJSON) <$> D.column (D.nullable D.jsonb))  -- wiInput - nullable JSONB
--    <*> D.column (D.nullable D.timestamptz)  -- wiStartedAt
--    <*> D.column (D.nullable D.timestamptz)  -- wiCompletedAt

-- Table definition for workflows table
workflowsTable :: OE.Table (OE.OEInt4, OE.OEText, OE.OEText, OE.OEMaybe (OE.OEText), OE.OEBool, OE.OEText) (OE.OEInt4, OE.OEText, OE.OEText, OE.OEMaybe (OE.OEText), OE.OEBool, OE.OEText)
workflowsTable = OE.table "workflows" (OITag.tag "workflows")
   \(wId, wCode, wName, wDesc, wIsActive, wDef) ->
      ( wId
      , wCode
      , wName
      , wDesc
      , wIsActive
      , wDef
      )
   \(wId, wCode, wName, wDesc, wIsActive, wDef) ->
      ( OE.required wId
      , OE.required wCode
      , OE.required wName
      , OE.required wDesc
      , OE.required wIsActive
      , OE.required wDef
      )

-- | List all workflows
listWorkflows :: Pool -> IO (QueryResult [Workflow])
listWorkflows pool = do
   let query = OE.sql 
         "SELECT id, code, name, description, is_active, definition::TEXT FROM workflows ORDER BY created_at DESC"
         (OE.makeColumns (,,,,,) 
            OE.int4
            OE.text
            OE.text
            (OE.maybe OE.text)
            OE.bool
            OE.text
         ) OE.noParams
   result <- runQuery pool query
   case result of
     Left err -> return $ QueryError (T.pack $ show err)
     Right cols -> return $ QuerySuccess $ map (\(wId, wCode, wName, wDesc, wIsActive, wDef) ->
        Workflow (fromIntegral wId) wCode wName wDesc wIsActive) cols

-- | Create a new workflow definition
createWorkflow :: Pool -> WorkflowInput -> IO (QueryResult Workflow)
createWorkflow pool input = do
   let code = case wiInputData input of
         Just _ -> wiCode input
         Nothing -> "default"
       name = case wiInputData input of
         Just _ -> wiName input
         Nothing -> Nothing
       description = case wiInputData input of
         Just _ -> wiDescription input
         Nothing -> Nothing
       definition = case wiInputData input of
         Just _ -> T.pack $ show (wiInputData input)
         Nothing -> "{}"
   
   let insert = OE.insert workflowsTable
         OE.constNothing
         ( 0  -- id (auto-increment)
         , code
         , name
         , description
         , True  -- is_active
         , definition
         )
   result <- runCommand pool insert
   case result of
     Left err -> return $ QueryError (T.pack $ show err)
     Right count -> if count > 0
                    then getWorkflowByCode pool code  -- TODO: Need to implement this
                    else return $ QueryError "Failed to create workflow"

-- | Start a workflow instance
startWorkflow :: Pool -> Text -> Text -> IO (QueryResult WorkflowInstance)
startWorkflow pool workflowName initialContext = do
   let query = OE.sql 
         "SELECT workflow_start($1, $2::JSONB)::TEXT"
         (OE.makeColumns (,) 
            OE.text
         ) (,,) 
   let params = (workflowName, initialContext)
   result <- runQuery pool query params
   case result of
     Left err -> return $ QueryError (T.pack $ show err)
     Right cols -> do
       let instId = head $ head cols  -- Simplified extraction
       -- Fetch full instance
       getWorkflowInstance pool instId

-- Table definition for workflow_instances table
workflowInstancesTable :: OE.Table (OE.OEText, OE.OEText, OE.OEInt2, OE.OEMaybe (OE.OEText), OE.OEMaybe (OE.OEText), OE.OEMaybe (OE.OETimestamptz), OE.OEMaybe (OE.OETimestamptz)) (OE.OEText, OE.OEText, OE.OEInt2, OE.OEMaybe (OE.OEText), OE.OEMaybe (OE.OEText), OE.OEMaybe (OE.OETimestamptz), OE.OEMaybe (OE.OETimestamptz))
workflowInstancesTable = OE.table "workflow_instances" (OITag.tag "workflow_instances")
   \(wiId, wiWorkflowName, wiStatus, wiCurrentStep, wiContext, wiStartedAt, wiCompletedAt) ->
      ( wiId
      , wiWorkflowName
      , wiStatus
      , wiCurrentStep
      , wiContext
      , wiStartedAt
      , wiCompletedAt
      )
   \(wiId, wiWorkflowName, wiStatus, wiCurrentStep, wiContext, wiStartedAt, wiCompletedAt) ->
      ( OE.required wiId
      , OE.required wiWorkflowName
      , OE.required wiStatus
      , OE.required wiCurrentStep
      , OE.required wiContext
      , OE.required wiStartedAt
      , OE.required wiCompletedAt
      )

-- | Get workflow instance by ID
getWorkflowInstance :: Pool -> Text -> IO (QueryResult WorkflowInstance)
getWorkflowInstance pool iid = do
   let query = OE.sql 
         "SELECT id::UUID, workflow_name::TEXT, status::INT, current_step::TEXT, context::JSONB, started_at, completed_at FROM workflow_instances WHERE id = $1::UUID"
         (OE.makeColumns (,,,,,,,) 
            OE.text
            OE.text
            OE.int2
            (OE.maybe OE.text)
            (OE.maybe OE.text)
            (OE.maybe OE.timestamptz)
            (OE.maybe OE.timestamptz)
         ) (OE.required . fst)
   result <- runQuery pool query iid
   case result of
     Left err -> return $ QueryError (T.pack $ show err)
     Right cols -> return $ QuerySuccess $ map (\(wiId, wiWorkflowName, wiStatus, wiCurrentStep, wiContext, wiStartedAt, wiCompletedAt) ->
        WorkflowInstance (fromIntegral $ read wiId) (read $ wiWorkflowName) (fromIntegral wiStatus) wiCurrentStep wiContext wiStartedAt wiCompletedAt) cols

-- | List workflow instances
listWorkflowInstances :: Pool -> IO (QueryResult [WorkflowInstance])
listWorkflowInstances pool = do
   let query = OE.sql 
         "SELECT id::UUID, workflow_name::TEXT, status::INT, current_step::TEXT, context::JSONB, started_at, completed_at FROM workflow_instances ORDER BY started_at DESC"
         (OE.makeColumns (,,,,,,,) 
            OE.text
            OE.text
            OE.int2
            (OE.maybe OE.text)
            (OE.maybe OE.text)
            (OE.maybe OE.timestamptz)
            (OE.maybe OE.timestamptz)
         ) OE.noParams
   result <- runQuery pool query
   case result of
     Left err -> return $ QueryError (T.pack $ show err)
     Right cols -> return $ QuerySuccess $ map (\(wiId, wiWorkflowName, wiStatus, wiCurrentStep, wiContext, wiStartedAt, wiCompletedAt) ->
        WorkflowInstance (fromIntegral $ read wiId) (read $ wiWorkflowName) (fromIntegral wiStatus) wiCurrentStep wiContext wiStartedAt wiCompletedAt) cols

-- | Complete workflow step
completeWorkflowStep :: Pool -> Text -> Int -> Text -> IO (QueryResult ())
completeWorkflowStep pool iid nextStep contextUpdate = do
   let query = OE.sql 
         "SELECT workflow_step_complete($1::UUID, $2, $3::JSONB)"
         (OE.makeColumns (,,) 
            OE.text
            OE.int4
            OE.text
         ) OE.noCols
   let params = (iid, nextStep, contextUpdate)
   result <- runCommand pool query params
   case result of
     Left err -> return $ QueryError (T.pack $ show err)
     Right count -> if count > 0
                    then QuerySuccess ()
                    else QueryError "Failed to complete workflow step"

-- | Complete workflow
completeWorkflow :: Pool -> Text -> IO (QueryResult ())
completeWorkflow pool iid = do
   let query = OE.sql 
         "SELECT workflow_complete($1::UUID)"
         OE.noCols
         (OE.required . fst)
   result <- runCommand pool query iid
   case result of
     Left err -> return $ QueryError (T.pack $ show err)
     Right count -> if count > 0
                    then QuerySuccess ()
                    else QueryError "Failed to complete workflow"