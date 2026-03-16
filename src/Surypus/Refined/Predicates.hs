-- | LiquidHaskell-style type predicates
-- These are type aliases for documentation and static verification
module Surypus.Refined.Predicates where

-- | Non-negative value predicate
-- { v | v >= 0 }
-- Используется для: остатки, суммы, количество
type NonNeg = ()

-- | Positive value predicate
-- { v | v > 0 }
-- Используется для: цены, количество товара
type Pos = ()

-- | Percentage predicate (0-100)
-- { v | 0 <= v <= 100 }
-- Используется для: налоговые ставки, скидки
type Percent = ()

-- | Valid amount (2 decimal places)
-- { v | v >= 0 && v имеет ровно 2 знака после запятой }
-- Используется для: денежные суммы
type ValidAmount = ()

-- | Valid quantity
-- { v | v >= 0 }
-- Используется для: количество товара
type ValidQuantity = ()

-- | Account balance
-- { v | v может быть положительным (дебет) или отрицательным (кредит) }
-- Используется для: сальдо счета
type Balance = ()

-- | Document date
-- Используется для: даты документов
type DocDate = ()

-- | Entity ID
-- { v | v > 0 }
-- Используется для: ID сущностей
type EntityId = ()
