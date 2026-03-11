-- | Package module - Product packaging
module Core.Package where

import           Data.Int  (Int64)
import           Data.Text (Text)

-- | PackageType - Type of product package
data PackageType = PT_Box | PT_Pallet | PT_Bundle | PT_Piece
  deriving (Show, Eq)

-- | Package - Product package
data Package = Package
  { pkgId         :: Int64
  , pkgCode       :: Text
  , pkgType       :: PackageType
  , pkgWeight     :: Double
  , pkgVolume     :: Double
  , pkgDimensions:: Text  -- LxWxH
  , pkgBarcode    :: Text
  } deriving (Show, Eq)

-- | Pallet - Shipping pallet
data Pallet = Pallet
  { palId         :: Int64
  , palCode       :: Text
  , palLocationId:: Int64
  , palStatus     :: PalletStatus
  , palWeight     :: Double
  } deriving (Show, Eq)

data PalletStatus = PS_Empty | PS_Loading | PS_Loaded | PS_Shipped
  deriving (Show, Eq)
