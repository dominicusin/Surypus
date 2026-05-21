{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}

-- | Bank statement import — OFX and ISO 20022 (camt.053) parsing
module Integration.BankStatement
  ( BankTxn  (..)
  , ImportResult  (..)
  , parseOFX
  , parseISO20022
  , importStatementLines
  ) where

import Data.Text (Text)
import qualified Data.Text as T
import Data.Aeson (ToJSON, FromJSON)
import GHC.Generics (Generic)
import qualified Hasql.Decoders as D
import qualified Hasql.Encoders as E
import qualified Hasql.Session as Session
import Hasql.Statement (Statement  (..))
import Data.Functor.Contravariant ((>$<))
import DAL.Database (Pool, usePool)
import DAL.Types (QueryResult  (..))

data BankTxn = BankTxn
  { btDate        :: !Text
  , btValueDate   :: !(Maybe Text)
  , btAmount      :: !Double
  , btCurrency    :: !Text
  , btDescription :: !(Maybe Text)
  , btRef         :: !(Maybe Text)
  , btCounterparty :: !(Maybe Text)
  } deriving (Show, Eq, Generic)

instance ToJSON BankTxn
instance FromJSON BankTxn

data ImportResult = ImportResult
  { irImportId :: !Text
  , irRowCount :: !Int
  , irStatus   :: !Text
  } deriving (Show, Eq, Generic)

instance ToJSON ImportResult

-- | Parse OFX text into transactions.
-- OFX is SGML-like; we extract STMTTRN blocks with simple text scanning.
parseOFX :: Text -> [BankTxn]
parseOFX content =
  let blocks = extractBlocks "<STMTTRN>" "</STMTTRN>" content
  in map parseTxnBlock blocks

extractBlocks :: Text -> Text -> Text -> [Text]
extractBlocks open close txt
  | T.null txt = []
  | otherwise =
      case T.breakOn open txt of
        (_, rest) | T.null rest -> []
        (_, rest) ->
          let body = T.drop (T.length open) rest
          in case T.breakOn close body of
               (block, remaining) -> block : extractBlocks open close (T.drop (T.length close) remaining)

parseTxnBlock :: Text -> BankTxn
parseTxnBlock block = BankTxn
  { btDate        = getField "DTPOSTED" block
  , btValueDate   = Just (getField "DTAVAIL" block)
  , btAmount      = read $ T.unpack $ getField "TRNAMT" block
  , btCurrency    = "RUB"
  , btDescription = Just (getField "MEMO" block)
  , btRef         = Just (getField "FITID" block)
  , btCounterparty = Nothing
  }

getField :: Text -> Text -> Text
getField tag block =
  case T.breakOn ("<" <> tag <> ">") block of
    (_, rest) | T.null rest -> ""
    (_, rest) ->
      let val = T.drop (T.length tag + 2) rest
      in T.takeWhile (/= '<') val

-- | Parse ISO 20022 camt.053 XML into transactions.
-- Extracts Ntry/TxDtls blocks via simple text scanning.
parseISO20022 :: Text -> [BankTxn]
parseISO20022 content =
  let blocks = extractBlocks "<Ntry>" "</Ntry>" content
  in map parseNtryBlock blocks

parseNtryBlock :: Text -> BankTxn
parseNtryBlock block = BankTxn
  { btDate        = getXmlField "BookgDt" "Dt" block
  , btValueDate   = Just (getXmlField "ValDt" "Dt" block)
  , btAmount      = read $ T.unpack $ getXmlField "Amt" "" block
  , btCurrency    = "RUB"
  , btDescription = Just (getXmlField "AddtlNtryInf" "" block)
  , btRef         = Just (getXmlField "AcctSvcrRef" "" block)
  , btCounterparty = Just (getXmlField "Nm" "" block)
  }

getXmlField :: Text -> Text -> Text -> Text
getXmlField outer inner block =
  let tag = if T.null inner then outer else inner
      open = "<" <> tag <> ">"
      close = "</" <> tag <> ">"
  in case T.breakOn open block of
       (_, rest) | T.null rest -> ""
       (_, rest) ->
         let val = T.drop (T.length open) rest
         in T.takeWhile (/= '<') val

-- | Persist parsed transactions to DB under a new import record
importStatementLines :: Pool -> Text -> Text -> [BankTxn] -> IO (QueryResult ImportResult)
importStatementLines pool tenantId filename txns = do
  -- Create import header
  let hdrStmt = Statement
        "INSERT INTO bank_statement_import (tenant_id, filename, format, total_rows, status) \
        \VALUES ($1::UUID, $2, 'OFX', $3, 'done') RETURNING id::TEXT"
        (((\(t,_,_) -> t) >$< E.param (E.nonNullable E.text))
          <> ((\(_,f,_) -> f) >$< E.param (E.nonNullable E.text))
          <> ((\(_,_,n) -> fromIntegral n) >$< E.param (E.nonNullable E.int4)))
        (D.singleRow (D.column (D.nonNullable D.text)))
        True
  hdrRes <- usePool pool $ Session.statement (tenantId, filename, length txns) hdrStmt
  case hdrRes of
    Left err -> return $ QueryError (T.pack $ show err)
    Right importId -> do
      -- Insert lines
      let lineStmt = Statement
            "INSERT INTO bank_statement_line \
            \(import_id, txn_date, value_date, amount, currency, description, ref_number, counterparty) \
            \VALUES ($1::UUID, $2::DATE, $3::DATE, $4, $5, $6, $7, $8)"
            (((\(i,_,_,_,_,_,_,_) -> i) >$< E.param (E.nonNullable E.text))
              <> ((\(_,d,_,_,_,_,_,_) -> d) >$< E.param (E.nonNullable E.text))
              <> ((\(_,_,v,_,_,_,_,_) -> v) >$< E.param (E.nullable E.text))
              <> ((\(_,_,_,a,_,_,_,_) -> a) >$< E.param (E.nonNullable E.float8))
              <> ((\(_,_,_,_,c,_,_,_) -> c) >$< E.param (E.nonNullable E.text))
              <> ((\(_,_,_,_,_,d2,_,_) -> d2) >$< E.param (E.nullable E.text))
              <> ((\(_,_,_,_,_,_,r,_) -> r) >$< E.param (E.nullable E.text))
              <> ((\(_,_,_,_,_,_,_,cp) -> cp) >$< E.param (E.nullable E.text)))
            D.noResult
            True
      mapM_ (\t -> usePool pool $ Session.statement
              (importId, btDate t, btValueDate t, btAmount t, btCurrency t,
               btDescription t, btRef t, btCounterparty t) lineStmt) txns
      return $ QuerySuccess $ ImportResult importId (length txns) "done"
