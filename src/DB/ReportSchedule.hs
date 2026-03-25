-- | Report Schedule Database Operations
-- Note: Simplified stub implementation
module DB.ReportSchedule
  ( listReportSchedules,
    getReportSchedule,
    createReportSchedule,
    updateReportSchedule,
    deleteReportSchedule,
    listReportSnapshots,
    logReportSnapshot,
  )
where

import Data.Int (Int64)
import Data.Text (Text)
import Domain.ReportSchedule
import Hasql.Pool (Pool)

-- | List all report schedules
listReportSchedules :: Pool -> IO [ReportSchedule]
listReportSchedules _ = pure []

-- | Get report schedule by ID
getReportSchedule :: Pool -> Int64 -> IO (Maybe ReportSchedule)
getReportSchedule _ _ = pure Nothing

-- | Create new report schedule
createReportSchedule :: Pool -> ReportScheduleInput -> IO Int64
createReportSchedule _ _ = pure 0

-- | Update report schedule
updateReportSchedule :: Pool -> Int64 -> ReportScheduleInput -> IO ()
updateReportSchedule _ _ _ = pure ()

-- | Delete report schedule
deleteReportSchedule :: Pool -> Int64 -> IO ()
deleteReportSchedule _ _ = pure ()

-- | List report snapshots for a schedule
listReportSnapshots :: Pool -> Int64 -> IO [ReportSnapshot]
listReportSnapshots _ _ = pure []

-- | Log a report snapshot
logReportSnapshot :: Pool -> Int64 -> Text -> Maybe Text -> Maybe Text -> IO Int64
logReportSnapshot _ _ _ _ _ = pure 0
