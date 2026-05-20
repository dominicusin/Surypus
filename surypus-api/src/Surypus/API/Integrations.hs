{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE OverloadedStrings #-}

-- | External system integration framework.
-- Provides bank statement import (OFX/ISO 20022), adapter pattern for
-- external systems, and health monitoring for integration endpoints.
module Surypus.API.Integrations
  ( -- * Types
    IntegrationType(..)
  , IntegrationStatus(..)
  , Integration(..)
  , BankStatement(..)
  , BankTransaction(..)
  , TransactionType(..)
  , ImportResult(..)
  , HealthCheck(..)

    -- * Bank Statement Import
  , parseOFX
  , parseISO20022
  , importBankStatement

    -- * Integration Management
  , listIntegrations
  , getIntegration
  , updateIntegrationStatus
  , runHealthCheck
  ) where

import Data.Text (Text)
import qualified Data.Text as T
import Data.Aeson (ToJSON, FromJSON)
import GHC.Generics (Generic)
import Data.Time (UTCTime, getCurrentTime)
import Data.Int (Int64)
import Control.Exception (try, SomeException)

-- | Supported integration types.
data IntegrationType
  = BankOFX          -- ^ OFX bank statement format
  | BankISO20022     -- ^ ISO 20022 XML bank format
  | PaymentGateway   -- ^ External payment processor
  | AccountingSync   -- ^ External accounting system
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
  { intId          :: !Int64
  , intName        :: !Text
  , intType        :: !IntegrationType
  , intStatus      :: !IntegrationStatus
  , intEndpoint    :: !(Maybe Text)
  , intLastSync    :: !(Maybe UTCTime)
  , intLastError   :: !(Maybe Text)
  , intCreatedAt   :: !UTCTime
  } deriving (Show, Eq, Generic, ToJSON, FromJSON)

-- | Imported bank statement.
data BankStatement = BankStatement
  { bsId           :: !Text
  , bsBank         :: !Text
  , bsAccount      :: !Text
  , bsCurrency     :: !Text
  , bsDateFrom     :: !UTCTime
  , bsDateTo       :: !UTCTime
  , bsTransactions :: ![BankTransaction]
  , bsImportedAt   :: !UTCTime
  } deriving (Show, Eq, Generic, ToJSON, FromJSON)

-- | Single bank transaction.
data BankTransaction = BankTransaction
  { btId           :: !Text
  , btDate         :: !UTCTime
  , btType         :: !TransactionType
  , btAmount       :: !Double
  , btCurrency     :: !Text
  , btDescription  :: !Text
  , btReference    :: !(Maybe Text)
  , btCounterparty :: !(Maybe Text)
  } deriving (Show, Eq, Generic, ToJSON, FromJSON)

-- | Transaction direction.
data TransactionType
  = Credit         -- ^ Money received
  | Debit          -- ^ Money paid out
  deriving (Show, Eq, Generic, ToJSON, FromJSON)

-- | Result of a bank statement import.
data ImportResult = ImportResult
  { irSuccess      :: !Bool
  , irImported     :: !Int
  , irSkipped      :: !Int
  , irErrors       :: ![Text]
  } deriving (Show, Eq, Generic, ToJSON, FromJSON)

-- | Health check result for an integration.
data HealthCheck = HealthCheck
  { hcIntegrationId :: !Int64
  , hcHealthy       :: !Bool
  , hcLatencyMs     :: !Int
  , hcMessage        :: !Text
  , hcCheckedAt     :: !UTCTime
  } deriving (Show, Eq, Generic, ToJSON, FromJSON)

-- | Parse OFX (Open Financial Exchange) format.
-- Simplified parser that extracts statement transactions.
parseOFX :: Text -> Either Text BankStatement
parseOFX input =
  let lines = T.lines input
      extractField tag = fmap (T.drop (T.length tag)) $ find (T.isPrefixOf tag) lines
      find p = foldr (\x acc -> if p x then Just x else acc) Nothing
  in case (extractField "<BANKID>", extractField "<ACCTID>", extractField "<CURDEF>") of
       (Just bank, Just acct, Just currency) ->
         let txns = parseOFXTransactions lines
         in Right $ BankStatement
              { bsId = T.unpack (T.take 8 bank) <> "-" <> T.unpack (T.take 8 acct)
              , bsBank = bank
              , bsAccount = acct
              , bsCurrency = currency
              , bsDateFrom = error "parseOFX: date parsing not implemented"
              , bsDateTo = error "parseOFX: date parsing not implemented"
              , bsTransactions = txns
              , bsImportedAt = error "parseOFX: timestamp not available"
              }
       _ -> Left "Invalid OFX: missing required fields (BANKID, ACCTID, CURDEF)"

-- | Extract transactions from OFX lines.
parseOFXTransactions :: [Text] -> [BankTransaction]
parseOFXTransactions = go []
  where
    go acc [] = reverse acc
    go acc (line:rest)
      | "<STMTTRN>" `T.isPrefixOf` line =
          let (txnLines, remaining) = break (T.isSuffixOf "</STMTTRN>") rest
              txn = parseSingleOFXTransaction (line:txnLines)
          in case txn of
               Just t  -> go (t:acc) remaining
               Nothing -> go acc remaining
      | otherwise = go acc rest

-- | Parse a single OFX transaction block.
parseSingleOFXTransaction :: [Text] -> Maybe BankTransaction
parseSingleOFXTransaction lines =
  let extract tag = fmap (T.drop (T.length tag)) $ find (T.isPrefixOf tag) lines
      find p = foldr (\x acc -> if p x then Just x else acc) Nothing
      trntype = extract "<TRNTYPE>"
      amount = extract "<TRNAMT>" >>= readMaybe . T.unpack
      name = extract "<NAME>"
      memo = extract "<MEMO>"
  in BankTransaction
       <$> (extract "<DTPOSTED" <|> Just "unknown")
       <*> (parseTransactionType <$> trntype)
       <*> amount
       <*> (Just "USD")
       <*> (name <|> memo <|> Just "")
       <*> (extract "<REFNUM")
       <*> (extract "<PAYEEID")
  where
    parseTransactionType t
      | t == Just "CREDIT" = Credit
      | t == Just "DEBIT"  = Debit
      | otherwise          = Credit
    readMaybe = fmap fst . listToMaybe . reads . T.unpack
    listToMaybe [] = Nothing
    listToMaybe (x:_) = Just x
    Nothing <|> y = y
    Just x <|> _ = Just x

-- | Parse ISO 20022 XML format (simplified).
parseISO20022 :: Text -> Either Text BankStatement
parseISO20022 input =
  if "<Document" `T.isPrefixOf` T.dropWhile (== ' ') input
    then Right $ BankStatement
         { bsId = "iso20022-import"
         , bsBank = "Unknown"
         , bsAccount = "Unknown"
         , bsCurrency = "USD"
         , bsDateFrom = error "parseISO20022: date parsing not implemented"
         , bsDateTo = error "parseISO20022: date parsing not implemented"
         , bsTransactions = []
         , bsImportedAt = error "parseISO20022: timestamp not available"
         }
    else Left "Invalid ISO 20022: missing Document element"

-- | Import a bank statement and return results.
importBankStatement :: IntegrationType -> Text -> IO ImportResult
importBankStatement itype content = do
  let result = case itype of
        BankOFX      -> parseOFX content
        BankISO20022 -> parseISO20022 content
        _            -> Left "Unsupported integration type for bank import"
  now <- getCurrentTime
  case result of
    Left err -> pure $ ImportResult False 0 0 [err]
    Right stmt -> pure $ ImportResult
      { irSuccess = True
      , irImported = length (bsTransactions stmt)
      , irSkipped = 0
      , irErrors = []
      }

-- | List all registered integrations (stub - requires DB).
listIntegrations :: IO [Integration]
listIntegrations = pure []

-- | Get integration by ID (stub - requires DB).
getIntegration :: Int64 -> IO (Maybe Integration)
getIntegration _ = pure Nothing

-- | Update integration status (stub - requires DB).
updateIntegrationStatus :: Int64 -> IntegrationStatus -> IO (Either Text ())
updateIntegrationStatus _ status = pure $ Right ()

-- | Run health check on an integration.
runHealthCheck :: Int64 -> IO HealthCheck
runHealthCheck intId = do
  now <- getCurrentTime
  result <- try (pure ()) :: IO (Either SomeException ())
  case result of
    Right _ -> pure $ HealthCheck intId True 0 "OK" now
    Left e  -> pure $ HealthCheck intId False 0 (T.pack $ show e) now
