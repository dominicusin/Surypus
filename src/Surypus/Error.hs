{-# LANGUAGE OverloadedStrings #-}

module Surypus.Error
  ( AppError (..),
    AppResult,
  )
where

import Data.Aeson (ToJSON (..), object, (.=))
import qualified Data.Aeson.Key as Key
import Data.Text (Text)

data AppError
  = ValidationError Text
  | NotFound Text
  | DatabaseError Text
  | AuthError Text
  | RateLimitError
  | InternalError Text
  deriving (Show, Eq)

instance ToJSON AppError where
  toJSON (ValidationError msg) = object [Key.fromText "error" .= msg, Key.fromText "type" .= ("validation" :: Text)]
  toJSON (NotFound msg) = object [Key.fromText "error" .= msg, Key.fromText "type" .= ("not_found" :: Text)]
  toJSON (DatabaseError msg) = object [Key.fromText "error" .= msg, Key.fromText "type" .= ("database" :: Text)]
  toJSON (AuthError msg) = object [Key.fromText "error" .= msg, Key.fromText "type" .= ("auth" :: Text)]
  toJSON RateLimitError = object [Key.fromText "error" .= ("Rate limit exceeded" :: Text), Key.fromText "type" .= ("rate_limit" :: Text)]
  toJSON (InternalError msg) = object [Key.fromText "error" .= msg, Key.fromText "type" .= ("internal" :: Text)]

type AppResult a = Either AppError a
