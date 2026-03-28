{-# LANGUAGE GeneralizedNewtypeDeriving #-}

module Domain.Types
  ( PPID (..),
    Money (..),
    Pagination (..),
    defaultPagination,
  )
where

import Data.Int (Int64)

newtype PPID = PPID {unPPID :: Int64}
  deriving (Eq, Ord, Show)

newtype Money = Money {getMoney :: Double}
  deriving (Eq, Show, Ord, Num, Real)

data Pagination = Pagination
  { paginationLimit :: Int,
    paginationOffset :: Int
  }
  deriving (Eq, Show)

defaultPagination :: Pagination
defaultPagination = Pagination 50 0
