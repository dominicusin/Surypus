module Surypus.Error where

import Data.Text (Text)

data AppError
  = ValidationError Text
  | NotFound Text
  | DatabaseError Text
  | AuthError Text
  | RateLimitError
  | InternalError Text
  deriving (Show, Eq)

type AppResult a = Either AppError a
