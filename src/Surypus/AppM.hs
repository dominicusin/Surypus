{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}

module Surypus.AppM where

import Control.Monad.Except
import Control.Monad.Reader
import DAL.Repository.Container (RepositoryContainer)
import Database.Persist.Sql
-- import Service.AccountingService (AccountingService)
-- import Service.AuditService (AuditService)
-- import Service.BillService (BillService)
-- import Service.GoodsService (GoodsService)
-- import Service.InventoryService (InventoryService)
-- import Service.LocationService (LocationService)
-- import Service.OrderService (OrderService)
-- import Service.PaymentService (PaymentService)
-- import Service.PayrollService (PayrollService)
-- import Service.PersonService (PersonService)
-- import Service.PriceService (PriceService)
-- import Service.ReportService (ReportService)
-- import Service.TaxService (TaxService)
-- import Service.UnitService (UnitService)
import Surypus.Cache (Cache)
import Surypus.Config
import Surypus.Error
import Surypus.JobRunner (Job, JobId, submitJob)

newtype AppM a = AppM {unAppM :: ReaderT AppEnv (ExceptT AppError IO) a}
  deriving newtype (Functor, Applicative, Monad, MonadReader AppEnv, MonadError AppError, MonadIO)

runAppM :: AppEnv -> AppM a -> IO (Either AppError a)
runAppM env = runExceptT . flip runReaderT env . unAppM

runDb :: SqlPersistT IO a -> AppM a
runDb action = do
  pool <- asks aePool
  liftIO $ runSqlPool action pool

getRepository :: AppM RepositoryContainer
getRepository = asks aeRepositories

getAccountingService :: AppM AccountingService
getAccountingService = asks (scAccountingService . aeServices)

getAuditService :: AppM AuditService
getAuditService = asks (scAuditService . aeServices)

getBillService :: AppM BillService
getBillService = asks (scBillService . aeServices)

getGoodsService :: AppM GoodsService
getGoodsService = asks (scGoodsService . aeServices)

getInventoryService :: AppM InventoryService
getInventoryService = asks (scInventoryService . aeServices)

getLocationService :: AppM LocationService
getLocationService = asks (scLocationService . aeServices)

getOrderService :: AppM OrderService
getOrderService = asks (scOrderService . aeServices)

getPriceService :: AppM PriceService
getPriceService = asks (scPriceService . aeServices)

getPaymentService :: AppM PaymentService
getPaymentService = asks (scPaymentService . aeServices)

getPayrollService :: AppM PayrollService
getPayrollService = asks (scPayrollService . aeServices)

getPersonService :: AppM PersonService
getPersonService = asks (scPersonService . aeServices)

getReportService :: AppM ReportService
getReportService = asks (scReportService . aeServices)

getTaxService :: AppM TaxService
getTaxService = asks (scTaxService . aeServices)

getUnitService :: AppM UnitService
getUnitService = asks (scUnitService . aeServices)

getCache :: AppM Cache
getCache = asks aeCache

submitJobM :: Job -> AppM JobId
submitJobM job = do
  queue <- asks aeJobQueue
  liftIO $ submitJob queue job
