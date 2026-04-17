-- | Unit of measure service.
--
-- Provides access to unit of measure operations through the database connection pool.
module Service.UnitService
  ( -- * Service type
    UnitService (..),
    createUnitService,
  )
where

import Hasql.Pool (Pool)

-- | Unit service with database connection pool
data UnitService = UnitService
  { unitservicePool :: Pool
  }

-- | Create a new unit service
createUnitService :: Pool -> UnitService
createUnitService = UnitService
