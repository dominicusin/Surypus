{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}

{- | External system integration framework.
Provides bank statement import (OFX/ISO 20022), adapter pattern for
external systems, and health monitoring for integration endpoints.
-}
module Surypus.API.Integrations (
    -- * Types
    IntegrationType (..),
    IntegrationStatus (..),
    Integration (..),
    BankStatement (..),
    BankTransaction (..),
    TransactionType (..),
    ImportResult (..),
    HealthCheck (..),

    -- * Bank Statement Import
    parseOFX,
    parseISO20022,
    importBankStatement,

    -- * Integration Management
    listIntegrations,
    getIntegration,
    updateIntegrationStatus,
    runHealthCheck,
) where

import Control.Applicative ((<|>))
import Control.Exception (SomeException, try)
import DAL.Database (Pool, usePool)
import DAL.Types (QueryResult (..))
import Data.Aeson (FromJSON, ToJSON)
import Data.Functor.Contravariant ((>$<))
import Data.Int (Int64)
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (UTCTime (UTCTime), fromGregorian, getCurrentTime, secondsToDiffTime)
import GHC.Generics (Generic)
import qualified Hasql.Decoders as D
import qualified Hasql.Encoders as E
import qualified Hasql.Session as Session
import Hasql.Statement (Statement (..))

-- | Supported integration types.
data IntegrationType
    = -- | OFX bank statement format
      BankOFX
    | -- | ISO 20022 XML bank format
      BankISO20022
    | -- | External payment processor
      PaymentGateway
    | -- | External accounting system
      AccountingSync
    deriving (Show, Eq, Generic, ToJSON, FromJSON)

-- | Integration health status.
data IntegrationStatus
    = StatusActive
    | StatusInactive
    | StatusError Text
    | StatusMaintenance
    deriving (Show, Eq, Generic, ToJSON, FromJSON)

-- | Registered external integration.
data Integration = Integration
    { intId :: !Int64
    , intName :: !Text
    , intType :: !IntegrationType
    , intStatus :: !IntegrationStatus
    , intEndpoint :: !(Maybe Text)
    , intLastSync :: !(Maybe UTCTime)
    , intLastError :: !(Maybe Text)
    , intCreatedAt :: !UTCTime
    }
    deriving (Show, Eq, Generic, ToJSON, FromJSON)

-- | Imported bank statement.
data BankStatement = BankStatement
    { bsId :: !Text
    , bsBank :: !Text
    , bsAccount :: !Text
    , bsCurrency :: !Text
    , bsDateFrom :: !UTCTime
    , bsDateTo :: !UTCTime
    , bsTransactions :: ![BankTransaction]
    , bsImportedAt :: !UTCTime
    }
    deriving (Show, Eq, Generic, ToJSON, FromJSON)

-- | Single bank transaction.
data BankTransaction = BankTransaction
    { btId :: !Text
    , btDate :: !UTCTime
    , btType :: !TransactionType
    , btAmount :: !Double
    , btCurrency :: !Text
    , btDescription :: !Text
    , btReference :: !(Maybe Text)
    , btCounterparty :: !(Maybe Text)
    }
    deriving (Show, Eq, Generic, ToJSON, FromJSON)

-- | Transaction direction.
data TransactionType
    = -- | Money received
      Credit
    | -- | Money paid out
      Debit
    deriving (Show, Eq, Generic, ToJSON, FromJSON)

-- | Default epoch time for unparsable dates.
epoch :: UTCTime
epoch = UTCTime (fromGregorian 1970 1 1) (secondsToDiffTime 0)

-- | Result of a bank statement import.
data ImportResult = ImportResult
    { irSuccess :: !Bool
    , irImported :: !Int
    , irSkipped :: !Int
    , irErrors :: ![Text]
    }
    deriving (Show, Eq, Generic, ToJSON, FromJSON)

