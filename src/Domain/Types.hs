{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}

module Domain.Types
  ( PPID (..),
    Money (..),
    toMoney,
    fromMoney,
    Pagination (..),
    defaultPagination,
    offset,
    limit,
    ppidToInt64,
    int64ToPPID,
    hasFlag,
    Flags32 (..),
  )
where

import Data.Bits ((.&.), (.|.))
import Data.Int (Int64)
import Data.Word (Word32)

newtype PPID = PPID {unPPID :: Int64}
  deriving (Eq, Ord, Show)

ppidToInt64 :: PPID -> Int64
ppidToInt64 (PPID i) = i

int64ToPPID :: Int64 -> PPID
int64ToPPID = PPID

newtype Money = Money {getMoney :: Double}
  deriving newtype (Eq, Show, Ord, Num, Real)

toMoney :: Double -> Money
toMoney d = Money (fromIntegral (round d :: Int))

fromMoney :: Money -> Int
fromMoney (Money d) = round d

newtype Flags32 = Flags32 Word32
  deriving (Eq, Show)

instance Semigroup Flags32 where
  Flags32 a <> Flags32 b = Flags32 (a .|. b)

instance Monoid Flags32 where
  mempty = Flags32 0

hasFlag :: Flags32 -> Flags32 -> Bool
hasFlag (Flags32 val) (Flags32 mask) = (val .&. mask) /= 0

data Pagination = Pagination
  { paginationLimit :: Int,
    paginationOffset :: Int
  }
  deriving (Eq, Show)

offset :: Pagination -> Int
offset = paginationOffset

limit :: Pagination -> Int
limit = paginationLimit

defaultPagination :: Pagination
defaultPagination = Pagination 50 0
