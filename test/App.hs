-- | Test application entry point
{-# LANGUAGE OverloadedStrings #-}
module App (mkApp) where

import Network.Wai (Application)
import Network.Wai.Handler.Warp (run)
import Control.Concurrent.STM (STM, TVar, newTVarIO, readTVarIO, writeTVar)
import qualified Data.Map as M

-- | Simple pass-through application for testing
-- In production, this would include real middleware, routing, etc.
mkApp :: IO Application
mkApp = return $ \_ req respond -> do
  respond $ response { status = 200, body = "OK" }
  where
    response = mempty :: Network.Wai.Response

-- | Test token store for simulating JWT authentication
newtype TestTokenStore = TestTokenStore (M.Map String String)

-- | Create a test token store with predefined users
newTestTokenStore :: IO TestTokenStore
newTestTokenStore = return $ TestTokenStore M.empty

-- | Generate a test JWT token for a user
generateTestToken :: TestTokenStore -> String -> IO String
generateTestToken (TestTokenStore store) user = do
  let token = "test-token-" ++ user
  return token