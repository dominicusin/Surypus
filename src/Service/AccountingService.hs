module Service.AccountingService
  ( AccountingService (..),
    createAccountingService,
    processTransaction,
    getAccountBalance,
    getAccountTurnovers,
    generateLedger,
    validateTransaction,
    Transaction (..),
    Entry (..),
    EntryType (..),
    TransactionResult (..),
    Ledger (..),
    LedgerEntry (..),
    Turnovers (..),
  )
where

import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (Day)
import qualified Hasql.Decoders as D
import qualified Hasql.Encoders as E
import Hasql.Pool (Pool, use)
import qualified Hasql.Session as Session
import Hasql.Statement (Statement)
import Surypus.Types (AppError (..), AppResult, Decimal (..))

newtype AccountingService = AccountingService
  { asPool :: Pool
  }

createAccountingService :: Pool -> AccountingService
createAccountingService = AccountingService

data Transaction = Transaction
  { tDate :: Day,
    tDescription :: Text,
    tEntries :: [Entry]
  }

data Entry = Entry
  { entryAccountId :: Int64,
    entryAmount :: Double,
    entryType :: EntryType
  }

data EntryType = Debit | Credit

newtype TransactionResult = TransactionProcessed Int64

newtype Ledger = Ledger {ledgerEntries :: [LedgerEntry]}

data LedgerEntry = LedgerEntry
  { leId :: Int64,
    leDate :: Day,
    leDescription :: Text,
    leAccountId :: Int64,
    leDebit :: Double,
    leCredit :: Double
  }

data Turnovers = Turnovers
  { trDebitTurnover :: Double,
    trCreditTurnover :: Double,
    trOpeningBalance :: Double,
    trClosingBalance :: Double
  }

validateTransaction :: Transaction -> Either Text ()
validateTransaction t
  | null (tEntries t) = Left "Transaction must have at least one entry"
  | not (isBalanced (tEntries t)) = Left "Transaction is not balanced: sum of debits must equal sum of credits"
  | otherwise = Right ()
  where
    isBalanced entries =
      let debitSum = sum [entryAmount e | e <- entries, entryType e == Debit]
          creditSum = sum [entryAmount e | e <- entries, entryType e == Credit]
       in abs (debitSum - creditSum) < 0.01

processTransaction :: AccountingService -> Transaction -> IO (Either Text TransactionResult)
processTransaction service transaction = do
  case validateTransaction transaction of
    Left err -> pure $ Left err
    Right _ -> do
      result <- use (asPool service) $ do
        let txSession = do
              Session.execute insertAccTurnStmt (toParams transaction)
              Session.query selectLastIdStmt () :: Session.Session (Session.Result Int64)
        Session.run txSession
      pure $ case result of
        Left err -> Left (T.pack (show err))
        Right [txId] -> Right (TransactionProcessed txId)
        Right _ -> Left "Unexpected result"

getAccountBalance :: AccountingService -> Int64 -> IO (Either Text Double)
getAccountBalance service accountId = do
  result <- use (asPool service) $ Session.query selectBalanceStmt accountId
  pure $ case result of
    Left err -> Left (T.pack (show err))
    Right [] -> Right 0.0
    Right [(bal, _)] -> Right (fromIntegral (bal :: Int64) / 100.0)
    Right _ -> Right 0.0

getAccountTurnovers :: AccountingService -> Int64 -> Day -> Day -> IO (Either Text Turnovers)
getAccountTurnovers service accountId fromDate toDate = do
  result <-
    use (asPool service) $
      Session.query
        selectTurnoversStmt
        ( accountId,
          fromDate,
          toDate
        )
  pure $ case result of
    Left err -> Left (T.pack (show err))
    Right [(opening, debitT, creditT, closing)] ->
      Right
        Turnovers
          { trDebitTurnover = fromIntegral (debitT :: Int64) / 100.0,
            trCreditTurnover = fromIntegral (creditT :: Int64) / 100.0,
            trOpeningBalance = fromIntegral (opening :: Int64) / 100.0,
            trClosingBalance = fromIntegral (closing :: Int64) / 100.0
          }
    Right _ -> Right (Turnovers 0 0 0 0)

