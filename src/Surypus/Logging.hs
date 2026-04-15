{-# LANGUAGE OverloadedStrings #-}

module Surypus.Logging
  ( LogLevel (..),
    initLogger,
    debugLog,
    debugLogIf,
  )
where

import Control.Monad (when)
import Data.Text (Text)
import qualified Data.Text as T
import System.Environment (lookupEnv)

data LogLevel
  = LogLevelDebug
  | LogLevelInfo
  | LogLevelWarn
  | LogLevelError
  | LogLevelOther Text
  deriving (Show, Eq)

initLogger :: IO (Text -> LogLevel -> Text -> IO ())
initLogger = do
  pure $ \moduleName level msg -> do
    let levelStr = case level of
          LogLevelDebug -> "[DEBUG]"
          LogLevelInfo -> "[INFO]"
          LogLevelWarn -> "[WARN]"
          LogLevelError -> "[ERROR]"
          LogLevelOther t -> T.concat ["[", t, "]"]
    let logMsg = T.concat [levelStr, " [", moduleName, "] ", msg]
    putStrLn (T.unpack logMsg)

-- | Debug log controlled by OPENPAPYRUS_DEBUG=1 environment variable.
-- When the variable is set to "1", messages are printed to stdout prefixed with [OPENPAPYRUS-DEBUG].
debugLog :: Text -> IO ()
debugLog msg = do
  m <- lookupEnv "OPENPAPYRUS_DEBUG"
  when (m == Just "1") $ putStrLn ("[OPENPAPYRUS-DEBUG] " <> T.unpack msg)

-- | Conditional debug log: only prints when OPENPAPYRUS_DEBUG=1 and condition is True.
debugLogIf :: Bool -> Text -> IO ()
debugLogIf cond msg = when cond $ debugLog msg
