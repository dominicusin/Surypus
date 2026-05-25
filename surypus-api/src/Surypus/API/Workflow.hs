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
import qualified Hasql.Decoders as D
import qualified Hasql.Encoders as E
import qualified Hasql.Session as Session
import qualified Hasql.Statement as Stmt
import Data.Functor.Contravariant ((>$<))
import DAL.Database (Pool, usePool)
import DAL.Types (QueryResult(..), Workflow(..), WorkflowInstance(..), WorkflowStatus(..), WorkflowInput(..))

workflowDecoder :: D.Row Workflow
workflowDecoder = Workflow
  <$> (fromIntegral <$> D.column (D.nonNullable D.int8))
  <*> D.column (D.nonNullable D.text)
  <*> D.column (D.nullable D.text)
  <*> D.column (D.nonNullable D.text)
  <*> D.column (D.nonNullable D.bool)
  <*> D.column (D.nonNullable D.text)

workflowInstanceDecoder :: D.Row WorkflowInstance
workflowInstanceDecoder = WorkflowInstance
  <$> (fromIntegral <$> D.column (D.nonNullable D.int8))  -- wiId - will need int8 from db
  <*> (fromIntegral <$> D.column (D.nonNullable D.int8))  -- wiWorkflowId
  <*> ((\n -> case n of
        0 -> WorkflowPending
        1 -> WorkflowRunning
        2 -> WorkflowCompleted
        _ -> WorkflowFailed) <$> D.column (D.nonNullable D.int2))
  <*> D.column (D.nullable D.text)  -- wiCurrentStep
   <*> ((>>= parseMaybe parseJSON) <$> D.column (D.nullable D.jsonb))  -- wiInput - nullable JSONB
  <*> D.column (D.nullable D.timestamptz)  -- wiStartedAt
  <*> D.column (D.nullable D.timestamptz)  -- wiCompletedAt

-- | List all workflows
listWorkflows :: Pool -> IO (QueryResult [Workflow])
listWorkflows pool = do
  let stmt = Stmt.Statement
        "SELECT id, code, name, description, is_active, definition::TEXT FROM workflows ORDER BY created_at DESC"
        E.noParams
        (D.rowList workflowDecoder)
        True
  res <- usePool pool $ Session.statement () stmt
  case res of
    Right workflows -> return $ QuerySuccess workflows
    Left err -> return $ QueryError (T.pack $ show err)

-- | Create a new workflow definition
createWorkflow :: Pool -> WorkflowInput -> IO (QueryResult Workflow)
createWorkflow pool input = do
  let stmt = Stmt.Statement
        "INSERT INTO workflows (code, name, description, definition) VALUES ($1, $2, $3, $4::JSONB) RETURNING id, code, name, description, is_active, definition::TEXT"
        (((\(code, _, _, _) -> code) >$< E.param (E.nonNullable E.text))
         <> ((\(_, name, _, _) -> name) >$< E.param (E.nullable E.text))
         <> ((\(_, _, desc, _) -> desc) >$< E.param (E.nullable E.text))
         <> ((\(_, _, _, def) -> def) >$< E.param (E.nonNullable E.text)))
        (D.singleRow workflowDecoder)
        True
  let params = case wiInputData input of
        Just txt -> (txt, Nothing, Nothing, "{}")
        Nothing -> ("default", Nothing, Nothing, "{}")
  res <- usePool pool $ Session.statement params stmt
  case res of
    Right workflow -> return $ QuerySuccess workflow
    Left err -> return $ QueryError (T.pack $ show err)

-- | Start a workflow instance
startWorkflow :: Pool -> Text -> Text -> IO (QueryResult WorkflowInstance)
startWorkflow pool workflowName initialContext = do
  let stmt = Stmt.Statement
        "SELECT workflow_start($1, $2::JSONB)::TEXT"
        (((\(n, _) -> n) >$< E.param (E.nonNullable E.text))
         <> ((\(_, c) -> c) >$< E.param (E.nonNullable E.text)))
        (D.singleRow (D.column (D.nonNullable D.text)))
        True
  let params = (workflowName, initialContext)
  res <- usePool pool $ Session.statement params stmt
  case res of
    Right instId -> do
      -- Fetch full instance
      getWorkflowInstance pool instId
    Left err -> return $ QueryError (T.pack $ show err)

-- | Get workflow instance by ID
getWorkflowInstance :: Pool -> Text -> IO (QueryResult WorkflowInstance)
getWorkflowInstance pool iid = do
  let stmt = Stmt.Statement
        "SELECT id::UUID, workflow_name::TEXT, status::INT, current_step::TEXT, context::JSONB, started_at, completed_at FROM workflow_instances WHERE id = $1::UUID"
        (E.param (E.nonNullable E.text))
        (D.singleRow workflowInstanceDecoder)
        True
  res <- usePool pool $ Session.statement iid stmt
  case res of
    Right instance' -> return $ QuerySuccess instance'
    Left err -> return $ QueryError (T.pack $ show err)

-- | List workflow instances
listWorkflowInstances :: Pool -> IO (QueryResult [WorkflowInstance])
listWorkflowInstances pool = do
  let stmt = Stmt.Statement
        "SELECT id::UUID, workflow_name::TEXT, status::INT, current_step::TEXT, context::JSONB, started_at, completed_at FROM workflow_instances ORDER BY started_at DESC"
        E.noParams
        (D.rowList workflowInstanceDecoder)
        True
  res <- usePool pool $ Session.statement () stmt
  case res of
    Right instances -> return $ QuerySuccess instances
    Left err -> return $ QueryError (T.pack $ show err)

-- | Complete workflow step
completeWorkflowStep :: Pool -> Text -> Int -> Text -> IO (QueryResult ())
completeWorkflowStep pool iid nextStep contextUpdate = do
  let stmt = Stmt.Statement
        "SELECT workflow_step_complete($1::UUID, $2, $3::JSONB)"
        (((\(i, _, _) -> i) >$< E.param (E.nonNullable E.text))
         <> ((\(_, s, _) -> fromIntegral s) >$< E.param (E.nonNullable E.int4))
         <> ((\(_, _, c) -> c) >$< E.param (E.nonNullable E.text)))
        D.noResult
        True
  let params = (iid, nextStep, contextUpdate)
  res <- usePool pool $ Session.statement params stmt
  case res of
    Right _ -> return $ QuerySuccess ()
    Left err -> return $ QueryError (T.pack $ show err)

-- | Complete workflow
completeWorkflow :: Pool -> Text -> IO (QueryResult ())
completeWorkflow pool iid = do
  let stmt = Stmt.Statement
        "SELECT workflow_complete($1::UUID)"
        (E.param (E.nonNullable E.text))
        D.noResult
        True
  res <- usePool pool $ Session.statement iid stmt
  case res of
    Right _ -> return $ QuerySuccess ()
    Left err -> return $ QueryError (T.pack $ show err)