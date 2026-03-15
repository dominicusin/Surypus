{-# LANGUAGE OverloadedStrings #-}

module Surypus.JWT where

import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (UTCTime, addUTCTime, getCurrentTime)
import GHC.Generics (Generic)
import Surypus.Types (AppError (..), AppResult)

data JWTPayload = JWTPayload
  { jwtUserId :: Int,
    jwtUsername :: Text,
    jwtRole :: Text
  }
  deriving (Show, Eq, Generic)

data JWTConfig = JWTConfig
  { jwtSecret :: Text,
    jwtExpirationHours :: Int
  }
  deriving (Show, Eq)

defaultJWTConfig :: JWTConfig
defaultJWTConfig =
  JWTConfig
    { jwtSecret = "surypus-secret-key",
      jwtExpirationHours = 24
    }

generateSimpleToken :: JWTConfig -> JWTPayload -> IO Text
generateSimpleToken config payload = do
  now <- getCurrentTime
  let expiration = addUTCTime (fromIntegral (jwtExpirationHours config * 3600)) now
      token = jwtSecret config <> ":" <> T.pack (show (jwtUserId payload)) <> ":" <> jwtUsername payload <> ":" <> jwtRole payload <> ":" <> T.pack (show expiration)
  return token

validateSimpleToken :: JWTConfig -> Text -> AppResult JWTPayload
validateSimpleToken config token = do
  case T.splitOn ":" token of
    [secret, uid, username, role, _exp] ->
      if secret == jwtSecret config
        then case reads (T.unpack uid) of
          [(uId, "")] -> Right (JWTPayload uId username role)
          _ -> Left (AuthError "Invalid token")
        else Left (AuthError "Invalid secret")
    _ -> Left (AuthError "Invalid token format")
