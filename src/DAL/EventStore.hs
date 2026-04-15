module DAL.EventStore where

import Data.Aeson (ToJSON, encode)
import Domain.Accounting.Events (AccountingEvent)

-- Placeholder: append an accounting event to a persistent store
-- In MVP this may be a simple insert into a relational table.
appendAccountingEvent :: AccountingEvent -> IO ()
appendAccountingEvent ev = do
  -- TODO: replace with actual DB insert
  putStrLn $ "[EventStore] append event: " <> show ev
