-- | Discount card types
module Core.Loyalty.Card where

import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (Day)

-- | DiscountCard - Discount/loyalty card (дисконтная карта)
data DiscountCard = DiscountCard
  { dcId :: Int64,
    dcSeriesId :: Int64, -- Card series ID
    dcCode :: Text, -- Card code/number
    dcPersonId :: Maybe Int64, -- Owner ID
    dcPercent :: Double, -- Discount percent
    dcExpires :: Maybe Day, -- Expiry date
    dcFlags :: Int,
    dcBalance :: Double -- Current balance (for bonus cards)
  }
  deriving (Show, Eq)

-- | DiscountCardSeries - Series of discount cards (серия карт)
data DiscountCardSeries = DiscountCardSeries
  { dcsId :: Int64,
    dcsCode :: Text,
    dcsName :: Text,
    dcsType :: CardSeriesType,
    dcsPercent :: Double, -- Default discount percent
    dcsMinSum :: Double, -- Minimum sum for discount
    dcsFlags :: Int
  }
  deriving (Show, Eq)

-- | Card series type
data CardSeriesType
  = CST_Discount -- Discount card (дисконтная)
  | CST_Bonus -- Bonus card (бонусная)
  | CST_Credit -- Credit card (кредитная)
  | CST_Gift -- Gift card (подарочная)
  deriving (Show, Eq, Enum)

-- | Card series flags
data CardSeriesFlags = CardSeriesFlags
  { csfActive :: Bool,
    csfAutoCreate :: Bool, -- Auto-create on first use
    csfNominal :: Bool -- Nominal card (номинальная)
  }
  deriving (Show, Eq)
