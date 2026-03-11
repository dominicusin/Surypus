-- | Domain Module - Переработанная архитектура
-- Использует мощь PostgreSQL и безопасность Haskell
-- Расширено на основе реинжиниринга C++ кода OpenPapyrus
module Domain
  ( module Domain.Core
  , module Domain.Types
  , module Domain.Person
  , module Domain.Goods
  , module Domain.Location
  , module Domain.Bill
  , module Domain.Stock
  ) where

import Domain.Bill
import Domain.Goods
import Domain.Location
import Domain.Person
import Domain.Stock
import Domain.Types
import Domain.Core
