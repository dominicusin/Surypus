{-# LANGUAGE OverloadedStrings #-}

module Surypus.Logging
  ( LogLevel (..),
    initLogger,
  )
where

import Data.Text (Text)
import qualified Data.Text as T

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
