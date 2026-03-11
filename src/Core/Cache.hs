-- | Cache module - In-memory cache
module Core.Cache where

import           Data.Int  (Int64)
import           Data.Text (Text)
import           Data.Time (UTCTime)

-- | Cache entry
data CacheEntry a = CacheEntry
  { ceKey     :: Text
  , ceValue   :: a
  , ceExpires :: Maybe UTCTime
  } deriving (Show, Eq)

-- | Cache statistics
data CacheStats = CacheStats
  { csHits   :: Int64
  , csMisses :: Int64
  , csSize   :: Int64
  } deriving (Show, Eq)

-- | Calculate hit rate
calcHitRate :: CacheStats -> Double
calcHitRate cs
  | total == 0 = 0
  | otherwise = fromIntegral (csHits cs) / fromIntegral total
  where total = csHits cs + csMisses cs

-- | Check if entry is expired
isExpired :: CacheEntry a -> UTCTime -> Bool
isExpired ce now = case ceExpires ce of
  Nothing  -> False
  Just exp -> now > exp
