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
import DAL.Database (Pool, runQuery, runCommand)
import DAL.Types (QueryResult(..))
import qualified Integration.BankStatement as BS
import qualified Opaleye as OE
import qualified Opaleye.Internal.HaskellDB.PrimQuery as OPQ
import qualified Opaleye.Internal.PGTypes as OPG
import qualified Opaleye.Internal.Tag as OITag
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
getImportStatus :: Pool -> Text -> IO (QueryResult ImportStatus)
getImportStatus pool importId = do
   let query = OE.sql 
         "SELECT id::TEXT, filename, format, total_rows, status, created_at \
         \FROM bank_statement_import WHERE id = $1::UUID"
         (OE.makeColumns (,,,,,) 
            OE.text
            OE.text
            OE.text
            OE.int4
            OE.text
            OE.timestamptz
         ) (OE.required . fst)
   result <- runQuery pool query importId
   case result of
     Left err -> return $ QueryError (T.pack $ show err)
     Right [] -> return $ QueryError "Import not found"
     Right ((importId, filename, format, totalRows, status, createdAt):_) ->
        return $ QuerySuccess $ ImportStatus
          importId
          filename
          format
          (fromIntegral totalRows)
          status
          createdAt

-- | Get unmatched transactions for manual review
getUnmatchedTransactions :: Pool -> Text -> IO (QueryResult [UnmatchedTxn])
getUnmatchedTransactions pool importId = do
   let query = OE.sql 
         "SELECT id::TEXT, txn_date, amount, description, ref_number \
         \FROM bank_statement_line \
         \WHERE import_id = $1::UUID AND needs_review = true \
         \ORDER BY txn_date"
         (OE.makeColumns (,,,,) 
            OE.text
            OE.text
            OE.double
            (OE.maybe OE.text)
            (OE.maybe OE.text)
         ) (OE.required . fst)
   result <- runQuery pool query importId
   case result of
     Left err -> return $ QueryError (T.pack $ show err)
     Right cols -> return $ QuerySuccess $ map (\(utId, utDate, utAmount, utDescription, utRef) ->
        UnmatchedTxn utId utDate utAmount utDescription utRef) cols
