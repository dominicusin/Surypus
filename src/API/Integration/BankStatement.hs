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
import qualified Data.ByteString.Char8 as BSC
import Data.Time (UTCTime)
import DAL.Database (ConnectionPool, runDb)
import DAL.Types (QueryResult(..))
import Integration.ImportExport (ImportStatus(..))
import qualified Integration.BankStatement as IBS
import Database.Persist.Sql (SqlPersistT, rawSql, rawExecute, PersistValue(..), rawQuery)
import qualified Data.Conduit as C
import qualified Data.Conduit.List as CL
import Control.Monad.Trans.Resource (runResourceT)



-- | Unmatched transaction for manual review
data UnmatchedTxn = UnmatchedTxn
  { utId :: Text
  , utDate :: Text
  , utAmount :: Double
  , utDescription :: Maybe Text
  , utRef :: Maybe Text
  } deriving (Show, Eq, Generic)

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

-- | Import status response
data ImportStatusResponse = ImportStatusResponse
  { isrImportId :: Text
  , isrFilename :: Text
  , isrFormat :: Text
  , isrTotalRows :: Int
  , isrStatus :: Text
  , isrCreatedAt :: Text
  } deriving (Show, Eq, Generic)

instance ToJSON ImportStatusResponse
instance FromJSON ImportStatusResponse

-- | Upload and process bank statement file
uploadBankStatement :: ConnectionPool -> UploadRequest -> IO (QueryResult UploadResponse)
uploadBankStatement pool request = do
  -- Parse based on format
  let txns = case urFormat request of
        "OFX" -> IBS.parseOFX (urContent request)
        "ISO20022" -> IBS.parseISO20022 (urContent request)
        _ -> []
  
  if null txns
    then return $ QueryError "No transactions parsed from file"
    else do
        -- Import to database
       importRes <- IBS.importStatementLines pool (urTenantId request) (urFilename request) txns
       case importRes of
         QueryError err -> return $ QueryError err
         QuerySuccess importResult -> do
           -- Match transactions to bills
           matchRes <- IBS.matchTransactionsToBills pool (IBS.irImportId importResult)
           case matchRes of
             QueryError err -> return $ QueryError err
             QuerySuccess matchResult -> do
               -- Flag unmatched transactions
               _ <- IBS.flagUnmatchedTransactions pool (IBS.irImportId importResult)
               return $ QuerySuccess $ UploadResponse
                 { uprImportId = IBS.irImportId importResult
                 , uprRowCount = IBS.irRowCount importResult
                 , uprMatchedCount = IBS.mrMatchedCount matchResult
                 , uprUnmatchedCount = IBS.mrUnmatchedCount matchResult
                 , uprStatus = "completed"
                 }

-- | Get import status
getImportStatus :: ConnectionPool -> Text -> IO (QueryResult ImportStatusResponse)
getImportStatus pool importId = do
   rows <- runDb pool $ runResourceT $ rawQuery
     "SELECT id::TEXT, filename, format, total_rows, status, created_at \
     \FROM bank_statement_import WHERE id = ?"
     [PersistText importId] C.$$ CL.consume
   case rows of
     [[PersistText id', PersistText filename, PersistText format, PersistInt64 totalRows, PersistText status, PersistText createdAt]] ->
       pure $ QuerySuccess $ ImportStatusResponse
         { isrImportId = id'
         , isrFilename = filename
         , isrFormat = format
         , isrTotalRows = fromIntegral totalRows
         , isrStatus = status
         , isrCreatedAt = createdAt
         }
     [] -> pure $ QueryError "Import not found"
     _ -> pure $ QueryError "Multiple imports found"

-- | Get unmatched transactions for manual review
getUnmatchedTransactions :: ConnectionPool -> Text -> IO (QueryResult [UnmatchedTxn])
getUnmatchedTransactions pool importId = do
  rows <- runDb pool $ runResourceT $ rawQuery
    "SELECT id::TEXT, txn_date, amount, description, ref_number \
    \FROM bank_statement_line \
    \WHERE import_id = ? AND needs_review = true \
    \ORDER BY txn_date"
    [PersistText importId] C.$$ CL.consume
  pure $ QuerySuccess $ map (\([PersistText utId, PersistText utDate, PersistDouble utAmount, PersistText utDescription, PersistText utRef]) ->
     UnmatchedTxn utId utDate utAmount (Just utDescription) (Just utRef)) rows
