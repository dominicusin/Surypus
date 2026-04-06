{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}

-- | Domain Types for Surypus ERP
--
-- This module provides fundamental types used throughout the domain layer,
-- including identifiers, monetary values, flags, and pagination.
--
-- = Types
--
-- * 'PPID' - Persistent ID wrapper for type safety
-- * 'Money' - Monetary value representation
-- * 'Flags32' - Bit flags for status/options
-- * 'Pagination' - Server-side pagination parameters
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

-- | Persistent ID wrapper
--
-- Wraps 'Int64' to provide type safety for persistent identifiers.
-- This prevents accidentally mixing different ID types.
newtype PPID = PPID {unPPID :: Int64}
  deriving (Eq, Ord, Show)

-- | Convert PPID to Int64
ppidToInt64 :: PPID -> Int64
ppidToInt64 (PPID i) = i

-- | Convert Int64 to PPID
int64ToPPID :: Int64 -> PPID
int64ToPPID = PPID

-- | Money value representation
--
-- Uses 'Double' internally with convenience constructors.
-- Consider using 'Decimal' from Surypus.Types for precise calculations.
newtype Money = Money {getMoney :: Double}
  deriving newtype (Eq, Show, Ord, Num, Real)

-- | Create Money from Double
toMoney :: Double -> Money
toMoney d = Money (fromIntegral (round d :: Int))

-- | Extract Double from Money
fromMoney :: Money -> Int
fromMoney (Money d) = round d

-- | 32-bit flags container
--
-- Used for storing multiple boolean options in a single integer.
newtype Flags32 = Flags32 Word32
  deriving (Eq, Show)

instance Semigroup Flags32 where
  Flags32 a <> Flags32 b = Flags32 (a .|. b)

instance Monoid Flags32 where
  mempty = Flags32 0

-- | Check if a flag is set
--
-- Returns 'True' if the mask bits are present in the value.
hasFlag :: Flags32 -> Flags32 -> Bool
hasFlag (Flags32 val) (Flags32 mask) = (val .&. mask) /= 0

-- | Pagination parameters
--
-- Used for server-side pagination of large result sets.
data Pagination = Pagination
  { -- | Number of items per page
    paginationLimit :: Int,
    -- | Starting offset (0-indexed)
    paginationOffset :: Int
  }
  deriving (Eq, Show)

-- | Get offset from pagination
offset :: Pagination -> Int
offset = paginationOffset

-- | Get limit from pagination
limit :: Pagination -> Int
limit = paginationLimit

-- | Default pagination (50 items, start at 0)
defaultPagination :: Pagination
defaultPagination = Pagination 50 0
