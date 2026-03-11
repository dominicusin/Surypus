-- | Country module - Countries
module Core.Country where

import           Data.Int (Int64)

-- | Country - Country
data Country = Country
  { cId     :: Int64
  , cCode   :: String
  , cName   :: String
  , cAlpha2 :: String
  } deriving (Show, Eq)

-- | Get code
getCountryCode :: Country -> String
getCountryCode c = cCode c
