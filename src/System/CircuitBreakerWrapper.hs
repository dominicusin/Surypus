module System.CircuitBreakerWrapper where

import qualified Data.Text as T
import Hasql.Pool (Pool)

data BreakerError = BreakerOpen | BreakerFailure Text deriving (Show, Eq)

-- | Simple no-op wrapper: always runs the action and returns its result.
withBreaker :: Pool -> IO a -> IO (Either BreakerError a)
withBreaker _pool action = Right <$> action
