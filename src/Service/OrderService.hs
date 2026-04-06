
-- | Order management service.
--
-- Provides access to order operations through the database connection pool.
module Service.OrderService
  ( -- * Service type
    OrderService (..),
    createOrderService,
  )
where

import Hasql.Pool (Pool)

-- | Order service with database connection pool
newtype OrderService = OrderService
  { orderservicePool :: Pool
  }

-- | Create a new order service
createOrderService :: Pool -> OrderService
createOrderService = OrderService
