-- | Goods management service.
--
-- Provides access to goods/product operations through the database connection pool.
module Service.GoodsService
  ( -- * Service type
    GoodsService (..),
    createGoodsService,
  )
where

import Hasql.Pool (Pool)

-- | Goods service with database connection pool
newtype GoodsService = GoodsService
  { goodsservicePool :: Pool
  }

-- | Create a new goods service
createGoodsService :: Pool -> GoodsService
createGoodsService = GoodsService
