-- | Bill/document service.
--
-- Provides access to bill and document operations through the database connection pool.
module Service.BillService
  ( -- * Service type
    BillService (..),
    createBillService,
  )
where

import Hasql.Pool (Pool)

-- | Bill service with database connection pool
newtype BillService = BillService
  { billservicePool :: Pool
  }

-- | Create a new bill service
createBillService :: Pool -> BillService
createBillService = BillService
