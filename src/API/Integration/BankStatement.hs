{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}

-- | REST API endpoints for bank statement import
module API.Integration.BankStatement
  ( uploadBankStatement
  , getImportStatus
  , getUnmatchedTransactions
  ) where

import Data.Text (Text)
import qualified Data.Text as T
import Data.Aeson (ToJSON, FromJSON, encode, decode, Value, object, (.=))
import GHC.Generics (Generic)
import qualified Data.ByteString.Lazy as BL
import qualified Data.ByteString.Char8 as BS
import Data.Time (UTCTime)
import DAL.Database (Pool, usePool)
import DAL.Types (QueryResult(..))
import qualified Integration.BankStatement as BS
import qualified Hasql.Session as Session
import Hasql.Statement (Statement(..))
import qualified Hasql.Decoders as D
import qualified Hasql.Encoders as E
import Data.Functor.Contravariant ((>$<))

-- | Request for bank statement upload
data UploadRequest = UploadRequest
  { urTenantId :: Text
  , urFilename :: Text
  , urFormat :: Text  -- "OFX" or "ISO20022"
  , urContent :: Text
  } deriving (Show, Eq, Generic)

instance ToJSON UploadRequest
instance FromJSON UploadRequest

-- | Response for bank statement upload
data UploadResponse = UploadResponse
  { uprImportId :: Text
  , uprRowCount :: Int
  , uprMatchedCount :: Int
  , uprUnmatchedCount :: Int
  , uprStatus :: Text
  } deriving (Show, Eq, Generic)

instance ToJSON UploadResponse
instance FromJSON UploadResponse

-- | Upload and process bank statement file
uploadBankStatement :: Pool -> UploadRequest -> IO (QueryResult UploadResponse)
uploadBankStatement pool request = do
  -- Parse based on format
  let txns = case urFormat request of
        "OFX" -> BS.parseOFX (urContent request)
        "ISO20022" -> BS.parseISO20022 (urContent request)
        _ -> []
  
  if null txns
    then return $ QueryError "No transactions parsed from file"
    else do
      -- Import to database
      importRes <- BS.importStatementLines pool (urTenantId request) (urFilename request) txns
      case importRes of
        QueryError err -> return $ QueryError err
        QuerySuccess importResult -> do
          -- Match transactions to bills
          matchRes <- BS.matchTransactionsToBills pool (BS.irImportId importResult)
          case matchRes of
            QueryError err -> return $ QueryError err
            QuerySuccess matchResult -> do
              -- Flag unmatched transactions
              _ <- BS.flagUnmatchedTransactions pool (BS.irImportId importResult)
              return $ QuerySuccess $ UploadResponse
                { uprImportId = BS.irImportId importResult
                , uprRowCount = BS.irRowCount importResult
                , uprMatchedCount = BS.mrMatchedCount matchResult
                , uprUnmatchedCount = BS.mrUnmatchedCount matchResult
                , uprStatus = "completed"
                }

-- | Get import status
data ImportStatus = ImportStatus
  { isImportId :: Text
  , isFilename :: Text
  , isFormat :: Text
  , isTotalRows :: Int
  , isStatus :: Text
  , isCreatedAt :: UTCTime
  } deriving (Show, Eq, Generic)

instance ToJSON ImportStatus
instance FromJSON ImportStatus

getImportStatus :: Pool -> Text -> IO (QueryResult ImportStatus)
getImportStatus pool importId = do
  let stmt = Statement
        "SELECT id::TEXT, filename, format, total_rows, status, created_at \
        \FROM bank_statement_import WHERE id = $1::UUID"
        (E.param (E.nonNullable E.text))
        (D.rowMaybe $ ImportStatus
          <$> D.column (D.nonNullable D.text)
          <*> D.column (D.nonNullable D.text)
          <*> D.column (D.nonNullable D.text)
          <*> (fromIntegral <$> D.column (D.nonNullable D.int4))
          <*> D.column (D.nonNullable D.text)
          <*> D.column (D.nonNullable D.timestamptz))
        True
  res <- usePool pool $ Session.statement importId stmt
  case res of
    Left err -> return $ QueryError (T.pack $ show err)
    Right Nothing -> return $ QueryError "Import not found"
    Right (Just status) -> return $ QuerySuccess status

-- | Get unmatched transactions for manual review
data UnmatchedTxn = UnmatchedTxn
  { utId :: Text
  , utDate :: Text
  , utAmount :: Double
  , utDescription :: Maybe Text
  , utRef :: Maybe Text
  } deriving (Show, Eq, Generic)

instance ToJSON UnmatchedTxn
instance FromJSON UnmatchedTxn

getUnmatchedTransactions :: Pool -> Text -> IO (QueryResult [UnmatchedTxn])
getUnmatchedTransactions pool importId = do
  let stmt = Statement
        "SELECT id::TEXT, txn_date, amount, description, ref_number \
        \FROM bank_statement_line \
        \WHERE import_id = $1::UUID AND needs_review = true \
        \ORDER BY txn_date"
        (E.param (E.nonNullable E.text))
        (D.rowList $ UnmatchedTxn
          <$> D.column (D.nonNullable D.text)
          <*> D.column (D.nonNullable D.text)
          <*> D.column (D.nonNullable D.float8)
          <*> D.column (D.nullable D.text)
          <*> D.column (D.nullable D.text))
        True
  res <- usePool pool $ Session.statement importId stmt
  case res of
    Left err -> return $ QueryError (T.pack $ show err)
    Right txns -> return $ QuerySuccess txns