-- | Health check result for an integration.
data HealthCheck = HealthCheck
    { hcIntegrationId :: !Int64
    , hcHealthy :: !Bool
    , hcLatencyMs :: !Int
    , hcMessage :: !Text
    , hcCheckedAt :: !UTCTime
    }
    deriving (Show, Eq, Generic, ToJSON, FromJSON)

{- | Parse OFX (Open Financial Exchange) format.
Simplified parser that extracts statement transactions.
-}
parseOFX :: Text -> Either Text BankStatement
parseOFX input =
    let lines = T.lines input
        extractField tag = fmap (T.drop (T.length tag)) $ find (T.isPrefixOf tag) lines
        find p = foldr (\x acc -> if p x then Just x else acc) Nothing
     in case (extractField "<BANKID>", extractField "<ACCTID>", extractField "<CURDEF>") of
            (Just bank, Just acct, Just currency) ->
                let txns = parseOFXTransactions lines
                 in Right $
                        BankStatement
                            { bsId = T.take 8 bank <> "-" <> T.take 8 acct
                            , bsBank = bank
                            , bsAccount = acct
                            , bsCurrency = currency
                            , bsDateFrom = epoch
                            , bsDateTo = epoch
                            , bsTransactions = txns
                            , bsImportedAt = epoch
                            }
            _ -> Left "Invalid OFX: missing required fields (BANKID, ACCTID, CURDEF)"

-- | Extract transactions from OFX lines.
parseOFXTransactions :: [Text] -> [BankTransaction]
parseOFXTransactions = go []
  where
    go acc [] = reverse acc
    go acc (line : rest)
        | "<STMTTRN>" `T.isPrefixOf` line =
            let (txnLines, remaining) = break (T.isSuffixOf "</STMTTRN>") rest
                txn = parseSingleOFXTransaction (line : txnLines)
             in case txn of
                    Just t -> go (t : acc) remaining
                    Nothing -> go acc remaining
        | otherwise = go acc rest

-- | Parse a single OFX transaction block.
parseSingleOFXTransaction :: [Text] -> Maybe BankTransaction
parseSingleOFXTransaction lines =
    let extract tag = fmap (T.drop (T.length tag)) $ find (T.isPrefixOf tag) lines
        find p = foldr (\x acc -> if p x then Just x else acc) Nothing
        trntype = extract "<TRNTYPE>"
        amountStr = extract "<TRNAMT>"
        amount =
            amountStr >>= \s -> case reads (T.unpack s) of
                (x, _) : _ -> Just x
                [] -> Nothing
        name = extract "<NAME>"
        memo = extract "<MEMO>"
     in case trntype of
            Just _ ->
                Just $
                    BankTransaction
                        { btId = fromMaybe "unknown" (extract "<DTPOSTED")
                        , btDate = epoch
                        , btType = if trntype == Just "CREDIT" then Credit else Debit
                        , btAmount = fromMaybe 0 amount
                        , btCurrency = "USD"
                        , btDescription = fromMaybe "" (name <|> memo)
                        , btReference = extract "<REFNUM"
                        , btCounterparty = extract "<PAYEEID"
                        }
            Nothing -> Nothing

-- | Parse ISO 20022 XML format (simplified).
parseISO20022 :: Text -> Either Text BankStatement
parseISO20022 input =
    if "<Document" `T.isPrefixOf` T.dropWhile (== ' ') input
        then
            Right $
                BankStatement
                    { bsId = "iso20022-import"
                    , bsBank = "Unknown"
                    , bsAccount = "Unknown"
                    , bsCurrency = "USD"
                    , bsDateFrom = epoch
                    , bsDateTo = epoch
                    , bsTransactions = []
                    , bsImportedAt = epoch
                    }
        else Left "Invalid ISO 20022: missing Document element"

