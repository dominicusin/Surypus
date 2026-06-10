{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Surypus.API.Accounting
    ( BalanceEntry (..)
    , BalanceResponse (..)
    , JournalEntry (..)
    , getBalance
    , getJournalEntries
    ) where

import Control.Monad.IO.Class (liftIO)
import DAL.Types (QueryResult(..))
import Data.Aeson (ToJSON)
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time.Calendar (Day)
import Database.Persist.Sql (ConnectionPool, PersistValue (..), rawSql, runSqlPool, Single (..))
import GHC.Generics (Generic)

-- | Balance sheet entry for one account
data BalanceEntry = BalanceEntry
    { beAccountId   :: !Int64
    , beCode        :: !Text
    , beName        :: !Text
    , beAccType     :: !Int
    , beTotalDebit  :: !Double
    , beTotalCredit :: !Double
    , beBalance     :: !Double
    } deriving (Show, Eq, Generic)

instance ToJSON BalanceEntry

-- | Balance sheet response with totals
data BalanceResponse = BalanceResponse
    { brEntries      :: ![BalanceEntry]
    , brTotalDebit   :: !Double
    , brTotalCredit  :: !Double
    , brTotalBalance :: !Double
    } deriving (Show, Eq, Generic)

instance ToJSON BalanceResponse

-- | Journal entry enriched with account names
data JournalEntry = JournalEntry
    { jeId         :: !Int64
    , jeDocId      :: !(Maybe Int64)
    , jeDebitAcc   :: !Int64
    , jeDebitName  :: !Text
    , jeCreditAcc  :: !Int64
    , jeCreditName :: !Text
    , jeAmount     :: !Double
    , jeDate       :: !Day
    } deriving (Show, Eq, Generic)

instance ToJSON JournalEntry

-- | Get balance sheet with period filtering
getBalance :: ConnectionPool -> Maybe Day -> Maybe Day -> IO (QueryResult BalanceResponse)
getBalance pool mStart mEnd = do
    let startSql = maybe "1900-01-01" show mStart
        endSql = maybe "2999-12-31" show mEnd
    result <- liftIO $ runSqlPool
        (rawSql
            "SELECT a.id, a.code, a.name, a.acc_type, \
            \  COALESCE(d.total_debit, 0), \
            \  COALESCE(c.total_credit, 0), \
            \  COALESCE(d.total_debit, 0) - COALESCE(c.total_credit, 0) \
            \FROM acc_plan a \
            \LEFT JOIN ( \
            \  SELECT dbt_acc_id, SUM(amount) as total_debit \
            \  FROM acc_turn \
            \  WHERE date >= ? AND date <= ? \
            \  GROUP BY dbt_acc_id \
            \) d ON a.id = d.dbt_acc_id \
            \LEFT JOIN ( \
            \  SELECT crd_acc_id, SUM(amount) as total_credit \
            \  FROM acc_turn \
            \  WHERE date >= ? AND date <= ? \
            \  GROUP BY crd_acc_id \
            \) c ON a.id = c.crd_acc_id \
            \ORDER BY a.code"
            [ PersistText (T.pack startSql)
            , PersistText (T.pack endSql)
            , PersistText (T.pack startSql)
            , PersistText (T.pack endSql)
            ]) pool
    let entries = [ BalanceEntry aid code name accType debit credit bal
                  | (Single (aid :: Int64), Single (code :: Text), Single (name :: Text)
                    , Single (accType :: Int), Single (debit :: Double)
                    , Single (credit :: Double), Single (bal :: Double)) <- result
                  ]
    let totalDebit  = sum (map beTotalDebit  entries)
        totalCredit = sum (map beTotalCredit entries)
    return $ QuerySuccess BalanceResponse
        { brEntries      = entries
        , brTotalDebit   = totalDebit
        , brTotalCredit  = totalCredit
        , brTotalBalance = totalDebit - totalCredit
        }

-- | Get journal entries with optional period filtering
getJournalEntries :: ConnectionPool -> Maybe Day -> Maybe Day -> IO (QueryResult [JournalEntry])
getJournalEntries pool mStart mEnd = do
    let startSql = maybe "1900-01-01" show mStart
        endSql = maybe "2999-12-31" show mEnd
    result <- liftIO $ runSqlPool
        (rawSql
            "SELECT t.id, t.doc_id, t.dbt_acc_id, COALESCE(d.name, ''), \
            \  t.crd_acc_id, COALESCE(c.name, ''), t.amount, t.date \
            \FROM acc_turn t \
            \LEFT JOIN acc_plan d ON t.dbt_acc_id = d.id \
            \LEFT JOIN acc_plan c ON t.crd_acc_id = c.id \
            \WHERE t.date >= ? AND t.date <= ? \
            \ORDER BY t.date DESC, t.id DESC"
            [ PersistText (T.pack startSql)
            , PersistText (T.pack endSql)
            ]) pool
    let entries = [ JournalEntry id docId dbtId dbtName crdId crdName amt dt
                  | (Single (id :: Int64), Single (docId :: Maybe Int64)
                    , Single (dbtId :: Int64), Single (dbtName :: Text)
                    , Single (crdId :: Int64), Single (crdName :: Text)
                    , Single (amt :: Double), Single (dt :: Day)) <- result
                  ]
    return $ QuerySuccess entries
