{-# LANGUAGE OverloadedStrings #-}

module DB.Connection
  ( PoolConfig (..)
  , Pool
  , createPool
  , closePool
  , initSchema
  ) where

import           Control.Monad           (forM_)
import qualified Data.ByteString.Char8   as BS
import qualified Data.Text               as T
import           Data.Time.Clock         (NominalDiffTime)
import           Hasql.Connection        (settings)
import           Hasql.Pool              (Pool, acquire, release, use)
import           Hasql.Session           (sql)

data PoolConfig = PoolConfig
  { pcHost        :: String
  , pcPort        :: Int
  , pcUser        :: String
  , pcPassword    :: String
  , pcDatabase    :: String
  , pcConnections :: Int
  , pcStripes     :: Int
  , pcIdleTime    :: NominalDiffTime
  } deriving (Eq, Show)

createPool :: PoolConfig -> IO Pool
createPool cfg =
  acquire (pcConnections cfg) (pcIdleTime cfg) connSettings
  where
    connSettings =
      settings
        (BS.pack $ pcHost cfg)
        (fromIntegral $ pcPort cfg)
        (BS.pack $ pcUser cfg)
        (BS.pack $ pcPassword cfg)
        (BS.pack $ pcDatabase cfg)

closePool :: Pool -> IO ()
closePool = release

initSchema :: Pool -> IO ()
initSchema pool = use pool $ do
  forM_ schemaStatements sql

schemaStatements :: [T.Text]
schemaStatements =
  [ \"CREATE TABLE IF NOT EXISTS job ( \
    \id BIGSERIAL PRIMARY KEY, \
    \code VARCHAR(64) NOT NULL UNIQUE, \
    \name VARCHAR(128) NOT NULL, \
    \job_type VARCHAR(32) NOT NULL, \
    \status VARCHAR(32) NOT NULL DEFAULT 'pending', \
    \priority SMALLINT NOT NULL DEFAULT 5, \
    \job_data JSONB, \
    \scheduled_at TIMESTAMPTZ, \
    \started_at TIMESTAMPTZ, \
    \completed_at TIMESTAMPTZ, \
    \error_message TEXT, \
    \created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(), \
    \updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW() \
    \)\" 
  , \"CREATE INDEX IF NOT EXISTS idx_job_status ON job(status)\"
  , \"CREATE INDEX IF NOT EXISTS idx_job_priority ON job(priority DESC)\"
  , \"CREATE TABLE IF NOT EXISTS job_param (id SERIAL PRIMARY KEY, job_id BIGINT NOT NULL, param_key VARCHAR(100) NOT NULL, param_value TEXT, UNIQUE(job_id, param_key))\"
  , \"CREATE TABLE IF NOT EXISTS job_dependency (id SERIAL PRIMARY KEY, job_id BIGINT NOT NULL, depends_on_id BIGINT NOT NULL, dependency_type VARCHAR(20) DEFAULT 'BLOCKS', CONSTRAINT jd_job_dependency_unique UNIQUE(job_id, depends_on_id), CONSTRAINT jd_no_self_reference CHECK(job_id != depends_on_id))\"
  , \"CREATE TABLE IF NOT EXISTS cron_tasks (id SERIAL PRIMARY KEY, name TEXT NOT NULL UNIQUE, schedule TEXT NOT NULL, command TEXT NOT NULL, enabled BOOLEAN NOT NULL DEFAULT TRUE, last_run TIMESTAMP WITH TIME ZONE, next_run TIMESTAMP WITH TIME ZONE)\"
  , \"CREATE TABLE IF NOT EXISTS cron_logs (id SERIAL PRIMARY KEY, task_id INTEGER REFERENCES cron_tasks(id) ON DELETE CASCADE, started_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(), finished_at TIMESTAMP WITH TIME ZONE, status TEXT NOT NULL, output TEXT)\"
  , \"CREATE TABLE IF NOT EXISTS service_events (id SERIAL PRIMARY KEY, event_time TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(), event_level TEXT NOT NULL, event_message TEXT NOT NULL)\"
  , \"CREATE SCHEMA IF NOT EXISTS accounting\"
  , \"CREATE TABLE IF NOT EXISTS accounting.acc_sheet (\\n    \\ id BIGSERIAL PRIMARY KEY, \\n    \\ name VARCHAR(256) NOT NULL, \\n    \\ code VARCHAR(32) NOT NULL, \\n    \\ flags INTEGER DEFAULT 0, \\n    \\ created_at TIMESTAMPTZ DEFAULT NOW() \\n    \\)\"
  , \"CREATE TABLE IF NOT EXISTS accounting.account (\\n    \\ id BIGSERIAL PRIMARY KEY, \\n    \\ sheet_id BIGINT NOT NULL REFERENCES accounting.acc_sheet(id), \\n    \\ code VARCHAR(32) NOT NULL, \\n    \\ name VARCHAR(256) NOT NULL, \\n    \\ atype SMALLINT NOT NULL DEFAULT 0, \\n    \\ parent_id BIGINT REFERENCES accounting.account(id), \\n    \\ currency_id BIGINT, \\n    \\ balance NUMERIC(18,4) DEFAULT 0, \\n    \\ created_at TIMESTAMPTZ DEFAULT NOW(), \\n    \\ updated_at TIMESTAMPTZ DEFAULT NOW() \\n    \\)\"
  , \"CREATE TABLE IF NOT EXISTS accounting.acct_entry (\\n    \\ id BIGSERIAL PRIMARY KEY, \\n    \\ dt DATE NOT NULL, \\n    \\ bill_id BIGINT, \\n    \\ debit_acc_id BIGINT NOT NULL REFERENCES accounting.account(id), \\n    \\ credit_acc_id BIGINT NOT NULL REFERENCES accounting.account(id), \\n    \\ amount NUMERIC(18,4) NOT NULL, \\n    \\ currency_id BIGINT, \\n    \\ memo TEXT, \\n    \\ created_at TIMESTAMPTZ DEFAULT NOW(), \\n    \\ CHECK (debit_acc_id <> credit_acc_id) \\n    \\)\"
  , \"CREATE INDEX IF NOT EXISTS idx_accounting_account_sheet ON accounting.account(sheet_id)\"
  , \"CREATE INDEX IF NOT EXISTS idx_accounting_account_code ON accounting.account(code)\"
  , \"CREATE INDEX IF NOT EXISTS idx_accounting_entry_date ON accounting.acct_entry(dt)\"
  , \"CREATE INDEX IF NOT EXISTS idx_accounting_entry_account ON accounting.acct_entry(debit_acc_id, credit_acc_id)\"
  , \"CREATE OR REPLACE FUNCTION accounting.trial_balance(p_sheet_id BIGINT, p_date DATE) RETURNS TABLE (account_id BIGINT, account_code TEXT, account_name TEXT, debit_turnover NUMERIC(18,4), credit_turnover NUMERIC(18,4), debit_end NUMERIC(18,4), credit_end NUMERIC(18,4), balance NUMERIC(18,4)) AS $$ BEGIN RETURN QUERY SELECT a.id, a.code, a.name, COALESCE(SUM(CASE WHEN ae.debit_acc_id = a.id AND ae.dt <= p_date THEN ae.amount ELSE 0 END), 0), COALESCE(SUM(CASE WHEN ae.credit_acc_id = a.id AND ae.dt <= p_date THEN ae.amount ELSE 0 END), 0), 0::NUMERIC(18,4), 0::NUMERIC(18,4), COALESCE(SUM(CASE WHEN ae.debit_acc_id = a.id AND ae.dt <= p_date THEN ae.amount ELSE 0 END), 0) - COALESCE(SUM(CASE WHEN ae.credit_acc_id = a.id AND ae.dt <= p_date THEN ae.amount ELSE 0 END), 0) FROM accounting.account a LEFT JOIN accounting.acct_entry ae ON ae.debit_acc_id = a.id OR ae.credit_acc_id = a.id WHERE a.sheet_id = p_sheet_id GROUP BY a.id, a.code, a.name ORDER BY a.code; END; $$ LANGUAGE plpgsql\"
  ]
