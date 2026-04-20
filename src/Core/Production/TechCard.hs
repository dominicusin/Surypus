{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE DuplicateRecordFields #-}

module Core.Production.TechCard
  ( TechCard (..),
    createTechCard,
    addBOMLine,
  )
where

import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (Day)

-- | Basic BoM line: goods id and required quantity
data BOMLine = BOMLine
  { bomGoodsId :: Int64,
    bomQty :: Double
  }
  deriving (Show, Eq)

data TechCard = TechCard
  { tcId :: Int64,
    tcName :: Text,
    tcBOM :: [BOMLine],
    tcEffective :: Day,
    tcActive :: Bool
  }
  deriving (Show, Eq)

-- | Create a new tech card with BOM lines
createTechCard :: Int64 -> Text -> [BOMLine] -> Day -> Bool -> TechCard
createTechCard cid name bom eff active = TechCard cid name bom eff active

-- | Add a BOM line to an existing tech card
addBOMLine :: TechCard -> BOMLine -> TechCard
addBOMLine tc l = tc {tcBOM = l : tcBOM tc}

-- | Compute BOM usage for a given produced units count
productionUsage :: TechCard -> Int -> [(Int64, Double)]
productionUsage tc units =
  map (\(BOMLine gid q) -> (gid, q * fromIntegral units)) (tcBOM tc)
