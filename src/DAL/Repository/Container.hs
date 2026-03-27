module DAL.Repository.Container
  ( RepositoryContainer (..),
    mkRepositoryContainer,
  )
where

import DAL.Repository.Bill
import DAL.Repository.Currency
import DAL.Repository.Goods
import DAL.Repository.Location
import DAL.Repository.Order
import DAL.Repository.Payment
import DAL.Repository.Person
import DAL.Repository.Price
import DAL.Repository.Tax
import Hasql.Pool (Pool)

data RepositoryContainer = RepositoryContainer
  { rcPersonRepository :: PersonRepository,
    rcGoodsRepository :: GoodsRepository,
    rcLocationRepository :: LocationRepository,
    rcPaymentRepository :: PaymentRepository,
    rcTaxRepository :: TaxRepository,
    rcCurrencyRepository :: CurrencyRepository,
    rcPriceRepository :: PriceRepository,
    rcBillRepository :: BillRepository,
    rcOrderRepository :: OrderRepository
  }

mkRepositoryContainer :: Pool -> RepositoryContainer
mkRepositoryContainer pool =
  RepositoryContainer
    { rcPersonRepository = mkPersonRepository pool,
      rcGoodsRepository = mkGoodsRepository pool,
      rcLocationRepository = mkLocationRepository pool,
      rcPaymentRepository = mkPaymentRepository pool,
      rcTaxRepository = mkTaxRepository pool,
      rcCurrencyRepository = mkCurrencyRepository pool,
      rcPriceRepository = mkPriceRepository pool,
      rcBillRepository = mkBillRepository pool,
      rcOrderRepository = mkOrderRepository pool
    }
