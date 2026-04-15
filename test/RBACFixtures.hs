{-# LANGUAGE OverloadedStrings #-}

module RBACFixtures where

import Data.ByteString (ByteString)
import qualified Data.ByteString as BS
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import Network.HTTP.Types (Header, hAuthorization)
import Surypus.JWT (JWTConfig (..), TokenPair (..), accessToken, generateTokenPair, jwtConfigFromSecret)

adminHeader :: IO Header
-- Canonical HTTP header suppliers used in tests
withAdminUser :: IO Header
withAdminUser = adminHeader
adminHeader = do
  let cfg = jwtConfigFromSecret "test-secret"
  tp <- generateTokenPair cfg 1 "admin" "admin" (Just 1)
  pure (hAuthorization, TE.encodeUtf8 ("Bearer " <> accessToken tp))

operatorHeader :: IO Header
withOperatorUser :: IO Header
withOperatorUser = operatorHeader
operatorHeader = do
  let cfg = jwtConfigFromSecret "test-secret"
  tp <- generateTokenPair cfg 2 "operator" "operator" (Just 1)
  pure (hAuthorization, TE.encodeUtf8 ("Bearer " <> accessToken tp))

viewerHeader :: IO Header
withViewerUser :: IO Header
withViewerUser = viewerHeader
viewerHeader = do
  let cfg = jwtConfigFromSecret "test-secret"
  tp <- generateTokenPair cfg 3 "viewer" "viewer" (Just 1)
  pure (hAuthorization, TE.encodeUtf8 ("Bearer " <> accessToken tp))

-- Edge-case tokens for HTTP RBAC tests
malformedHeader :: IO Header
malformedHeader = pure (hAuthorization, TE.encodeUtf8 ("Bearer not-a-jwt"))

expiredHeader :: IO Header
expiredHeader = do
  let cfg = JWTConfig {jwtSecret = "test-secret", jwtExpiry = (-3600), jwtRefreshExpiry = 1209600}
  tp <- generateTokenPair cfg 999 "expired" "expired" (Just 1)
  pure (hAuthorization, TE.encodeUtf8 ("Bearer " <> accessToken tp))
