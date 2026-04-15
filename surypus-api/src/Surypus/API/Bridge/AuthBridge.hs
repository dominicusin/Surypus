module Surypus.API.Bridge.AuthBridge where

import Data.Text (Text)
import Surypus.API.Root
import Surypus.Types.Auth

toInternalLoginInput :: LoginRequest -> Auth.LoginRequest
toInternalLoginInput (LoginRequest u p) = Auth.LoginRequest u p

fromInternalLoginOutput :: Auth.LoginResponse -> LoginResponse
fromInternalLoginOutput ir =
  LoginResponse
    { accessToken = Auth.respAccessToken ir,
      refreshToken = Auth.respRefreshToken ir,
      expiresIn = 3600,
      userId = Auth.respUserId ir,
      userName = Auth.respUserName ir,
      role = Auth.respRole ir
    }

toInternalRefreshInput :: Root.RefreshRequest -> Auth.RefreshRequest
toInternalRefreshInput (Root.RefreshRequest rt) = Auth.RefreshRequest rt

fromInternalRefreshOutput :: Auth.RefreshResponse -> Root.RefreshResponse
fromInternalRefreshOutput (Auth.RefreshResponse at rt ei) = Root.RefreshResponse at rt (maybe 3600 id ei)
