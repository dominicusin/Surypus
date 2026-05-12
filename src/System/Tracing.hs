module System.Tracing where

import Data.Text (Text)
import Data.Time.Clock (UTCTime)
import qualified Data.UUID as UUID
import Control.Concurrent.STM (TVar, newTVarIO, readTVar, writeTVar)
import Data.Aeson (ToJSON, Value, object, (.=))

-- | Trace context for distributed tracing
data TraceContext = TraceContext
  { traceId :: Text,
    spanId :: Text,
    parentSpanId :: Maybe Text,
    sampled :: Bool
  }

-- | Initialize trace context
initTraceContext :: IO TraceContext
initTraceContext = do
  tid <- UUID.toText <$> UUID.nextRandom
  sid <- UUID.toText <$> UUID.nextRandom
  return $ TraceContext tid sid Nothing True

-- | Start a new span
data Span = Span
  { spanId :: Text,
    spanName :: Text,
    spanStartTime :: UTCTime,
    spanTags :: [(Text, Text)],
    spanLogs :: [(UTCTime, Text)],
    spanChildSpans :: [Span]
  }

-- | Start timing a span
startSpan :: Text -> IO Span
startSpan name = do
  now <- getCurrentTime
  tid <- UUID.toText <$> UUID.nextRandom
  return $ Span tid name now [] [] []

-- | Add tag to span
addSpanTag :: Span -> Text -> Text -> Span
addSpanTag span key value = span { spanTags = (key, value) : spanTags span }

-- | Add log to span
addSpanLog :: Span -> Text -> IO Span
addSpanLog span msg = do
  now <- getCurrentTime
  return $ span { spanLogs = (now, msg) : spanLogs span }

-- | Finish span and get timing
endSpan :: Span -> (Span, NominalDiffTime)
endSpan span = (span, diffUTCTime (getCurrentTime >>= \t -> return t) -- simplified

-- | Trace an operation with automatic span management
traceOperation :: Text -> IO a -> IO (a, Span)
traceOperation operation action = do
  span <- startSpan operation
  result <- try action
  case result of
    Right val -> do
      endSpan span
      return (val, span)
    Left err -> do
      addSpanLog span ("Error: " <> T.pack (show err))
      endSpan span
      return (error (show err), span)

-- | Create trace context JSON
instance ToJSON TraceContext where
  toJSON TraceContext {..} = object
    [ "trace_id" .= traceId
    , "span_id" .= spanId
    , "parent_span_id" .= parentSpanId
    , "sampled" .= sampled
    ]

-- | Create span JSON
instance ToJSON Span where
  toJSON Span {..} = object
    [ "span_id" .= spanId
    , "name" .= spanName
    , "start_time" .= spanStartTime
    , "tags" .= spanTags
    , "logs" .= spanLogs
    ]
