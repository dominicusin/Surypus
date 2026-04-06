
module Surypus.API.Auth
  ( authenticateUser,
    getUserIdFromRequest,
  )
where

import Data.Int (Int64)
import Data.Text (Text)
import Surypus.JWT (JWTPayload (..))

data AuthUser = AuthUser Text
  deriving (Show, Eq)

-- | Authenticate user from JWT token (simplified)
authenticateUser :: JWTPayload -> Bool
authenticateUser _ = True

-- | Extract user ID from JWT token in request context
getUserIdFromRequest :: JWTPayload -> Int64
getUserIdFromRequest payload = fromIntegral $ jwtUserId payload
