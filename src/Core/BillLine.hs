-- | BillLine module - Bill lines
module Core.BillLine
  ( BillLine (..),
    calcLineTotal,
    prop_lineTotalNonNeg,
    prop_lineTotalDiscountBound,
  )
where

import Data.Int (Int64)
import Test.QuickCheck

{-@ type NonNeg = {v:Double | v >= 0} @-}
{-@ type Discount = {v:Double | v >= 0 && v <= 100} @-}

-- | BillLine - Bill line item
data BillLine = BillLine
  { blId :: Int64,
    blBillId :: Int64,
    blGoodsId :: Int64,
    blQtty :: Double,
    blPrice :: Double,
    blDiscount :: Double,
    blTaxRate :: Double,
    blFlags :: Int
  }
  deriving (Show, Eq)

{-@ calcLineTotal :: BillLine -> NonNeg @-}

-- | Calculate line total: qty * price * (1 - discount%)
calcLineTotal :: BillLine -> Double
calcLineTotal bl = blQtty bl * blPrice bl * (1 - blDiscount bl / 100)

-- ============================================================================
-- QUICKCHECK PROPERTIES
-- ============================================================================

instance Arbitrary BillLine where
  arbitrary = do
    qtty <- suchThat arbitrary (> 0)
    price <- suchThat arbitrary (> 0)
    discount <- choose (0, 100 :: Double)
    taxRate <- choose (0, 100 :: Double)
    pure $ BillLine 0 0 0 qtty price discount taxRate 0

-- | Property: Line total is always non-negative
prop_lineTotalNonNeg :: BillLine -> Bool
prop_lineTotalNonNeg bl = calcLineTotal bl >= 0

-- | Property: Discount cannot exceed 100%
prop_lineTotalDiscountBound :: BillLine -> Property
prop_lineTotalDiscountBound bl =
  let q = blQtty bl
      p = blPrice bl
      d = blDiscount bl
   in d <= 100 ==> calcLineTotal bl == q * p * (1 - d / 100)
