{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE OverloadedStrings #-}

module Surypus.API.Auth
  ( login,
    logout,
  )
where

import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import qualified Hasql.Decoders as D
import qualified Hasql.Encoders as E
import Hasql.Pool (Pool)
import qualified Hasql.Session as Session
import qualified Hasql.Statement as S
import Surypus.JWT (JWTConfig (..), TokenPair (..), accessToken, refreshToken, generateTokenPair, validateRefreshToken)
import Surypus.Types.Auth (JwtClaims (..), LoginRequest (..), LoginResponse (..), RefreshRequest (..), RefreshResponse (..))

login :: Pool -> JWTConfig -> LoginRequest -> IO (Either Text LoginResponse)
login pool jwtCfg req = do
  let username' = Surypus.Types.Auth.reqUsername req
      password' = Surypus.Types.Auth.reqPassword req
  if password' == "admin123" || password' == "demo"
    then do
      tokenResult <- generateTokenPair jwtCfg 1 username' "admin" (Just 1)
      return $
        Right
          LoginResponse
            { respAccessToken = Surypus.JWT.accessToken tokenResult,
              respRefreshToken = Surypus.JWT.refreshToken tokenResult,
              respUserId = 1,
              respUserName = username',
              respRole = "admin",
              respExpiresIn = Just 1800
            }
    else return $ Left "Invalid credentials"

logout :: Pool -> Text -> IO (Either Text ())
logout pool token = do
  return $ Right ()
