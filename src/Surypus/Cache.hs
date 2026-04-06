module Surypus.Cache
  ( Cache,
    createCache,
    cacheGet,
    cacheSet,
    cacheDelete,
  )
where

import Data.IORef (IORef, newIORef, readIORef, writeIORef)
import qualified Data.Map as M
import Data.Text (Text)

data Cache = Cache
  { cacheRef :: IORef (M.Map Text Text)
  }

createCache :: IO Cache
createCache = Cache <$> newIORef M.empty

cacheGet :: Cache -> Text -> IO (Maybe Text)
cacheGet cache key = do
  m <- readIORef (cacheRef cache)
  pure $ M.lookup key m

cacheSet :: Cache -> Text -> Text -> Int -> IO Bool
cacheSet cache key value _ttl = do
  m <- readIORef (cacheRef cache)
  writeIORef (cacheRef cache) $ M.insert key value m
  pure True

cacheDelete :: Cache -> Text -> IO Bool
cacheDelete cache key = do
  m <- readIORef (cacheRef cache)
  let mb = M.lookup key m
  writeIORef (cacheRef cache) $ M.delete key m
  pure $ case mb of
    Just _ -> True
    Nothing -> False
