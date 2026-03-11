{-# LANGUAGE GeneralizedNewtypeDeriving #-}

module Domain.Types
  ( PPID(..)
  , Money(..)
  , Pagination(..)
  , defaultPagination
  ) where

import Data.Int (Int64)

newtype PPID = PPID { unPPID :: Int64 }
  deriving (Eq, Ord, Show)

ppidToInt64 :: PPID -> Int64
ppidToInt64 = unPPID

int64ToPPID :: Int64 -> PPID
int64ToPPID = PPID

newtype Money = Money { getMoney :: Double }
  deriving (Eq, Show, Ord, Num, Real)

toMoney :: Double -> Money
toMoney = Money

fromMoney :: Money -> Double
fromMoney = getMoney

data Pagination = Pagination
  { paginationLimit  :: Int
  , paginationOffset :: Int
  } deriving (Eq, Show)

defaultPagination :: Pagination
defaultPagination = Pagination 50 0
