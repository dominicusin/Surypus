module DAL.Repository.Container
  ( RepositoryContainer (..),
    mkRepositoryContainer,
  )
where

import DAL.Repository.AccPlan
import DAL.Repository.AccTurn
import DAL.Repository.AuditLog
import DAL.Repository.Bill
import DAL.Repository.Currency
import DAL.Repository.Location
import DAL.Repository.Order
import DAL.Repository.Payment
import DAL.Repository.Price
import DAL.Repository.RBAC
import DAL.Repository.Tax
import DAL.Repository.User
import Hasql.Pool (Pool)

data RepositoryContainer = RepositoryContainer
  { rcLocationRepository :: LocationRepository,
    rcPaymentRepository :: PaymentRepository,
    rcTaxRepository :: TaxRepository,
    rcCurrencyRepository :: CurrencyRepository,
    rcPriceRepository :: PriceRepository,
    rcBillRepository :: BillRepository,
    rcOrderRepository :: OrderRepository,
    rcAccPlanRepository :: AccPlanRepository,
    rcAccTurnRepository :: AccTurnRepository,
    rcUserRepository :: UserRepository,
    rcRBACRepository :: RBACRepository,
    rcAuditLogRepository :: AuditLogRepository
  }

mkRepositoryContainer :: Pool -> RepositoryContainer
mkRepositoryContainer pool =
  RepositoryContainer
    { rcLocationRepository = mkLocationRepository pool,
      rcPaymentRepository = mkPaymentRepository pool,
      rcTaxRepository = mkTaxRepository pool,
      rcCurrencyRepository = mkCurrencyRepository pool,
      rcPriceRepository = mkPriceRepository pool,
      rcBillRepository = mkBillRepository pool,
      rcOrderRepository = mkOrderRepository pool,
      rcAccPlanRepository = mkAccPlanRepository pool,
      rcAccTurnRepository = mkAccTurnRepository pool,
      rcUserRepository = mkUserRepository pool,
      rcRBACRepository = mkRBACRepository pool,
      rcAuditLogRepository = mkAuditLogRepository pool
    }
