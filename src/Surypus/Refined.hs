{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TypeOperators #-}

-- | Refined Types with LiquidHaskell-style invariants
-- Модуль содержит типы с проверенными инвариантами:
-- - NonNegative: неотрицательные значения (для остатков, сумм)
-- - Positive: строго положительные значения
-- - Percentage: проценты (0-100)
-- - Amount: денежные суммы
module Surypus.Refined
  ( -- * Refined Types
    NonNegative (..),
    Positive (..),
    Percentage (..),
    Amount (..),
    Quantity (..),

    -- * Smart Constructors
    mkNonNegative,
    mkPositive,
    mkPercentage,
    mkAmount,
    mkQuantity,

    -- * Predicates
    isNonNegative,
    isPositive,
    isValidPercentage,

    -- * LiquidHaskell-style type synonyms (for documentation)
    module Surypus.Refined.Predicates,
  )
where

import Surypus.Refined.Predicates
import Surypus.Types (Decimal (..))

-- | Non-negative number (>= 0)
-- Инвариант: value >= 0
-- Использование: остатки на складе, суммы платежей
newtype NonNegative a = NonNegative {unNonNegative :: a}
  deriving (Show, Eq, Ord)

-- | Positive number (> 0)
-- Инвариант: value > 0
-- Использование: количество товара, цена
newtype Positive a = Positive {unPositive :: a}
  deriving (Show, Eq, Ord)

-- | Percentage (0-100)
-- Инвариант: 0 <= value <= 100
-- Использование: ставка налога, скидка
newtype Percentage a = Percentage {unPercentage :: a}
  deriving (Show, Eq, Ord)

-- | Money amount
-- Инвариант: value >= 0, ровно 2 знака после запятой
newtype Amount = Amount {unAmount :: Decimal}
  deriving (Show, Eq, Ord)

-- | Quantity
-- Инвариант: value >= 0
newtype Quantity = Quantity {unQuantity :: Decimal}
  deriving (Show, Eq, Ord)

-- | Smart constructor for NonNegative
-- Возвращает Nothing если значение отрицательное
mkNonNegative :: (Ord a, Num a) => a -> Maybe (NonNegative a)
mkNonNegative a
  | a >= 0 = Just (NonNegative a)
  | otherwise = Nothing

-- | Smart constructor for Positive
-- Возвращает Nothing если значение <= 0
mkPositive :: (Ord a, Num a) => a -> Maybe (Positive a)
mkPositive a
  | a > 0 = Just (Positive a)
  | otherwise = Nothing

-- | Smart constructor for Percentage
-- Возвращает Nothing если значение вне диапазона [0, 100]
mkPercentage :: (Ord a, Num a) => a -> Maybe (Percentage a)
mkPercentage a
  | a >= 0 && a <= 100 = Just (Percentage a)
  | otherwise = Nothing

-- | Smart constructor for Amount
mkAmount :: Double -> Maybe Amount
mkAmount a
  | a >= 0 = Just (Amount (Decimal (round (a * 100))))
  | otherwise = Nothing

-- | Smart constructor for Quantity
mkQuantity :: Double -> Maybe Quantity
mkQuantity q
  | q >= 0 = Just (Quantity (Decimal (round (q * 100))))
  | otherwise = Nothing

-- | Check if value is non-negative
isNonNegative :: (Ord a, Num a) => a -> Bool
isNonNegative a = a >= 0

-- | Check if value is positive
isPositive :: (Ord a, Num a) => a -> Bool
isPositive a = a > 0

-- | Check if percentage is valid (0-100)
isValidPercentage :: (Ord a, Num a) => a -> Bool
isValidPercentage p = p >= 0 && p <= 100
