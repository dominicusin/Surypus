{-# LANGUAGE DeriveGeneric #-}

module Domain.Document.Audit
  ( DocumentAuditPayload (..),
    defaultDocumentAuditLookahead,
  )
where

import Data.Aeson (FromJSON, ToJSON)
import GHC.Generics (Generic)

newtype DocumentAuditPayload = DocumentAuditPayload
  { daaLookaheadDays :: Maybe Int
  }
  deriving (Eq, Show, Generic)

instance FromJSON DocumentAuditPayload

instance ToJSON DocumentAuditPayload

defaultDocumentAuditLookahead :: Int
defaultDocumentAuditLookahead = 30
