{-# LANGUAGE OverloadedStrings #-}

-- | Error Types for Surypus ERP
--
-- This module defines the core error types used throughout the application.
-- Errors are categorized by domain (validation, database, authentication, etc.)
-- and automatically serialize to JSON for API responses.
--
-- = Usage
--
-- @
-- import Surypus.Error
--
-- case maybeResult of
--   Nothing -> throwError (NotFound "User not found")
--   Just user -> return user
-- @
module Surypus.Error
  ( AppError (..),
    AppResult,
  )
where

import Data.Aeson (ToJSON (..), object, (.=))
import qualified Data.Aeson.Key as Key
import Data.Text (Text)

-- | Application-level errors
--
-- These errors are used throughout the application and are
-- automatically converted to JSON responses in the API.
data AppError
  = -- | Input validation failed
    ValidationError Text
  | -- | Resource not found
    NotFound Text
  | -- | Database operation failed
    DatabaseError Text
  | -- | Authentication/authorization failed
    AuthError Text
  | -- | Rate limit exceeded
    RateLimitError
  | -- | Unexpected internal error
    InternalError Text
  deriving (Show, Eq)

-- | JSON serialization for errors
--
-- Each error type includes:
-- * @error@: Human-readable error message
-- * @type@: Machine-readable error category
instance ToJSON AppError where
  toJSON (ValidationError msg) = object [Key.fromText "error" .= msg, Key.fromText "type" .= ("validation" :: Text)]
  toJSON (NotFound msg) = object [Key.fromText "error" .= msg, Key.fromText "type" .= ("not_found" :: Text)]
  toJSON (DatabaseError msg) = object [Key.fromText "error" .= msg, Key.fromText "type" .= ("database" :: Text)]
  toJSON (AuthError msg) = object [Key.fromText "error" .= msg, Key.fromText "type" .= ("auth" :: Text)]
  toJSON RateLimitError = object [Key.fromText "error" .= ("Rate limit exceeded" :: Text), Key.fromText "type" .= ("rate_limit" :: Text)]
  toJSON (InternalError msg) = object [Key.fromText "error" .= msg, Key.fromText "type" .= ("internal" :: Text)]

-- | Alias for result type with error handling
type AppResult a = Either AppError a
