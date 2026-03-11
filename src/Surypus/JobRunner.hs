{-# LANGUAGE OverloadedStrings #-}

module Surypus.JobRunner
  ( runJobWorker
  , processPendingJobs
  ) where

import Control.Concurrent (threadDelay)
import Control.Monad (forever, unless, void)
import Data.Aeson (eitherDecodeStrict)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Text.Encoding (encodeUtf8)
import Hasql.Pool (Pool)
import Domain.Document.Audit (DocumentAuditPayload(..), defaultDocumentAuditLookahead)
import Domain.Job (JobRecord(..), JobStatus(..))
import Domain.ReportJob (ReportRenderPayload(..))
import Domain.Payroll (PayrollSnapshotPayload(..))
import Domain.Production (MRPNeed(..))
import qualified DB.JobQueue as JobQueue
import qualified DB.PersonSnapshot as PersonSnapshot
import qualified DB.ReportSchedule as DBReportSchedule
import qualified DB.HRPayrollSnapshot as HRPayrollSnapshot
import qualified DB.Production as DBProduction
import qualified DB.Document.Audit as DBDocumentAudit
import Surypus.Reports (generateJRXML, getReport)

runJobWorker :: Pool -> Int -> IO ()
runJobWorker pool intervalSeconds = forever $ do
  didWork <- processPendingJobs pool
  unless didWork $
    threadDelay (intervalSeconds * 1000000)

processPendingJobs :: Pool -> IO Bool
processPendingJobs pool = do
  mjob <- JobQueue.fetchPendingJob pool
  case mjob of
    Nothing -> pure False
    Just job -> do
      void $ JobQueue.setJobStatus pool (jobId job) JobRunning Nothing
      result <- dispatchJob pool job
      let level = either (const "ERROR") (const "INFO") result
          message = buildLog job result
      JobQueue.logServiceEvent pool level message
      case result of
        Right _ -> void $ JobQueue.setJobStatus pool (jobId job) JobCompleted Nothing
        Left err -> void $ JobQueue.setJobStatus pool (jobId job) JobFailed (Just err)
      pure True

dispatchJob :: Pool -> JobRecord -> IO (Either Text Text)
dispatchJob pool job =
  case T.toLower (jobType job) of
    "person_summary_snapshot" -> runPersonSnapshotJob pool
    "report_render" -> runReportRenderJob pool job
    "payroll_summary_snapshot" -> runPayrollSnapshotJob pool job
    "mrp_plan" -> runMRPJob pool job
    "document_register_audit" -> runDocumentRegisterAuditJob pool job
    other -> pure $ Left $ "unsupported job type " <> other

runReportRenderJob :: Pool -> JobRecord -> IO (Either Text Text)
runReportRenderJob pool JobRecord{..} =
  case jobData of
    Nothing -> pure $ Left "report_render payload missing"
    Just payload -> case eitherDecodeStrict (encodeUtf8 payload) of
      Left err -> pure $ Left $ "failed to decode payload: " <> T.pack err
      Right ReportRenderPayload{..} -> do
        mSchedule <- DBReportSchedule.getReportSchedule pool rrpScheduleId
        case mSchedule of
          Nothing -> pure $ Left "report schedule not found"
          Just schedule -> case getReport (rsReport schedule) of
            Nothing -> do
              void $ DBReportSchedule.logReportSnapshot pool rrpScheduleId "failed" (Just "template not found") Nothing
              pure $ Left "report template missing"
            Just reportDef -> do
              let jrxml = generateJRXML reportDef
              void $ DBReportSchedule.logReportSnapshot pool rrpScheduleId "completed" (Just "JRXML generated") (Just jrxml)
              pure $ Right "report render snapshot stored"

runPersonSnapshotJob :: Pool -> IO (Either Text Text)
runPersonSnapshotJob pool = do
  mres <- PersonSnapshot.runPersonSummarySnapshot pool
  pure $ case mres of
    Nothing -> Left "person summary snapshot did not produce results"
    Just _ -> Right "person summary snapshot stored"

runPayrollSnapshotJob :: Pool -> JobRecord -> IO (Either Text Text)
runPayrollSnapshotJob pool JobRecord{..} =
  case jobData of
    Nothing -> pure $ Left "payroll_summary_snapshot payload missing"
    Just payload -> case eitherDecodeStrict (encodeUtf8 payload) of
      Left err -> pure $ Left $ "failed to decode payload: " <> T.pack err
      Right PayrollSnapshotPayload{..} -> do
        sid <- HRPayrollSnapshot.registerPayrollSnapshot pool pspPeriodStart pspPeriodEnd
        pure $ Right $ "payroll snapshot stored " <> T.pack (show sid)

runMRPJob :: Pool -> JobRecord -> IO (Either Text Text)
runMRPJob pool JobRecord{..} =
  case jobData of
    Nothing -> pure $ Left "mrp_plan payload missing"
    Just payload -> case eitherDecodeStrict (encodeUtf8 payload) of
      Left err -> pure $ Left $ "failed to decode payload: " <> T.pack err
      Right (needs :: [MRPNeed]) -> do
        plan <- DBProduction.runMRPCalc pool needs
        void $ DBProduction.logProductionPlan pool plan jobCode
        pure $ Right "MRP plan stored"

runDocumentRegisterAuditJob :: Pool -> JobRecord -> IO (Either Text Text)
runDocumentRegisterAuditJob pool JobRecord{..} =
  case jobData of
    Nothing -> performAudit defaultDocumentAuditLookahead
    Just payload -> case eitherDecodeStrict (encodeUtf8 payload) of
      Left err -> pure $ Left $ "failed to decode payload: " <> T.pack err
      Right DocumentAuditPayload{..} ->
        let lookahead = maybe defaultDocumentAuditLookahead id daaLookaheadDays
         in performAudit lookahead
  where
    performAudit lookaheadDays = do
      expiring <- DBDocumentAudit.findExpiringRegisters pool lookaheadDays
      duplicates <- DBDocumentAudit.findDuplicateRegisterNumbers pool
      let summary = T.concat
            [ "document_register_audit: "
            , T.pack (show (length expiring))
            , " expiring registers, "
            , T.pack (show (length duplicates))
            , " duplicate numbers"
            ]
      void $ JobQueue.logServiceEvent pool "INFO" summary
      pure $ Right summary

buildLog :: JobRecord -> Either Text Text -> Text
buildLog job outcome =
  let prefix = T.concat [jobType job, " ", jobCode job, " (", jobName job, ") - "]
   in prefix <> either ("failed: " <>) ("completed: " <>) outcome
