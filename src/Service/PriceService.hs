-- | Price management service.
--
-- Provides access to goods price operations through the database connection pool.
module Service.PriceService
  ( -- * Service type
    PriceService (..),
    createPriceService,
  )
where

import Hasql.Pool (Pool)

-- | Price service with database connection pool
data PriceService = PriceService
  { priceservicePool :: Pool
  }

-- | Create a new price service
createPriceService :: Pool -> PriceService
createPriceService = PriceService
