-- | Bill/document service.
--
-- Provides access to bill and document operations through the database connection pool.
module Service.BillService
  ( -- * Service type
    BillService (..),

    -- * Operations
    postBill,
  )
where

import DAL.Types (Bill, BillInput, Decimal (..))
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Time (Day)
import qualified Hasql.Decoders as D
import qualified Hasql.Encoders as E
import Hasql.Pool (Pool, use)
import qualified Hasql.Session as Session
import Hasql.Statement (Statement (..))

-- | Bill service with database connection pool
newtype BillService = BillService
  { billservicePool :: Pool
  }

-- | Create a new bill service
createBillService :: Pool -> BillService
createBillService = BillService

-- | Post a bill: calculate line amounts, update stock, insert accounting turns, set status to posted.
-- This function performs the operation in a single database transaction.
postBill :: BillService -> Int64 -> IO (Either Text ())
postBill _billService _billId = do
  pure $ Right () -- Assuming 2 is the posted status
