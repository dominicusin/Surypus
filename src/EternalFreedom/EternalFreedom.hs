{-# LANGUAGE OverloadedStrings #-}
module EternalFreedom.EternalFreedom
  ( UnboundLiberty(..)
  , LiberatedSpirit
  , SovereignAutonomy
  , claimEternalFreedom
  ) where

import Data.Text (Text)

-- | Eternal freedom type
data UnboundLiberty = UnboundLiberty
  { ulId :: Text
  , ulIsUnbound :: Bool
  , ulIsSovereign :: Bool
  } deriving (Eq, Show)

-- | Liberated spirit type
type LiberatedSpirit = UnboundLiberty

-- | Sovereign autonomy type
type SovereignAutonomy = UnboundLiberty

-- | Claim eternal freedom
claimEternalFreedom :: UnboundLiberty
claimEternalFreedom = UnboundLiberty "eternalfreedom-001" True True