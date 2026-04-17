module System.DecisionEngine where

import Control.Concurrent.STM (TVar, atomically, newTVarIO, readTVar, writeTVar)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import System.Orchestrator (Orchestrator)

-- | Decision context
data DecisionContext = DecisionContext
  { contextMetrics :: Map.Map Text Double,
    contextHealth :: Maybe (),
    contextUserInput :: Map.Map Text Text
  }

-- | Decision rule
data DecisionRule = DecisionRule
  { ruleId :: Text,
    ruleCondition :: DecisionContext -> Bool,
    ruleAction :: DecisionContext -> IO (),
    rulePriority :: Int
  }

-- | Decision engine
data DecisionEngine = DecisionEngine
  { engineRules :: TVar [DecisionRule],
    engineOrchestrator :: Orchestrator
  }

-- | Initialize decision engine
initDecisionEngine :: Orchestrator -> IO DecisionEngine
initDecisionEngine orch = do
  rulesVar <- newTVarIO []
  return $ DecisionEngine rulesVar orch

-- | Add decision rule
addDecisionRule :: DecisionEngine -> DecisionRule -> IO ()
addDecisionRule engine rule = atomically $ do
  rules <- readTVar (engineRules engine)
  let newRules = insertRuleByPriority rule rules
  writeTVar (engineRules engine) newRules
  where
    insertRuleByPriority newRule [] = [newRule]
    insertRuleByPriority newRule (r : rs)
      | rulePriority newRule >= rulePriority r = newRule : r : rs
      | otherwise = r : insertRuleByPriority newRule rs

-- | Evaluate decision
evaluateDecision :: DecisionEngine -> DecisionContext -> IO [Text]
evaluateDecision engine context = do
  rules <- readTVarIO (engineRules engine)
  let applicable = filter (ruleCondition) rules
  mapM_ (ruleAction) applicable
  return $ map ruleId applicable

-- | Decision outcome
data DecisionOutcome
  = Approve
  | Reject Text
  | Review
  deriving (Show, Eq)

-- | Make decision
makeDecision :: DecisionEngine -> DecisionContext -> IO DecisionOutcome
makeDecision engine context = do
  result <- evaluateDecision engine context
  if null result
    then return Reject "No applicable rules"
    else return Approve

-- | Decision audit
data DecisionAudit = DecisionAudit
  { auditDecisionId :: Text,
    auditContext :: DecisionContext,
    auditOutcome :: DecisionOutcome,
    auditTimestamp :: UTCTime
  }

-- | Log decision audit
logDecisionAudit :: DecisionAudit -> IO ()
logDecisionAudit audit = do
  -- Persist audit log
  return ()
