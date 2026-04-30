{-# LANGUAGE DuplicateRecordFields #-}

module Production.MRP where
  ( BOMLine (..),
    MRPDemand,
    calculateMRP,
  )
where

import Data.Int (Int64)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as M

data BOMLine = BOMLine
  { bomGoodsId :: Int64,
    bomQty :: Double
  }
  deriving (Show, Eq)

type MRPDemand = [(Int64, Double)]

-- | Very lightweight MRP calculation: expand demand by BOM lines and sum contributions
calculateMRP :: [BOMLine] -> MRPDemand -> MRPDemand
calculateMRP bom demand =
  let extra = [(bomGoodsId b, bomQty b) | b <- bom]
      merged = demand ++ extra
      summed = M.fromListWith (+) merged
   in M.toList $ M.filter (> 0) summed