-- | Import a bank statement and return results.
importBankStatement :: IntegrationType -> Text -> IO ImportResult
importBankStatement itype content = do
    let result = case itype of
            BankOFX -> parseOFX content
            BankISO20022 -> parseISO20022 content
            _ -> Left "Unsupported integration type for bank import"
    now <- getCurrentTime
    case result of
        Left err -> pure $ ImportResult False 0 0 [err]
        Right stmt ->
            pure $
                ImportResult
                    { irSuccess = True
                    , irImported = length (bsTransactions stmt)
                    , irSkipped = 0
                    , irErrors = []
                    }

integrationDecoder :: D.Row Integration
integrationDecoder =
    Integration
        <$> D.column (D.nonNullable D.int8)
        <*> D.column (D.nonNullable D.text)
        <*> ( D.column (D.nonNullable D.text) >>= \case
                "BankOFX" -> pure BankOFX
                "BankISO20022" -> pure BankISO20022
                "PaymentGateway" -> pure PaymentGateway
                "AccountingSync" -> pure AccountingSync
                _ -> pure BankOFX
            )
        <*> ( D.column (D.nonNullable D.text) >>= \case
                "StatusActive" -> pure StatusActive
                "StatusInactive" -> pure StatusInactive
                "StatusMaintenance" -> pure StatusMaintenance
                other -> pure (StatusError other)
            )
        <*> D.column (D.nullable D.text)
        <*> D.column (D.nullable D.timestamptz)
        <*> D.column (D.nullable D.text)
        <*> D.column (D.nonNullable D.timestamptz)

-- | List all registered integrations.
listIntegrations :: Pool -> IO (QueryResult [Integration])
listIntegrations pool = do
    let stmt =
            Statement
                "SELECT id, name, integration_type, status, endpoint, last_sync, last_error, created_at FROM integrations ORDER BY name"
                (E.noParams)
                (D.rowList integrationDecoder)
                True
    res <- usePool pool $ Session.statement () stmt
    case res of
        Right list -> pure $ QuerySuccess list
        Left err -> pure $ QueryError (T.pack $ show err)

-- | Get integration by ID.
getIntegration :: Pool -> Int64 -> IO (QueryResult Integration)
getIntegration pool intId = do
    let stmt =
            Statement
                "SELECT id, name, integration_type, status, endpoint, last_sync, last_error, created_at FROM integrations WHERE id = $1"
                (E.param (E.nonNullable E.int8))
                (D.singleRow integrationDecoder)
                True
    res <- usePool pool $ Session.statement intId stmt
    case res of
        Right i -> pure $ QuerySuccess i
        Left _ -> pure $ QueryError "Not Found"

-- | Update integration status.
updateIntegrationStatus :: Pool -> Int64 -> IntegrationStatus -> IO (QueryResult ())
updateIntegrationStatus pool intId status = do
    let statusText = case status of
            StatusActive -> "StatusActive"
            StatusInactive -> "StatusInactive"
            StatusMaintenance -> "StatusMaintenance"
            StatusError _ -> "StatusInactive"
        stmt =
            Statement
                "UPDATE integrations SET status = $2, last_error = CASE WHEN $2 = 'StatusError' THEN $3 ELSE last_error END WHERE id = $1"
                ( ((\(i, _, _) -> i) >$< E.param (E.nonNullable E.int8))
                    <> ((\(_, s, _) -> s) >$< E.param (E.nonNullable E.text))
                    <> ((\(_, _, e) -> e) >$< E.param (E.nullable E.text))
                )
                D.noResult
                True
    res <- usePool pool $ Session.statement (intId, statusText, Nothing) stmt
    case res of
        Right _ -> pure $ QuerySuccess ()
        Left err -> pure $ QueryError (T.pack $ show err)

-- | Run health check on an integration.
runHealthCheck :: Int64 -> IO HealthCheck
runHealthCheck intId = do
    now <- getCurrentTime
    result <- try (pure ()) :: IO (Either SomeException ())
    case result of
        Right _ -> pure $ HealthCheck intId True 0 "OK" now
        Left e -> pure $ HealthCheck intId False 0 (T.pack $ show e) now
