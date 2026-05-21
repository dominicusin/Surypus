{-# LANGUAGE OverloadedStrings #-}
module Dimensional.DimensionalComputing
  ( Dimension(..)
  , NVector
  , DimensionProcessor
  , processInDimension
  ) where

import Data.Text (Text)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as M

-- | Dimension types
data Dimension = Dim1D | Dim2D | Dim3D | Dim4D | ND Int deriving (Eq, Show)

-- | N-dimensional vector
type NVector = [Double]

-- | Dimension processor type
type DimensionProcessor = Dimension -> NVector -> IO NVector

-- | Process data in a specific dimension
processInDimension :: DimensionProcessor
processInDimension _ vec = return vec