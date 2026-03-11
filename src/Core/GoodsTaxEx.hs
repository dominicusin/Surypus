-- | GoodsTaxEx module - Extended goods tax
module Core.GoodsTaxEx where

import           Data.Int  (Int64)
import           Data.Text (Text)

-- | GoodsTaxEx - Extended goods tax
data GoodsTaxEx = GoodsTaxEx
  { gteId      :: Int64
  , gteCode    :: Text
  , gteName    :: Text
  , gteTaxRate :: Double
  , gteFlags   :: Int
  } deriving (Show, Eq)

-- | Calculate tax amount
calcTaxAmount :: GoodsTaxEx -> Double -> Double
calcTaxAmount gte price = price * gteTaxRate gte / 100
