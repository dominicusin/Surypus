
-- | Location/warehouse service.
--
-- Provides access to location and warehouse operations through the database connection pool.
module Service.LocationService
  ( -- * Service type
    LocationService (..),
    createLocationService,
  )
where

import Hasql.Pool (Pool)

-- | Location service with database connection pool
newtype LocationService = LocationService
  { locationservicePool :: Pool
  }

-- | Create a new location service
createLocationService :: Pool -> LocationService
createLocationService = LocationService