generateLedger :: AccountingService -> Day -> Day -> IO (Either Text Ledger)
generateLedger service fromDate toDate = do
  result <-
    use (asPool service) $
      Session.query
        selectLedgerStmt
        ( fromDate,
          toDate
        )
  pure $ case result of
    Left err -> Left (T.pack (show err))
    Right rows ->
      Right
        Ledger
          { ledgerEntries =
              [ LedgerEntry
                  { leId = rowId,
                    leDate = rowDate,
                    leDescription = rowDesc,
                    leAccountId = rowAccountId,
                    leDebit = fromIntegral rowDebit / 100.0,
                    leCredit = fromIntegral rowCredit / 100.0
                  }
                | (rowId, rowDate, rowDesc, rowAccountId, rowDebit, rowCredit) <- rows
              ]
          }

selectLastIdStmt :: Statement () Int64
selectLastIdStmt =
  Session.statement
    "SELECT currval('acc_turn_id_seq')"
    Session.noParams
    (D.singleRow (D.column (D.nonNullable D.int8)))

insertAccTurnStmt :: Statement (Day, Text, Int64, Int64, Int64) Int64
insertAccTurnStmt =
  Session.statement
    "INSERT INTO acc_turn (turn_date, description, debit_acc_id, credit_acc_id, amount) VALUES ($1, $2, $3, $4, $5) RETURNING id"
    ( (,,,)
        <$> (E.param . E.nonNullable $ E.date)
        <*> (E.param . E.nonNullable $ E.text)
        <*> (E.param . E.nonNullable $ E.int8)
        <*> (E.param . E.nonNullable $ E.int8)
        <*> (E.param . E.nonNullable $ E.int8)
    )
    (D.singleRow (D.column (D.nonNullable D.int8)))

selectBalanceStmt :: Statement Int64 (Int64, Int64)
selectBalanceStmt =
  Session.statement
    "SELECT COALESCE(SUM(debit_amount), 0) - COALESCE(SUM(credit_amount), 0), id FROM acc_turn WHERE account_id = $1 GROUP BY id"
    (E.param (E.nonNullable E.int8))
    ( D.rowList
        ( D.column (D.nonNullable D.int8),
          D.column (D.nonNullable D.int8)
        )
    )

selectTurnoversStmt :: Statement (Int64, Day, Day) (Int64, Int64, Int64, Int64)
selectTurnoversStmt =
  Session.statement
    "SELECT \
    \ (SELECT COALESCE(SUM(debit_amount - credit_amount), 0) FROM acc_turn WHERE account_id = $1 AND turn_date < $2) as opening, \
    \ COALESCE(SUM(CASE WHEN debit_amount > 0 THEN debit_amount ELSE 0 END), 0) as debit_turnover, \
    \ COALESCE(SUM(CASE WHEN credit_amount > 0 THEN credit_amount ELSE 0 END), 0) as credit_turnover, \
    \ (SELECT COALESCE(SUM(debit_amount - credit_amount), 0) FROM acc_turn WHERE account_id = $1 AND turn_date <= $3) as closing \
    \ FROM acc_turn WHERE account_id = $1 AND turn_date BETWEEN $2 AND $3"
    ( (,,)
        <$> E.param (E.nonNullable E.int8)
        <*> E.param (E.nonNullable E.date)
        <*> E.param (E.nonNullable E.date)
    )
    ( D.rowList
        ( D.column (D.nonNullable D.int8),
          D.column (D.nonNullable D.int8),
          D.column (D.nonNullable D.int8),
          D.column (D.nonNullable D.int8)
        )
    )

selectLedgerStmt :: Statement (Day, Day) [(Int64, Day, Text, Int64, Int64, Int64)]
selectLedgerStmt =
  Session.statement
    "SELECT id, turn_date, description, account_id, debit_amount, credit_amount \
    \ FROM acc_turn WHERE turn_date BETWEEN $1 AND $2 ORDER BY turn_date, id"
    ( (,)
        <$> E.param (E.nonNullable E.date)
        <*> E.param (E.nonNullable E.date)
    )
    ( D.rowList
        ( D.column (D.nonNullable D.int8),
          D.column (D.nonNullable D.date),
          D.column (D.nonNullable D.text),
          D.column (D.nonNullable D.int8),
          D.column (D.nonNullable D.int8),
          D.column (D.nonNullable D.int8)
        )
    )

toParams :: Transaction -> (Day, Text, Int64, Int64, Int64)
toParams t = case tEntries t of
  [debitEntry, creditEntry] ->
    ( tDate t,
      tDescription t,
      entryAccountId debitEntry,
      entryAccountId creditEntry,
      round (entryAmount debitEntry * 100)
    )
  _ -> (tDate t, tDescription t, 0, 0, 0)
