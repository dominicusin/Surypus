module System.AuditComplete where

import Control.Concurrent.STM (TVar, newTVarIO, readTVar, writeTVar, atomically)
import Data.Text (Text)
import qualified Data.UUID as UUID
import qualified Data.ByteString.Lazy as BL
import Data.Time.Clock (UTCTime)
import Data.Aeson (ToJSON, encode)

-- | Audit severity levels with numeric values for filtering
data AuditSeverity
  = DebugS = 100
  | InfoS = 200
  | WarningS = 300
  | ErrorS = 400
  | CriticalS = 500
  deriving (Show, Eq, Ord, Enum, Bounded)

-- | Complete audit event with full context
data AuditEventComplete = AuditEventComplete
  { auditEventId :: Text,
    auditTimestamp :: UTCTime,
    auditSeverity :: AuditSeverity,
    auditSource :: Text,
    auditAction :: Text,
    auditEntity :: Text,
    auditEntityId :: Maybe Text,
    auditUserId :: Maybe Text,
    auditUsername :: Maybe Text,
    auditChanges :: Maybe BL.ByteString,
    auditMetadata :: [(Text, Text)],
    auditIpAddress :: Maybe Text,
    auditUserAgent :: Maybe Text,
    auditRequestPath :: Maybe Text,
    auditStatusCode :: Maybe Int
  }

-- | Audit storage with compliance guarantees
data AuditStorage = AuditStorage
  { auditBuffer :: TVar [AuditEventComplete],
    auditIndex :: TVar (Map.Map Text [AuditEventComplete]),
    auditRetentionDays :: Int,
    auditComplianceMode :: Bool
  }

-- | Initialize complete audit system
initAuditComplete :: Int -> Bool -> IO AuditStorage
initAuditComplete retentionDays compliance = do
  bufferVar <- newTVarIO []
  indexVar <- newTVarIO Map.empty
  return $ AuditStorage
    { auditBuffer = bufferVar,
      auditIndex = indexVar,
      auditRetentionDays = retentionDays,
      auditComplianceMode = compliance
    }

-- | Write audit event with full compliance
writeAuditComplete :: AuditStorage -> AuditEventComplete -> IO ()
writeAuditComplete audit event = atomically $ do
  -- Add to buffer
  buffer <- readTVar (auditBuffer audit)
  let newBuffer = event : take 10000 buffer  -- Keep last 10k events
  writeTVar (auditBuffer audit) newBuffer
  
  -- Update indices
  updateIndices audit event
  
  -- Enforce retention if in compliance mode
  when (auditComplianceMode audit) $ do
    now <- getCurrentTime
    let cutoff = addUTCTime (negate $ fromIntegral (auditRetentionDays audit * 24 * 3600)) now
    buffer' <- readTVar (auditBuffer audit)
    let valid = filter (\e -> auditTimestamp e > cutoff) buffer'
    writeTVar (auditBuffer audit) valid

-- | Update all indices
updateIndices :: AuditStorage -> AuditEventComplete -> STM ()
updateIndices audit event = do
  idx <- readTVar (auditIndex audit)
  let sourceKey = auditSource event
      updated = Map.insertWith (++) sourceKey [event] idx
  writeTVar (auditIndex audit) updated

-- | Query with complex filters
queryAuditComplete :: AuditStorage -> Maybe Text -> Maybe AuditSeverity -> Maybe UTCTime -> Maybe UTCTime -> IO [AuditEventComplete]
queryAuditComplete audit mSource mSeverity minTime maxTime = do
  idx <- readTVarIO (auditIndex audit)
  let candidates = case mSource of
        Nothing -> concat $ Map.elems idx
        Just src -> Map.findWithDefault [] src idx
  return $ filter (applyFilters mSeverity minTime maxTime) candidates

-- | Apply filter predicates
applyFilters :: Maybe AuditSeverity -> Maybe UTCTime -> Maybe UTCTime -> AuditEventComplete -> Bool
applyFilters mSeverity minTime maxTime event =
  maybe True (>=) mSeverity (Just $ auditSeverity event) &&
  maybe True (auditTimestamp event >=) minTime &&
  maybe True (auditTimestamp event <=) maxTime

-- | Export audit data in various formats
exportAuditData :: AuditStorage -> BL.ByteString -> IO (Either Text BL.ByteString)
exportAuditData audit format = do
  events <- readTVarIO (auditBuffer audit)
  case format of
    "json" -> return $ Right $ encode events
    "compact" -> return $ Right $ BL.pack $ show events
    _ -> return $ Left "Unsupported format"

-- | Generate compliance report
generateComplianceReport :: AuditStorage -> IO BL.ByteString
generateComplianceReport audit = do
  events <- readTVarIO (auditBuffer audit)
  let report = mconcat $
        [ "Compliance Report\n"
        , "Total Events: " <> BL.pack (show (length events)) <> "\n"
        , "Severity Breakdown: " <> BL.pack (show $ countSeverities events) <> "\n"
        ]
  return report
  where
    countSeverities = undefined  -- Implementation placeholder

-- | Real-time audit streaming
streamAuditEvents :: AuditStorage -> (AuditEventComplete -> IO ()) -> IO ()
streamAuditEvents audit handler = do
  events <- readTVarIO (auditBuffer audit)
  mapM_ handler (reverse events)  -- Newest first
