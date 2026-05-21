{-# LANGUAGE OverloadedStrings #-}
module Sage.EternalWisdom
  ( TimelessInsight(..)
  , PerfectJudgment
  , AbsoluteDiscernment
  , channelWisdom
  ) where

import Data.Text (Text)

-- | Eternal wisdom type
data TimelessInsight = TimelessInsight
  { tiId :: Text
  , tiIsTimeless :: Bool
  , tiIsPerfect :: Bool
  } deriving (Eq, Show)

-- | Perfect judgment type
type PerfectJudgment = TimelessInsight

-- | Absolute discernment type
type AbsoluteDiscernment = TimelessInsight

-- | Channel eternal wisdom
channelWisdom :: PerfectJudgment
channelWisdom = TimelessInsight "wisdom-001" True True