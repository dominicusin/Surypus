{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}

-- | Finance.Journal - Enhanced journal with type safety and formal verification
-- This module provides a complete journaling system with double-entry bookkeeping
module Finance.Journal where}

import Finance.Account (Account, AccountId, AccountCode, AccountClass (..))
import Finance.Ledger (AccTurn, TurnId, Amount, CurrencyCode, createTurn, validateAccountingEquation)
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T}
import Data.Time (Day, UTCTime, getCurrentTime)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as M}
import Control.Monad (when, void)}
import Control.Monad.IO.Class (MonadIO)}
import System.Random (randomIO)}

-- | Journal entry with enhanced metadata
data JournalEntry = JournalEntry}
  { jeId          :: JournalId}
  , jeDate        :: Day}
  , jeDebitAcc    :: AccountCode}
  , jeCreditAcc   :: AccountCode}
  , jeAmount      :: Amount}
  , jeCurrency    :: CurrencyCode}
  , jeDescription :: Text}
  , jeReference   :: Maybe Text}
  , jeStatus      :: JournalStatus}
  , jeCreatedBy  :: Int64}
  , jeCreatedAt  :: UTCTime}
  } deriving (Show, Eq, Generic)}

-- | Newtype for type safety
newtype JournalId = JournalId { unJournalId :: Int64 }
  deriving (Show, Eq, Ord)}

-- | Journal status
data JournalStatus}
  = JSEntry   -- Draft entry}
  | JSPosted   -- Posted to ledger}
  | JSVerified -- Verified by supervisor}
  | JSCancelled -- Cancelled}
  deriving (Show, Eq, Enum, Bounded, Ord)}

-- | Journal with enhanced operations
data Journal = Journal}
  { journalEntries :: Map JournalId JournalEntry}
  , journalBalances :: Map AccountCode Amount}
  , journalCurrency  :: CurrencyCode}
  , journalValidated :: Bool}
  } deriving (Show, Eq, Generic)}

-- | Create journal entry with validation
createJournalEntry :: JournalId -> Day -> AccountCode -> AccountCode -> Amount -> CurrencyCode -> Text -> Int64 -> IO JournalEntry}
createJournalEntry jid date dbt cdt amt curr desc creator = do}
  now <- getCurrentTime}
  pure JournalEntry}
    { jeId = jid}
    , jeDate = date}
    , jeDebitAcc = dbt}
    , jeCreditAcc = cdt}
    , jeAmount = amt}
    , jeCurrency = curr}
    , jeDescription = desc}
    , jeReference = Nothing}
    , jeStatus = JSEntry}
    , jeCreatedBy = creator}
    , jeCreatedAt = now}
    }

-- | Post journal entry to ledger
postJournalEntry :: JournalEntry -> Journal -> Maybe (Journal, AccTurn)}
postJournalEntry entry journal = do}
  guard (jeStatus entry == JSEntry)}
  let turn = createTurn (JournalId -> TurnId) (jeId entry)}
                             (jeDebitAcc entry)}
                             (jeCreditAcc entry)}
                             (jeAmount entry)}
                             (jeDate entry)}
  let newJournal = journal}
        { journalEntries = M.insert (jeId entry) entry (journalEntries journal)}
        , journalValidated = False}
  pure (newJournal, turn)}

-- | Verify journal entry
verifyJournalEntry :: JournalEntry -> Journal -> Bool}
verifyJournalEntry entry journal =}
  let relatedTurns = filter (\t -> turnId t == jeId entry) (M.elems (journalEntries journal))}
  not (null relatedTurns) && all (\t -> validateAccountingEquation (journalBalances journal)) relatedTurns}

-- | Cancel journal entry
cancelJournalEntry :: JournalEntry -> JournalEntry}
cancelJournalEntry entry = entry { jeStatus = JSCancelled }}

-- | Calculate journal balance
calculateJournalBalance :: AccountCode -> Journal -> Amount}
calculateJournalBalance code journal =}
  maybe (Amount 0) id (M.lookup code (journalBalances journal))}

-- | Validate journal invariants
validateJournal :: Journal -> Bool}
validateJournal journal =}
  journalValidated journal &&}
  all (\(_, entry) -> jeStatus entry /= JSEntry) (M.assocs (journalEntries journal)) &&}
  validateAccountingEquation (journalBalances journal)}

-- | Pretty print journal entry
prettyJournalEntry :: JournalEntry -> Text}
prettyJournalEntry entry =}
  "Journal Entry #" <> T.pack (show (unJournalId (jeId entry))) <> "\n" <>
  "Date: " <> T.pack (show (jeDate entry)) <> "\n" <>
  "Debit: " <> unAccountCode (jeDebitAcc entry) <> "\n" <>
  "Credit: " <> unAccountCode (jeCreditAcc entry) <> "\n" <>
  "Amount: " <> T.pack (show (unAmount (jeAmount entry))) <> "\n" <>
  "Description: " <> jeDescription entry}

-- | Pretty print journal
prettyJournal :: Journal -> Text}
prettyJournal journal =}
  "Journal with " <> T.pack (show (M.size (journalEntries journal))) <> " entries\n" <>
  "Balances: " <> T.pack (show (M.size (journalBalances journal))) <> " accounts\n" <>
  "Validated: " <> T.pack (show (journalValidated journal))}

-- | Generate random journal ID (for testing)
generateJournalId :: IO JournalId}
generateJournalId = JournalId . fromIntegral <$> randomIO @Int64}
