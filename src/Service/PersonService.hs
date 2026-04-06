
-- | Person/counterparty service.
--
-- Provides access to person (customer/supplier) operations through the database connection pool.
module Service.PersonService
  ( -- * Service type
    PersonService (..),
    createPersonService,
  )
where

import Hasql.Pool (Pool)

-- | Person service with database connection pool
data PersonService = PersonService
  { personservicePool :: Pool
  }

-- | Create a new person service
createPersonService :: Pool -> PersonService
createPersonService = PersonService
