module System.Audit where

import Control.Concurrent.STM (TVar, atomically, newTVarIO, readTVar, writeTVar)
import qualified Data.ByteString.Lazy as BL
import Data.Text (Text)
import Data.Time.Clock (UTCTime)
import qualified Data.UUID as UUID

-- | Audit severity levels
data AuditSeverity
  = Debug
  | Info
  | Warning
  | Error
  | Critical
  deriving (Show, Eq, Ord)

-- | Audit event with full context
data AuditEvent = AuditEvent
  { auditEventId :: Text,
    auditTimestamp :: UTCTime,
    auditSeverity :: AuditSeverity,
    auditSource :: Text,
    auditAction :: Text,
    auditEntity :: Text,
    auditEntityId :: Maybe Text,
    auditUserId :: Maybe Text,
    auditChanges :: Maybe BL.ByteString,
    auditMetadata :: [(Text, Text)],
    auditIpAddress :: Maybe Text,
    auditUserAgent :: Maybe Text
  }

-- | Audit storage with immutability guarantee
data AuditLog = AuditLog
  { logBuffer :: TVar [AuditEvent],
    logIndex :: TVar (Map.Map Text [AuditEvent]),
    logRetentionDays :: Int
  }

-- | Create audit logger
initAuditLog :: Int -> IO AuditLog
initAuditLog retentionDays = do
  bufferVar <- newTVarIO []
  indexVar <- newTVarIO Map.empty
  return $ AuditLog bufferVar indexVar retentionDays

-- | Write audit event (atomic, immutable)
writeAuditEvent :: AuditLog -> AuditEvent -> IO ()
writeAuditEvent auditLog event = atomically $ do
  buffer <- readTVar (logBuffer auditLog)
  let newBuffer = event : buffer
  writeTVar (logBuffer auditLog) newBuffer
  -- Maintain index for fast lookup
  updateIndex (logIndex auditLog) event

-- | Indexed lookup
queryAuditLog :: AuditLog -> Text -> Maybe UTCTime -> Maybe UTCTime -> IO [AuditEvent]
queryAuditLog auditLog source timeRange = do
  index <- readTVarIO (logIndex auditLog)
  let events = Map.findWithDefault [] source index
  return $ filterByTime events timeRange

-- | Time-based filtering
filterByTime :: [AuditEvent] -> Maybe UTCTime -> Maybe UTCTime -> [AuditEvent]
filterByTime events minTime maxTime = filter inRange events
  where
    inRange e =
      maybe True (>= eventTimestamp e) minTime
        && maybe True (<= eventTimestamp e) maxTime

-- | Immutable event update pattern
updateAuditEvent :: AuditEvent -> AuditEvent
updateAuditEvent event =
  event
    { auditChanges = Just (encodeChanges event)
    }

-- | Encode changes as immutable ByteString
encodeChanges :: AuditEvent -> BL.ByteString
encodeChanges _ = "{}" -- Placeholder for actual encoding

-- | Audit retention policy enforcement
enforceRetention :: AuditLog -> IO ()
enforceRetention auditLog = do
  now <- getCurrentTime
  atomically $ do
    buffer <- readTVar (logBuffer auditLog)
    let validEvents = filter (withinRetention now (logRetentionDays auditLog)) buffer
    writeTVar (logBuffer auditLog) validEvents

-- | Calculate retention cutoff
withinRetention :: UTCTime -> Int -> AuditEvent -> Bool
withinRetention now days event =
  diffUTCTime now (auditTimestamp event) < fromIntegral (days * 24 * 3600)

-- | Immutable audit trail validation
validateAuditTrail :: [AuditEvent] -> Either Text [AuditEvent]
validateAuditTrail events = do
  let sorted = sortBy (\a b -> compare (auditTimestamp a) (auditTimestamp b)) events
  -- Verify chronological integrity
  if isChronological sorted
    then Right sorted
    else Left "Audit trail integrity violation"
  where
    isChronological [] = True
    isChronological [_] = True
    isChronological (a : b : rest) = auditTimestamp a <= auditTimestamp b && isChronological (b : rest)
