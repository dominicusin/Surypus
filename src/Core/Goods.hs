-- | Goods Module - Product catalog and inventory
module Core.Goods where

import Core.Refined (NonNegDouble)
import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (Day)
import Test.QuickCheck

-- ============================================================================
-- GOODS TYPES (correspond to GoodsTbl::Rec)
-- ============================================================================

{-@ data Goods = Goods
  { gId :: Int64,
    gCode :: Text,
    gName :: Text,
    gFullName :: Text,
    gGroupId :: Int64,
    gParentId :: Int64,
    gUnitId :: Int64,
    gTaxGrpId :: Int64,
    gManufId :: Int64,
    gCountryId :: Int64,
    gBarcode :: Text,
    gPrice :: NonNegDouble,
    gCost :: NonNegDouble,
    gLowestPrice :: NonNegDouble,
    gAvgCost :: NonNegDouble,
    gRestrictPrice :: NonNegDouble,
    gWeight :: NonNegDouble,
    gVolume :: NonNegDouble,
    gMinStock :: NonNegDouble,
    gMaxStock :: NonNegDouble,
    gReorderPoint :: NonNegDouble,
    gFlags :: GoodsFlags,
    gStatus :: GoodsStatus
  } @-}
data Goods = Goods
  { gId :: Int64,
    gCode :: Text,
    gName :: Text,
    gFullName :: Text,
    gGroupId :: Int64,
    gParentId :: Int64,
    gUnitId :: Int64,
    gTaxGrpId :: Int64,
    gManufId :: Int64,
    gCountryId :: Int64,
    gBarcode :: Text,
    gPrice :: Double,
    gCost :: Double,
    gLowestPrice :: Double,
    gAvgCost :: Double,
    gRestrictPrice :: Double,
    gWeight :: Double,
    gVolume :: Double,
    gMinStock :: Double,
    gMaxStock :: Double,
    gReorderPoint :: Double,
    gFlags :: GoodsFlags,
    gStatus :: GoodsStatus
  }
  deriving (Show, Eq)

data GoodsFlags = GoodsFlags
  { gfGoods :: Bool, -- Is goods (not service)
    gfSerial :: Bool, -- Serial number required
    gfWeight :: Bool, -- Weight matters
    gfVolume :: Bool, -- Volume matters
    gfTaxable :: Bool, -- Taxable
    gfImport :: Bool, -- Imported
    gfNoReturn :: Bool -- No return
  }
  deriving (Show, Eq)

data GoodsStatus = GS_Active | GS_Discontinued | GS_Obsolete
  deriving (Show, Eq)

-- | Goods group
data GoodsGroup = GoodsGroup
  { ggId :: Int64,
    ggCode :: Text,
    ggName :: Text,
    ggParentId :: Maybe Int64,
    ggFlags :: Int
  }
  deriving (Show, Eq)

-- | Goods unit of measure
data GoodsUnit = GoodsUnit
  { uId :: Int64,
    uCode :: Text,
    uName :: Text,
    uShortName :: Text,
    uFraction :: Double -- Conversion factor to base unit
  }
  deriving (Show, Eq)

-- | Stock balance
{-@ data GoodsRest = GoodsRest
  { grGoodsId :: Int64,
    grLocationId :: Int64,
    grQtty :: NonNegDouble,
    grCost :: NonNegDouble,
    grPrice :: NonNegDouble
  } @-}
data GoodsRest = GoodsRest
  { grGoodsId :: Int64,
    grLocationId :: Int64,
    grQtty :: Double,
    grCost :: Double,
    grPrice :: Double
  }
  deriving (Show, Eq)

-- | Goods price
data GoodsPrice = GoodsPrice
  { gpId :: Int64,
    gpGoodsId :: Int64,
    gpPriceTypeId :: Int64,
    gpPrice :: Double,
    gpCurrencyId :: Int64,
    gpMinQtty :: Double,
    gpDateFrom :: Day,
    gpDateTo :: Maybe Day
  }
  deriving (Show, Eq)

-- ============================================================================
-- GOODS FUNCTIONS
-- ============================================================================

{-@ validateGoods :: Goods -> {v:Bool | v = (gPrice g >= 0 && gCost g >= 0)} @-}
validateGoods :: Goods -> Bool
validateGoods g = gPrice g >= 0 && gCost g >= 0

validateBarcode :: Text -> Bool
validateBarcode bc = length (show bc) >= 8 && length (show bc) <= 14

-- | FIFO allocation
{-@ fifoAllocation :: [GoodsRest] -> NonNegDouble -> [GoodsRest] @-}
fifoAllocation :: [GoodsRest] -> Double -> [GoodsRest]
fifoAllocation rests needed = go rests needed []
  where
    go [] _ acc = reverse acc
    go _ 0 acc = reverse acc
    go (r : rs) n acc
      | grQtty r <= n = go rs (n - grQtty r) (r : acc)
      | otherwise = reverse acc

-- | Calculate average cost
{-@ calcAvgCost :: [GoodsRest] -> NonNegDouble @-}
calcAvgCost :: [GoodsRest] -> Double
calcAvgCost rests =
  let totalCost = sum (map (\r -> grQtty r * grCost r) rests)
      totalQty = sum (map grQtty rests)
   in if totalQty > 0 then totalCost / totalQty else 0

-- | Check reorder needed
isReorderNeeded :: Goods -> GoodsRest -> Bool
isReorderNeeded goods rest = grQtty rest <= gReorderPoint goods

-- ============================================================================
-- QUICKCHECK PROPERTIES
-- ============================================================================

prop_goods_price_nonnegative :: Goods -> Property
prop_goods_price_nonnegative g =
  property (gPrice g >= 0 && gCost g >= 0)

prop_fifo_total :: [GoodsRest] -> Double -> Property
prop_fifo_total rests needed =
  let allocated = fifoAllocation rests needed
      totalAllocated = sum (map grQtty allocated)
   in property (totalAllocated == min needed (sum (map grQtty rests)))
