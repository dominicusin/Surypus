{-# LANGUAGE OverloadedStrings #-}
{-# OPTIONS_GHC -Wno-unused-imports #-}

-- | Background Job System - Task queue and execution
module Production.JobSystem
  ( -- * Job Operations
    createJob,
    getJobStatus,
    listJobs,
    listPendingJobs,
    processNextJob,

    -- * Job Types
    JobStatus (..),
    JobPriority (..)
  ) where

import Data.Int (Int64)
import Data.Text (Text)
-- import qualified Hasql.Decoders as D
-- import qualified Hasql.Encoders as E
-- import Hasql.Pool (Pool, use)
-- import qualified Hasql.Session as Session
-- import qualified Hasql.Session as Session
-- import Hasql.Statement (Statement)