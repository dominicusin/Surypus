{-# LANGUAGE OverloadedStrings #-}
module Interstellar.InterstellarSystems
  ( StarSystem(..)
  , Coordinates3D(..)
  , InterstellarComm
  , establishLink
  , transmitData
  ) where

import Data.Text (Text)
import Data.Time (UTCTime)

-- | 3D stellar coordinates
data Coordinates3D = Coordinates3D
  { cx :: Double
  , cy :: Double
  , cz :: Double
  } deriving (Eq, Show)

-- | Star system representation
data StarSystem = StarSystem
  { ssName :: Text
  , ssCoords :: Coordinates3D
  , ssPopulation :: Int
  } deriving (Eq, Show)

-- | Interstellar communication type
type InterstellarComm = StarSystem -> UTCTime -> IO ()

-- | Establish communication link
establishLink :: StarSystem -> IO InterstellarComm
establishLink system = return $ \_ _ -> return ()

-- | Transmit data across interstellar distances
transmitData :: InterstellarComm -> StarSystem -> UTCTime -> IO ()
transmitData comm target time = comm target time