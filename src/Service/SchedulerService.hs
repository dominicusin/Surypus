{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}

module Service.SchedulerService
  ( SchedulerService (..),
    createSchedulerService,
    scheduleJob,
    listJobs,
    runJob,
  )
where

import Data.Aeson (Value, object, (.=))
import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (getCurrentTime)
import Data.UUID (UUID, nextRandom)
import Hasql.Pool (Pool)
import Service.AuditService
  ( AuditAction (..),
    AuditEntityType (..),
    AuditEvent (..),
    AuditService,
    createAuditService,
    logAuditEvent,
  )
import Surypus.Event
  ( DomainEvent (..),
    EventBus,
    EventType (JobCompleted, JobScheduled, JobStarted),
    publishEventSync,
  )

data SchedulerService = SchedulerService
  { schedPool :: Pool,
    schedEventBus :: EventBus,
    schedAuditService :: AuditService
  }

createSchedulerService :: Pool -> EventBus -> AuditService -> SchedulerService
createSchedulerService pool eb as = SchedulerService pool eb as

scheduleJob :: SchedulerService -> Text -> Text -> IO (Either Text Int64)
scheduleJob service jobType payload = do
  now <- getCurrentTime
  let jobId = 1
  publishEventSync (schedEventBus service) JobScheduled "Job" (Just jobId) Nothing (object ["type" .= jobType, "payload" .= payload])
  logToAudit service now AuditExecute AuditEntityJob (Just jobId) ("Job scheduled: " <> jobType)
  pure (Right jobId)

listJobs :: SchedulerService -> IO [Text]
listJobs service = do
  now <- getCurrentTime
  logToAudit service now AuditRead AuditEntityJob Nothing ("Listed jobs")
  pure []

runJob :: SchedulerService -> Int64 -> IO UUID
runJob service jobId = do
  now <- getCurrentTime
  uuid <- nextRandom
  publishEventSync (schedEventBus service) JobStarted "Job" (Just jobId) Nothing (object ["job_id" .= jobId, "run_id" .= uuid])
  logToAudit service now AuditExecute AuditEntityJob (Just jobId) ("Job started")
  pure uuid

logToAudit ::
  SchedulerService ->
  UTCTime ->
  AuditAction ->
  AuditEntityType ->
  Maybe Int64 ->
  Text ->
  IO ()
logToAudit service timestamp action entityType entityId description = do
  let event =
        AuditEvent
          { auditId = Nothing,
            auditTimestamp = timestamp,
            auditUserId = Nothing,
            auditUsername = Nothing,
            auditAction = action,
            auditEntityType = entityType,
            auditEntityId = entityId,
            auditChanges = Nothing,
            auditIpAddress = Nothing,
            auditDescription = Just description
          }
  _ <- logAuditEvent (schedAuditService service) event
  pure ()
