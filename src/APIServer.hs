{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module APIServer
  ( ServerConfig(..)
  , APIResponse(..)
  , APIError(..)
  , LoginRequest(..)
  , LoginResponse(..)
  , runServer
  , healthStatus
  ) where

import Control.Monad (forM_)
import Control.Monad.IO.Class (liftIO)
import Data.Maybe (fromMaybe)
import Data.Aeson (FromJSON, ToJSON, Value, object, (.=), encode)
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Text.Lazy (toStrict)
import qualified Data.Text.Lazy as TL
import qualified Data.Text.Lazy.Encoding as TLE
import GHC.Generics (Generic)
import Hasql.Pool (Pool)
import Network.Wai.Handler.Warp (defaultSettings, setHost, setPort)
import Network.Wai.Middleware.RequestLogger (logStdoutDev)
import Web.Scotty
import Web.Scotty.Internal.Types (Options(..))
import DB.Connection (PoolConfig)

import Domain.Types (Pagination(..), defaultPagination)
import Domain.Person
import Domain.Goods
import Domain.Bill
import Domain.Accounting
  ( AccAccountInput(..)
  , AccEntryInput(..)
  , AccountFilter(..)
  , EntryFilter(..)
  , prepareAccount
  , prepareEntry
  )
import Domain.Location
import Domain.Stock
import Domain.Inventory
import Domain.Asset
import Domain.HR (SalaryFilter(..), SalaryRecord(..), SalarySummary(..))
import Domain.Payroll (PayrollSnapshotPayload(..), PayrollSnapshotRequest(..), validatePayrollSnapshotRequest)
import Domain.Document (DocumentRegisterFilter(..))
import Domain.Document.Audit (DocumentAuditPayload(..))
import Domain.Production (TechFilter(..), MRPNeed(..))
import Domain.TechCard (TechCardInput(..), TechLineInput(..), validateTechCardInput, validateTechLineInput)
import Domain.Job (JobFilter(..), JobRequest(..), JobStatus(..), jobStatusFromText, validateJobRequest)
import Domain.ReportJob (ReportRenderPayload(..))
import Domain.ReportSchedule (ReportScheduleInput(..), reportScheduleTemplates, validateReportSchedule)
import qualified DB.Person as DBPerson
import qualified DB.PersonSummary as DBPersonSummary
import qualified DB.PersonSnapshot as DBPersonSnapshot
import qualified DB.Person.Address as DBPersonAddress
import qualified DB.Person.Contact as DBPersonContact
import qualified DB.Person.BankAccount as DBPersonBankAccount
import qualified DB.Goods as DBGoods
import qualified DB.Bill as DBBill
import qualified DB.Location as DBLocation
import qualified DB.Accounting as DBAccounting
import qualified DB.Stock as DBStock
import qualified DB.Inventory as DBInventory
import qualified DB.Asset as DBAsset
import qualified DB.BillLine as DBBillLine
import qualified DB.Payroll as DBPayroll
import qualified DB.HRPayrollSnapshot as DBHRPayrollSnapshot
import qualified DB.HRCharge as DBHRCharge
import qualified DB.Document.Register as DBDocumentRegister
import qualified DB.Document.RegisterType as DBDocumentRegisterType
import qualified DB.Document.Counter as DBDocumentCounter
import qualified DB.User as DBUser
import qualified DB.Production as DBProduction
import qualified DB.TechCard as DBTechCard
import qualified DB.JobQueue as DBJobQueue
import qualified DB.ReportSchedule as DBReportSchedule
import qualified Core.Auth.JWT as JWT
import Data.UUID (toText)
import qualified Data.UUID.V4 as UUIDv4
import Data.Time (Day)
import Core.Document.Types
  ( DocumentRegister(..)
  , DocumentRegisterType(..)
  , DocumentOpCounter(..)
  , validateDocumentRegister
  , validateDocumentRegisterType
  , validateDocumentOpCounter
  )
import qualified Data.Map as Map
import qualified Surypus.Reports as Reports

-- | Server configuration
data ServerConfig = ServerConfig
  { scHost       :: String
  , scPort       :: Int
  , scPoolConfig :: PoolConfig
  , scAuthConfig :: JWT.JWTConfig
  } deriving (Eq, Show)

-- | Standard API response wrapper
data APIResponse a
  = APIOk a
  | APIError APIError
  deriving (Eq, Show, Generic)

instance ToJSON a => ToJSON (APIResponse a) where
  toJSON (APIOk a) = object ["status" .= ("ok" :: Text), "data" .= a]
  toJSON (APIError err) = object ["status" .= ("error" :: Text), "error" .= err]

data APIError
  = ErrNotFound Text
  | ErrBadRequest Text
  | ErrInternal Text
  deriving (Eq, Show, Generic)

instance ToJSON APIError where
  toJSON (ErrNotFound msg) = object ["code" .= (404 :: Int), "message" .= msg]
  toJSON (ErrBadRequest msg) = object ["code" .= (400 :: Int), "message" .= msg]
  toJSON (ErrInternal msg) = object ["code" .= (500 :: Int), "message" .= msg]

data LoginRequest = LoginRequest
  { loginUser :: Text
  , loginPassword :: Text
  } deriving (Eq, Show, Generic)

instance FromJSON LoginRequest

data LoginResponse = LoginResponse
  { lrToken  :: Text
  , lrUserId :: Int64
  , lrRole   :: Text
  } deriving (Eq, Show, Generic)

instance ToJSON LoginResponse

data WorkOrderInput = WorkOrderInput
  { woiCode :: Text
  , woiDate :: Day
  , woiDueDate :: Day
  , woiProductId :: Int64
  , woiQuantity :: Double
  } deriving (Eq, Show, Generic)

instance FromJSON WorkOrderInput

data EdiStatusUpdate = EdiStatusUpdate
  { esuStatus :: Int
  , esuConfStatus :: Int
  } deriving (Eq, Show, Generic)

instance FromJSON EdiStatusUpdate
instance ToJSON EdiStatusUpdate

data JobStatusUpdate = JobStatusUpdate
  { jsuStatus :: Text
  , jsuMessage :: Maybe Text
  } deriving (Eq, Show, Generic)

instance FromJSON JobStatusUpdate

data JobDependencyRequest = JobDependencyRequest
  { dependsOnId :: Int64
  , dependencyType :: Maybe Text
  } deriving (Eq, Show, Generic)

instance FromJSON JobDependencyRequest

data HealthStatus = HealthStatus
  { hsStatus   :: Text
  , hsVersion  :: Text
  , hsUptime   :: Int
  } deriving (Eq, Show, Generic)

instance ToJSON HealthStatus

healthStatus :: HealthStatus
healthStatus = HealthStatus "healthy" "0.1.0" 0

runServer :: ServerConfig -> Pool -> IO ()
runServer cfg pool = scottyOpts opts (app cfg pool)
  where
    opts = Options 1 (setHost (scHost cfg) . setPort (scPort cfg) $ defaultSettings)

app :: ServerConfig -> Pool -> ScottyM ()
app cfg pool = do
  middleware logStdoutDev
  defaultHandler $ \err -> json (APIError $ ErrInternal (T.pack $ show err))
  get "/api/v1/health" $ json (APIOk healthStatus)
  post "/api/v1/auth/login" $ do
    LoginRequest{..} <- jsonData
    mUser <- liftIO $ DBUser.verifyUserCredentials pool loginUser loginPassword
    case mUser of
      Just user -> do
        let role = DBUser.appUserRole user
        token <- liftIO $ JWT.createToken (scAuthConfig cfg) (DBUser.appUserId user) role
        json (APIOk LoginResponse { lrToken = token, lrUserId = DBUser.appUserId user, lrRole = role })
      Nothing ->
        json (APIError $ ErrBadRequest \"invalid credentials\")
  personsRoutes pool (scAuthConfig cfg)
  goodsRoutes pool (scAuthConfig cfg)
  accountingRoutes pool (scAuthConfig cfg)
  locationRoutes pool (scAuthConfig cfg)
  billRoutes pool (scAuthConfig cfg)
  hrRoutes pool (scAuthConfig cfg)
  productionRoutes pool (scAuthConfig cfg)
  stockRoutes pool (scAuthConfig cfg)
  inventoryRoutes pool (scAuthConfig cfg)
  assetRoutes pool (scAuthConfig cfg)
  reportRoutes pool (scAuthConfig cfg)
  documentRoutes pool (scAuthConfig cfg)
  jobRoutes pool (scAuthConfig cfg)

personsRoutes :: Pool -> JWT.JWTConfig -> ScottyM ()
personsRoutes pool authCfg = do
  get "/api/v1/persons" $ withAuth authCfg $ \_ -> do
    limit <- paramWithDefault "limit" 50
    offset <- paramWithDefault "offset" 0
    name <- optionalParam "name"
    inn <- optionalParam "inn"
    kind <- optionalParam "kind"
    status <- optionalParam "status"
    persons <- liftIO $ DBPerson.listPersons pool (Pagination limit offset) PersonFilter
      { pfName = name
      , pfINN = inn
      , pfKind = kind
      , pfStatus = status
      }
    json (APIOk persons)
  get "/api/v1/persons/:id" $ withAuth authCfg $ \_ -> do
    pid <- param "id"
    mp <- liftIO $ DBPerson.getPerson pool pid
    case mp of
      Nothing -> json (APIError $ ErrNotFound "Person not found")
      Just p -> json (APIOk p)
  post "/api/v1/persons" $ withAuth authCfg $ \_ -> do
    person <- jsonData
    newId <- liftIO $ DBPerson.createPerson pool person
    json (APIOk person { personId = Just newId })
  put "/api/v1/persons/:id" $ withAuth authCfg $ \_ -> do
    pid <- param "id"
    person <- jsonData
    _ <- liftIO $ DBPerson.updatePerson pool pid person
    json (APIOk person { personId = Just pid })
  delete "/api/v1/persons/:id" $ withAuth authCfg $ \_ -> do
    pid <- param "id"
    _ <- liftIO $ DBPerson.deletePerson pool pid
    json (APIOk (object ["deleted" .= pid]))
  personAddressRoutes pool authCfg
  personContactRoutes pool authCfg
  personBankAccountRoutes pool authCfg

personAddressRoutes :: Pool -> JWT.JWTConfig -> ScottyM ()
personAddressRoutes pool authCfg = do
  get "/api/v1/persons/:personId/addresses" $ withAuth authCfg $ \_ -> do
    personId <- param "personId"
    addresses <- liftIO $ DBPersonAddress.listPersonAddresses pool personId
    json (APIOk addresses)

  post "/api/v1/persons/:personId/addresses" $ withAuth authCfg $ \_ -> do
    personId <- param "personId"
    input <- jsonData
    let candidate = mkPersonAddress personId Nothing input
    case validatePersonAddress candidate of
      Left err -> json (APIError $ ErrBadRequest err)
      Right valid -> do
        newId <- liftIO $ DBPersonAddress.createPersonAddress pool personId valid
        json (APIOk valid { paId = Just newId })

  put "/api/v1/persons/:personId/addresses/:id" $ withAuth authCfg $ \_ -> do
    personId <- param "personId"
    addrId <- param "id"
    input <- jsonData
    let candidate = mkPersonAddress personId (Just addrId) input
    case validatePersonAddress candidate of
      Left err -> json (APIError $ ErrBadRequest err)
      Right valid -> do
        updated <- liftIO $ DBPersonAddress.updatePersonAddress pool personId valid
        if updated
          then json (APIOk valid)
          else json (APIError $ ErrNotFound "Address not found")

  delete "/api/v1/persons/:personId/addresses/:id" $ withAuth authCfg $ \_ -> do
    addrId <- param "id"
    deleted <- liftIO $ DBPersonAddress.deletePersonAddress pool addrId
    if deleted
      then json (APIOk (object ["deleted" .= addrId]))
      else json (APIError $ ErrNotFound "Address not found")

personContactRoutes :: Pool -> JWT.JWTConfig -> ScottyM ()
personContactRoutes pool authCfg = do
  get "/api/v1/persons/:personId/contacts" $ withAuth authCfg $ \_ -> do
    personId <- param "personId"
    contacts <- liftIO $ DBPersonContact.listPersonContacts pool personId
    json (APIOk contacts)

  post "/api/v1/persons/:personId/contacts" $ withAuth authCfg $ \_ -> do
    personId <- param "personId"
    input <- jsonData
    let candidate = mkPersonContact personId Nothing input
    case validatePersonContact candidate of
      Left err -> json (APIError $ ErrBadRequest err)
      Right valid -> do
        newId <- liftIO $ DBPersonContact.createPersonContact pool personId valid
        json (APIOk valid { pcId = Just newId })

  put "/api/v1/persons/:personId/contacts/:id" $ withAuth authCfg $ \_ -> do
    personId <- param "personId"
    contactId <- param "id"
    input <- jsonData
    let candidate = mkPersonContact personId (Just contactId) input
    case validatePersonContact candidate of
      Left err -> json (APIError $ ErrBadRequest err)
      Right valid -> do
        updated <- liftIO $ DBPersonContact.updatePersonContact pool personId valid
        if updated
          then json (APIOk valid)
          else json (APIError $ ErrNotFound "Contact not found")

  delete "/api/v1/persons/:personId/contacts/:id" $ withAuth authCfg $ \_ -> do
    contactId <- param "id"
    deleted <- liftIO $ DBPersonContact.deletePersonContact pool contactId
    if deleted
      then json (APIOk (object ["deleted" .= contactId]))
      else json (APIError $ ErrNotFound "Contact not found")

personBankAccountRoutes :: Pool -> JWT.JWTConfig -> ScottyM ()
personBankAccountRoutes pool authCfg = do
  get "/api/v1/persons/:personId/bank-accounts" $ withAuth authCfg $ \_ -> do
    personId <- param "personId"
    accounts <- liftIO $ DBPersonBankAccount.listPersonBankAccounts pool personId
    json (APIOk accounts)

  post "/api/v1/persons/:personId/bank-accounts" $ withAuth authCfg $ \_ -> do
    personId <- param "personId"
    input <- jsonData
    let candidate = mkPersonBankAccount personId Nothing input
    case validatePersonBankAccount candidate of
      Left err -> json (APIError $ ErrBadRequest err)
      Right valid -> do
        newId <- liftIO $ DBPersonBankAccount.createPersonBankAccount pool personId valid
        json (APIOk valid { pbaId = Just newId })

  put "/api/v1/persons/:personId/bank-accounts/:id" $ withAuth authCfg $ \_ -> do
    personId <- param "personId"
    accountId <- param "id"
    input <- jsonData
    let candidate = mkPersonBankAccount personId (Just accountId) input
    case validatePersonBankAccount candidate of
      Left err -> json (APIError $ ErrBadRequest err)
      Right valid -> do
        updated <- liftIO $ DBPersonBankAccount.updatePersonBankAccount pool personId valid
        if updated
          then json (APIOk valid)
          else json (APIError $ ErrNotFound "Bank account not found")

  delete "/api/v1/persons/:personId/bank-accounts/:id" $ withAuth authCfg $ \_ -> do
    accountId <- param "id"
    deleted <- liftIO $ DBPersonBankAccount.deletePersonBankAccount pool accountId
    if deleted
      then json (APIOk (object ["deleted" .= accountId]))
      else json (APIError $ ErrNotFound "Bank account not found")

  get "/api/v1/persons/summary" $ withAuth authCfg $ \_ -> do
    summary <- liftIO $ DBPersonSummary.listPersonSummary pool
    json (APIOk summary)

  get "/api/v1/persons/summary/snapshots" $ withAuth authCfg $ \_ -> do
    snaps <- liftIO $ DBPersonSnapshot.listPersonSummarySnapshots pool
    json (APIOk snaps)

  post "/api/v1/persons/summary/snapshots" $ withAuth authCfg $ \_ -> do
    mrun <- liftIO $ DBPersonSnapshot.runPersonSummarySnapshot pool
    case mrun of
      Nothing -> json (APIError $ ErrInternal "snapshot job failed")
      Just (runId, runAt) -> json (APIOk (object ["run_id" .= runId, "run_at" .= runAt]))

goodsRoutes :: Pool -> JWT.JWTConfig -> ScottyM ()
goodsRoutes pool authCfg = do
  get "/api/v1/goods" $ withAuth authCfg $ \_ -> do
    limit <- paramWithDefault "limit" 50
    offset <- paramWithDefault "offset" 0
    name <- optionalParam "name"
    barcode <- optionalParam "barcode"
    gtype <- optionalParam "type"
    brand <- optionalParam "brand"
    goods <- liftIO $ DBGoods.listGoods pool (Pagination limit offset) GoodsFilter
      { gfName = name
      , gfBarcode = barcode
      , gfType = gtype
      , gfBrand = brand
      }
    json (APIOk goods)
  get "/api/v1/goods/:id" $ withAuth authCfg $ \_ -> do
    gid <- param "id"
    mg <- liftIO $ DBGoods.getGoods pool gid
    case mg of
      Nothing -> json (APIError $ ErrNotFound "Goods not found")
      Just g -> json (APIOk g)
  post "/api/v1/goods" $ withAuth authCfg $ \_ -> do
    goods <- jsonData
    nid <- liftIO $ DBGoods.createGoods pool goods
    json (APIOk goods { goodsId = Just nid })
  put "/api/v1/goods/:id" $ withAuth authCfg $ \_ -> do
    gid <- param "id"
    goods <- jsonData
    _ <- liftIO $ DBGoods.updateGoods pool gid goods
    json (APIOk goods { goodsId = Just gid })
  delete "/api/v1/goods/:id" $ withAuth authCfg $ \_ -> do
    gid <- param "id"
    _ <- liftIO $ DBGoods.deleteGoods pool gid
    json (APIOk (object ["deleted" .= gid]))

accountingRoutes :: Pool -> JWT.JWTConfig -> ScottyM ()
accountingRoutes pool authCfg = do
  get "/api/v1/accounting/accounts" $ withAuth authCfg $ \_ -> do
    limit <- paramWithDefault "limit" 50
    offset <- paramWithDefault "offset" 0
    sheetId <- optionalParam "sheetId"
    code <- optionalParam "code"
    atype <- optionalParam "type"
    accounts <- liftIO $ DBAccounting.listAccounts pool (Pagination limit offset) AccountFilter
      { afSheetId = sheetId
      , afCode = code
      , afType = atype
      , afLimit = limit
      , afOffset = offset
      }
    json (APIOk accounts)
  get "/api/v1/accounting/accounts/:id" $ withAuth authCfg $ \_ -> do
    aid <- param "id"
    mAccount <- liftIO $ DBAccounting.getAccount pool aid
    maybe (json (APIError $ ErrNotFound "Account not found")) (json . APIOk) mAccount
  post "/api/v1/accounting/accounts" $ withAuth authCfg $ \_ -> do
    payload <- jsonData
    case prepareAccount payload of
      Left err -> json (APIError $ ErrBadRequest err)
      Right account -> do
        nid <- liftIO $ DBAccounting.createAccount pool account
        json (APIOk account { accAccountId = Just nid })
  get "/api/v1/accounting/entries" $ withAuth authCfg $ \_ -> do
    limit <- paramWithDefault "limit" 50
    offset <- paramWithDefault "offset" 0
    accountId <- optionalParam "accountId"
    since <- optionalParam "since"
    until <- optionalParam "until"
    entries <- liftIO $ DBAccounting.listEntries pool (Pagination limit offset) EntryFilter
      { efAccountId = accountId
      , efSince = since
      , efUntil = until
      , efLimit = limit
      , efOffset = offset
      }
    json (APIOk entries)
  post "/api/v1/accounting/entries" $ withAuth authCfg $ \_ -> do
    payload <- jsonData
    case prepareEntry payload of
      Left err -> json (APIError $ ErrBadRequest err)
      Right entry -> do
        nid <- liftIO $ DBAccounting.createEntry pool entry
        json (APIOk entry { accEntryId = Just nid })
  get "/api/v1/accounting/trial-balance" $ withAuth authCfg $ \_ -> do
    sheetId <- param "sheetId"
    asOf <- param "asOf"
    rows <- liftIO $ DBAccounting.trialBalance pool sheetId asOf
    json (APIOk rows)

locationRoutes :: Pool -> JWT.JWTConfig -> ScottyM ()
locationRoutes pool authCfg = do
  get "/api/v1/locations" $ withAuth authCfg $ \_ -> do
    limit <- paramWithDefault "limit" 50
    offset <- paramWithDefault "offset" 0
    name <- optionalParam "name"
    ltype <- optionalParam "type"
    locs <- liftIO $ DBLocation.listLocations pool (Pagination limit offset) LocationFilter
      { lfName = name
      , lfType = ltype
      , lfLimit = limit
      , lfOffset = offset
      }
    json (APIOk locs)
  get "/api/v1/locations/:id" $ withAuth authCfg $ \_ -> do
    lid <- param "id"
    mloc <- liftIO $ DBLocation.getLocation pool lid
    maybe (json (APIError $ ErrNotFound "Location not found")) (json . APIOk) mloc
  post "/api/v1/locations" $ withAuth authCfg $ \_ -> do
    location <- jsonData
    nid <- liftIO $ DBLocation.createLocation pool location
    json (APIOk location { locationId = Just nid })
  put "/api/v1/locations/:id" $ withAuth authCfg $ \_ -> do
    lid <- param "id"
    location <- jsonData
    _ <- liftIO $ DBLocation.updateLocation pool lid location
    json (APIOk location { locationId = Just lid })
  delete "/api/v1/locations/:id" $ withAuth authCfg $ \_ -> do
    lid <- param "id"
    _ <- liftIO $ DBLocation.deleteLocation pool lid
    json (APIOk (object ["deleted" .= lid]))

billRoutes :: Pool -> JWT.JWTConfig -> ScottyM ()
billRoutes pool authCfg = do
  get "/api/v1/bills" $ withAuth authCfg $ \_ -> do
    limit <- paramWithDefault "limit" 50
    offset <- paramWithDefault "offset" 0
    person <- optionalParam "person"
    location <- optionalParam "location"
    status <- optionalParam "status"
    bills <- liftIO $ DBBill.listBills pool (Pagination limit offset) BillFilter
      { bfPersonId = person
      , bfLocationId = location
      , bfStatus = status
      , bfLimit = limit
      , bfOffset = offset
      }
    json (APIOk bills)
  get "/api/v1/bills/:id" $ withAuth authCfg $ \_ -> do
    bid <- param "id"
    mb <- liftIO $ DBBill.getBill pool bid
    maybe (json (APIError $ ErrNotFound "Bill not found")) (json . APIOk) mb
  post "/api/v1/bills" $ withAuth authCfg $ \_ -> do
    bill <- jsonData
    nid <- liftIO $ DBBill.createBill pool bill
    json (APIOk bill { billId = Just nid })
  post "/api/v1/bills/:id/post" $ withAuth authCfg $ \_ -> do
    bid <- param "id"
    _ <- liftIO $ DBBill.postBill pool bid
    json (APIOk (object ["posted" .= bid]))
  post "/api/v1/bills/:id/lines" $ withAuth authCfg $ \_ -> do
    bid <- param "id"
    line <- jsonData
    lid <- liftIO $ DBBillLine.createBillLine pool bid line
    _ <- liftIO $ DBBill.recalcBillTotals pool bid
    json (APIOk line { billLineId = Just lid })
  patch "/api/v1/bills/:id/edi" $ withAuth authCfg $ \_ -> do
    bid <- param "id"
    update <- jsonData
    _ <- liftIO $ DBBill.setEdiStatus pool bid (esuStatus update) (esuConfStatus update)
    json (APIOk (object ["ediStatus" .= esuStatus update, "ediConfStatus" .= esuConfStatus update]))

hrRoutes :: Pool -> JWT.JWTConfig -> ScottyM ()
hrRoutes pool authCfg = do
  get "/api/v1/hr/salaries" $ withAuth authCfg $ \_ -> do
    empId <- optionalParam "employee"
    chargeId <- optionalParam "charge"
    periodStart <- optionalParam "from"
    periodEnd <- optionalParam "to"
    records <- liftIO $ DBPayroll.listSalaryRecords pool SalaryFilter
      { sfEmployeeId = empId
      , sfChargeId = chargeId
      , sfPeriodStart = periodStart
      , sfPeriodEnd = periodEnd
      }
    json (APIOk records)

  post "/api/v1/hr/salaries" $ withAuth authCfg $ \_ -> do
    record <- jsonData
    case validateSalaryRecord record of
      Left err -> json (APIError $ ErrBadRequest err)
      Right valid -> do
        sid <- liftIO $ DBPayroll.createSalaryRecord pool valid
        json (APIOk valid { srId = Just sid })

  get "/api/v1/hr/payrolls/summary" $ withAuth authCfg $ \_ -> do
    start <- param "from"
    end <- param "to"
    summary <- liftIO $ DBPayroll.getPayrollSummary pool start end
    json (APIOk summary)

  get "/api/v1/hr/payrolls/snapshots" $ withAuth authCfg $ \_ -> do
    snapshots <- liftIO $ DBHRPayrollSnapshot.listPayrollSnapshots pool
    json (APIOk snapshots)

  post "/api/v1/hr/payrolls/snapshots" $ withAuth authCfg $ \_ -> do
    payload <- jsonData
    case validatePayrollSnapshotRequest payload of
      Left err -> json (APIError $ ErrBadRequest err)
      Right valid -> do
        let jobPayload = toStrict $ TLE.decodeUtf8 $ encode (PayrollSnapshotPayload (psrPeriodStart valid) (psrPeriodEnd valid))
            jobName = T.concat ["Payroll snapshot ", T.pack (show (psrPeriodStart valid)), " - ", T.pack (show (psrPeriodEnd valid))]
            jobReq = JobRequest
              { jrCode = T.concat ["payroll-summary-", T.pack (show (psrPeriodStart valid)), "-", T.pack (show (psrPeriodEnd valid))]
              , jrName = jobName
              , jrType = "payroll_summary_snapshot"
              , jrPriority = 5
              , jrPayload = Just jobPayload
              , jrScheduled = Nothing
              }
        jid <- liftIO $ DBJobQueue.enqueueJob pool jobReq
        json (APIOk (object ["jobId" .= jid]))

  get "/api/v1/hr/charges" $ withAuth authCfg $ \_ -> do
    charges <- liftIO $ DBHRCharge.listSalaryCharges pool
    json (APIOk charges)

  post "/api/v1/hr/charges" $ withAuth authCfg $ \_ -> do
    input <- jsonData
    case validateSalaryChargeInput input of
      Left err -> json (APIError $ ErrBadRequest err)
      Right valid -> do
        newId <- liftIO $ DBHRCharge.createSalaryCharge pool valid
        let base = mkSalaryCharge valid
        json (APIOk base { scId = Just newId })

  put "/api/v1/hr/charges/:id" $ withAuth authCfg $ \_ -> do
    chargeId <- param "id"
    input <- jsonData
    case validateSalaryChargeInput input of
      Left err -> json (APIError $ ErrBadRequest err)
      Right valid -> do
        mcharge <- liftIO $ DBHRCharge.updateSalaryCharge pool chargeId valid
        case mcharge of
          Nothing -> json (APIError $ ErrNotFound "Salary charge not found")
          Just charge -> json (APIOk charge)

stockRoutes :: Pool -> JWT.JWTConfig -> ScottyM ()
stockRoutes pool authCfg = do
  get "/api/v1/stock" $ withAuth authCfg $ \_ -> do
    limit <- paramWithDefault "limit" 50
    offset <- paramWithDefault "offset" 0
    goods <- optionalParam "goods"
    location <- optionalParam "location"
    stocks <- liftIO $ DBStock.listStock pool (Pagination limit offset) StockFilter
      { sfGoodsId = goods
      , sfLocationId = location
      }
    json (APIOk stocks)
  get "/api/v1/stock/:goods/:location" $ withAuth authCfg $ \_ -> do
    goodsId <- param "goods"
    locationId <- param "location"
    mstock <- liftIO $ DBStock.getStock pool goodsId locationId
    maybe (json (APIError $ ErrNotFound "Stock not found")) (json . APIOk) mstock
  post "/api/v1/stock/:goods/:location/reserve" $ withAuth authCfg $ \_ -> do
    goodsId <- param "goods"
    locationId <- param "location"
    qty <- param "qty"
    mstock <- liftIO $ DBStock.reserveStock pool goodsId locationId qty
    maybe (json (APIError $ ErrBadRequest "Unable to reserve stock")) (json . APIOk) mstock

inventoryRoutes :: Pool -> JWT.JWTConfig -> ScottyM ()
inventoryRoutes pool authCfg = do
  get "/api/v1/inventory" $ withAuth authCfg $ \_ -> do
    limit <- paramWithDefault "limit" 50
    offset <- paramWithDefault "offset" 0
    docs <- liftIO $ DBInventory.listInventoryDocs pool (Pagination limit offset)
    json (APIOk docs)

  get "/api/v1/inventory/:id" $ withAuth authCfg $ \_ -> do
    docId <- param "id"
    mdoc <- liftIO $ DBInventory.getInventoryDoc pool docId
    case mdoc of
      Nothing -> json (APIError $ ErrNotFound "Inventory document not found")
      Just doc -> do
        lines <- liftIO $ DBInventory.listInventoryLines pool docId
        summary <- liftIO $ DBInventory.getInventorySummary pool docId
        json (APIOk (InventoryDocumentDetail doc lines summary))

  post "/api/v1/inventory" $ withAuth authCfg $ \_ -> do
    payload <- jsonData
    case validateInventoryDocumentInput payload of
      Left err -> json (APIError $ ErrBadRequest err)
      Right valid -> do
        created <- liftIO $ DBInventory.createInventoryDoc pool valid
        json (APIOk created)

  post "/api/v1/inventory/:id/lines" $ withAuth authCfg $ \_ -> do
    docId <- param "id"
    lineReq <- jsonData
    let line = lineReq { iliInventoryId = docId }
    case validateInventoryLineInput line of
      Left err -> json (APIError $ ErrBadRequest err)
      Right valid -> do
        added <- liftIO $ DBInventory.addInventoryLine pool valid
        json (APIOk added)

  get "/api/v1/inventory/:id/summary" $ withAuth authCfg $ \_ -> do
    docId <- param "id"
    summary <- liftIO $ DBInventory.getInventorySummary pool docId
    case summary of
      Nothing -> json (APIError $ ErrNotFound "Inventory summary not available")
      Just s -> json (APIOk s)

  post "/api/v1/inventory/:id/complete" $ withAuth authCfg $ \_ -> do
    docId <- param "id"
    updated <- liftIO $ DBInventory.updateInventoryStatus pool docId IS_Completed
    if updated
      then json (APIOk (object ["id" .= docId, "status" .= (T.pack $ show IS_Completed)]))
      else json (APIError $ ErrNotFound "Inventory document not found")

assetRoutes :: Pool -> JWT.JWTConfig -> ScottyM ()
assetRoutes pool authCfg = do
  get "/api/v1/assets" $ withAuth authCfg $ \_ -> do
    assets <- liftIO $ DBAsset.listAssets pool
    json (APIOk assets)

  get "/api/v1/assets/:id" $ withAuth authCfg $ \_ -> do
    aid <- param "id"
    masset <- liftIO $ DBAsset.getAsset pool aid
    maybe (json (APIError $ ErrNotFound "Asset not found")) (json . APIOk) masset

  post "/api/v1/assets" $ withAuth authCfg $ \_ -> do
    payload <- jsonData
    case validateAssetInput payload of
      Left err -> json (APIError $ ErrBadRequest err)
      Right valid -> do
        created <- liftIO $ DBAsset.createAsset pool valid
        json (APIOk created)

  post "/api/v1/assets/:id/depreciate" $ withAuth authCfg $ \_ -> do
    aid <- param "id"
    period <- param "period"
    ok <- liftIO $ DBAsset.depreciateAsset pool aid period
    json (APIOk (object ["updated" .= ok]))

  get "/api/v1/assets/:id/events" $ withAuth authCfg $ \_ -> do
    aid <- param "id"
    events <- liftIO $ DBAsset.listAssetEvents pool aid
    json (APIOk events)

  get "/api/v1/assets/:id/depreciations" $ withAuth authCfg $ \_ -> do
    aid <- param "id"
    deps <- liftIO $ DBAsset.listAssetDepreciations pool aid
    json (APIOk deps)

reportSummary :: Reports.ReportDef -> Value
reportSummary r = object
  [ "name" .= Reports.rdName r
  , "title" .= Reports.rdTitle r
  , "category" .= reportCategoryName (Reports.rdCategory r)
  , "description" .= Reports.rdDescription r
  ]

reportDetail :: Reports.ReportDef -> Value
reportDetail r = reportSummary r <> object
  [ "sql" .= Reports.rdSql r
  , "jrxml" .= Reports.rdJrxml r
  , "params" .= map paramToValue (Reports.rdParams r)
  , "fields" .= map fieldToValue (Reports.rdFields r)
  , "groups" .= map groupToValue (Reports.rdGroups r)
  ]

paramToValue :: Reports.ParamDef -> Value
paramToValue p = object
  [ "name" .= pName p
  , "type" .= paramTypeName (pType p)
  , "label" .= pLabel p
  , "required" .= pRequired p
  , "default" .= pDefault p
  ]

fieldToValue :: Reports.FieldDef -> Value
fieldToValue f = object
  [ "name" .= fName f
  , "type" .= fieldTypeName (fType f)
  , "formula" .= fFormula f
  ]

groupToValue :: Reports.GroupDef -> Value
groupToValue g = object
  [ "name" .= gName g
  , "field" .= gField g
  , "ascending" .= gSortAsc g
  ]

reportCategoryName :: Reports.ReportCategory -> Text
reportCategoryName = T.pack . show

paramTypeName :: Reports.ParamType -> Text
paramTypeName = T.pack . show

fieldTypeName :: Reports.FieldType -> Text
fieldTypeName = T.pack . show

documentRoutes :: Pool -> JWT.JWTConfig -> ScottyM ()
documentRoutes pool authCfg = do
  get "/api/v1/documents/registers" $ withAuth authCfg $ \_ -> do
    limit <- paramWithDefault "limit" 50
    offset <- paramWithDefault "offset" 0
    personId <- optionalParam "personId"
    typeId <- optionalParam "typeId"
    number <- optionalParam "number"
    registers <- liftIO $
      DBDocumentRegister.listRegisters pool (Pagination limit offset) DocumentRegisterFilter
        { drfPersonId = personId
        , drfTypeId = typeId
        , drfNumber = number
        }
    json (APIOk registers)

  get "/api/v1/documents/registers/:id" $ withAuth authCfg $ \_ -> do
    rid <- param "id"
    mreg <- liftIO $ DBDocumentRegister.getRegister pool rid
    case mreg of
      Nothing -> json (APIError $ ErrNotFound "Register not found")
      Just reg -> json (APIOk reg)

  post "/api/v1/documents/registers" $ withAuth authCfg $ \_ -> do
    reg <- jsonData
    case validateDocumentRegister reg of
      Left err -> json (APIError $ ErrBadRequest err)
      Right valid -> do
        newId <- liftIO $ DBDocumentRegister.createRegister pool valid
        json (APIOk valid { drId = Just newId })

  put "/api/v1/documents/registers/:id" $ withAuth authCfg $ \_ -> do
    rid <- param "id"
    reg <- jsonData
    case validateDocumentRegister reg of
      Left err -> json (APIError $ ErrBadRequest err)
      Right valid -> do
        updated <- liftIO $ DBDocumentRegister.updateRegister pool rid valid
        if updated
          then json (APIOk valid { drId = Just rid })
          else json (APIError $ ErrNotFound "Register not found")

  delete "/api/v1/documents/registers/:id" $ withAuth authCfg $ \_ -> do
    rid <- param "id"
    deleted <- liftIO $ DBDocumentRegister.deleteRegister pool rid
    if deleted
      then json (APIOk (object ["deleted" .= rid]))
      else json (APIError $ ErrNotFound "Register not found")

  get "/api/v1/documents/counters" $ withAuth authCfg $ \_ -> do
    limit <- paramWithDefault "limit" 50
    offset <- paramWithDefault "offset" 0
    counters <- liftIO $ DBDocumentCounter.listDocumentCounters pool (Pagination limit offset)
    json (APIOk counters)

  get "/api/v1/documents/counters/:id" $ withAuth authCfg $ \_ -> do
    cid <- param "id"
    mc <- liftIO $ DBDocumentCounter.getDocumentCounter pool cid
    case mc of
      Nothing -> json (APIError $ ErrNotFound "Counter not found")
      Just c -> json (APIOk c)

  post "/api/v1/documents/counters" $ withAuth authCfg $ \_ -> do
    counter <- jsonData
    case validateDocumentOpCounter counter of
      Left err -> json (APIError $ ErrBadRequest err)
      Right valid -> do
        newId <- liftIO $ DBDocumentCounter.createDocumentCounter pool valid
        json (APIOk valid { docCounterId = Just newId })

  put "/api/v1/documents/counters/:id" $ withAuth authCfg $ \_ -> do
    cid <- param "id"
    counter <- jsonData
    case validateDocumentOpCounter counter of
      Left err -> json (APIError $ ErrBadRequest err)
      Right valid -> do
        updated <- liftIO $ DBDocumentCounter.updateDocumentCounter pool cid valid
        if updated
          then json (APIOk valid { docCounterId = Just cid })
          else json (APIError $ ErrNotFound "Counter not found")

  delete "/api/v1/documents/counters/:id" $ withAuth authCfg $ \_ -> do
    cid <- param "id"
    deleted <- liftIO $ DBDocumentCounter.deleteDocumentCounter pool cid
    if deleted
      then json (APIOk (object ["deleted" .= cid]))
      else json (APIError $ ErrNotFound "Counter not found")

  get "/api/v1/documents/counters/:id/next-number" $ withAuth authCfg $ \_ -> do
    cid <- param "id"
    nextNumber <- liftIO $ DBDocumentCounter.getNextDocumentNumber pool (fromIntegral (cid :: Int64))
    json (APIOk (object ["next_number" .= nextNumber]))

  post "/api/v1/documents/audit" $ withAuth authCfg $ \_ -> do
    payload <- jsonData
    uuid <- liftIO UUIDv4.nextRandom
    let jobPayload = toStrict $ TLE.decodeUtf8 $ encode payload
        jobReq = JobRequest
          { jrCode = T.concat ["doc-audit-", T.pack (show (toText uuid))]
          , jrName = "Document register audit"
          , jrType = "document_register_audit"
          , jrPriority = 5
          , jrPayload = Just jobPayload
          , jrScheduled = Nothing
          }
    jid <- liftIO $ DBJobQueue.enqueueJob pool jobReq
    json (APIOk (object ["jobId" .= jid]))

registerTypeRoutes pool authCfg

  reportScheduleRoutes pool authCfg

registerTypeRoutes :: Pool -> JWT.JWTConfig -> ScottyM ()
registerTypeRoutes pool authCfg = do
  get "/api/v1/documents/register-types" $ withAuth authCfg $ \_ -> do
    types <- liftIO $ DBDocumentRegisterType.listRegisterTypes pool
    json (APIOk types)

  get "/api/v1/documents/register-types/:id" $ withAuth authCfg $ \_ -> do
    rid <- param "id"
    mtype <- liftIO $ DBDocumentRegisterType.getRegisterType pool rid
    maybe (json (APIError $ ErrNotFound "Register type not found")) (json . APIOk) mtype

  get "/api/v1/documents/register-types/code/:code" $ withAuth authCfg $ \_ -> do
    code <- param "code"
    mtype <- liftIO $ DBDocumentRegisterType.getRegisterTypeByCode pool code
    maybe (json (APIError $ ErrNotFound "Register type not found")) (json . APIOk) mtype

  post "/api/v1/documents/register-types" $ withAuth authCfg $ \_ -> do
    drt <- jsonData
    case validateDocumentRegisterType drt of
      Left err -> json (APIError $ ErrBadRequest err)
      Right valid -> do
        newId <- liftIO $ DBDocumentRegisterType.createRegisterType pool valid
        json (APIOk valid { drtId = Just newId })

  put "/api/v1/documents/register-types/:id" $ withAuth authCfg $ \_ -> do
    rid <- param "id"
    drt <- jsonData
    case validateDocumentRegisterType drt of
      Left err -> json (APIError $ ErrBadRequest err)
      Right valid -> do
        updated <- liftIO $ DBDocumentRegisterType.updateRegisterType pool rid valid
        if updated
          then json (APIOk valid { drtId = Just rid })
          else json (APIError $ ErrNotFound "Register type not found")

  delete "/api/v1/documents/register-types/:id" $ withAuth authCfg $ \_ -> do
    rid <- param "id"
    deleted <- liftIO $ DBDocumentRegisterType.deleteRegisterType pool rid
    if deleted
      then json (APIOk (object ["deleted" .= rid]))
      else json (APIError $ ErrNotFound "Register type not found")

  get "/api/v1/documents/register-types/:id/next-number" $ withAuth authCfg $ \_ -> do
    rid <- param "id"
    nextNumber <- liftIO $ DBDocumentRegisterType.getNextRegisterNumber pool rid
    json (APIOk (object ["next_number" .= nextNumber]))

reportRoutes :: Pool -> JWT.JWTConfig -> ScottyM ()
reportRoutes _ authCfg = do
  get "/api/v1/reports" $ withAuth authCfg $ \_ -> do
    let reports = map reportSummary (Map.elems Reports.allReports)
    json (APIOk reports)

  get "/api/v1/reports/:name" $ withAuth authCfg $ \_ -> do
    name <- param "name"
    case Reports.getReport name of
      Nothing -> json (APIError $ ErrNotFound "Report not found")
      Just report -> json (APIOk (reportDetail report))

  get "/api/v1/reports/templates" $ withAuth authCfg $ \_ -> do
    let templates = map (\(name, def) ->
          object
            [ "name" .= name
            , "title" .= Reports.rdTitle def
            , "category" .= reportCategoryName (Reports.rdCategory def)
            , "description" .= Reports.rdDescription def
            ]) reportScheduleTemplates
    json (APIOk templates)

  reportScheduleRoutes pool authCfg

reportScheduleRoutes :: Pool -> JWT.JWTConfig -> ScottyM ()
reportScheduleRoutes pool authCfg = do
  get "/api/v1/reports/schedules" $ withAuth authCfg $ \_ -> do
    schedules <- liftIO $ DBReportSchedule.listReportSchedules pool
    json (APIOk schedules)

  post "/api/v1/reports/schedules" $ withAuth authCfg $ \_ -> do
    input <- jsonData
    case validateReportSchedule input of
      Left err -> json (APIError $ ErrBadRequest err)
      Right valid -> do
        newId <- liftIO $ DBReportSchedule.createReportSchedule pool valid
        json (APIOk (object ["id" .= newId]))

  put "/api/v1/reports/schedules/:id" $ withAuth authCfg $ \_ -> do
    rid <- param "id"
    input <- jsonData
    case validateReportSchedule input of
      Left err -> json (APIError $ ErrBadRequest err)
      Right valid -> do
        updated <- liftIO $ DBReportSchedule.updateReportSchedule pool rid valid
        if updated
          then json (APIOk (object ["updated" .= rid]))
          else json (APIError $ ErrNotFound "Schedule not found")

  delete "/api/v1/reports/schedules/:id" $ withAuth authCfg $ \_ -> do
    rid <- param "id"
    deleted <- liftIO $ DBReportSchedule.deleteReportSchedule pool rid
    if deleted
      then json (APIOk (object ["deleted" .= rid]))
      else json (APIError $ ErrNotFound "Schedule not found")

  get "/api/v1/reports/schedules/:id/snapshots" $ withAuth authCfg $ \_ -> do
    rid <- param "id"
    snaps <- liftIO $ DBReportSchedule.listReportSnapshots pool rid
    json (APIOk snaps)

  post "/api/v1/reports/schedules/:id/run" $ withAuth authCfg $ \_ -> do
    rid <- param "id"
    msched <- liftIO $ DBReportSchedule.getReportSchedule pool rid
    case msched of
      Nothing -> json (APIError $ ErrNotFound "Schedule not found")
      Just sched -> do
        uuid <- liftIO UUIDv4.nextRandom
        let payload = ReportRenderPayload { rrpScheduleId = rid }
            payloadText = toStrict $ TLE.decodeUtf8 $ encode payload
            jobReq = JobRequest
              { jrCode = T.concat ["report-render-", T.pack (show rid), "-", T.pack (show (toText uuid))]
              , jrName = T.concat ["Render report ", rsName sched]
              , jrType = "report_render"
              , jrPriority = 5
              , jrPayload = Just payloadText
              , jrScheduled = Nothing
              }
        jid <- liftIO $ DBJobQueue.enqueueJob pool jobReq
        json (APIOk (object ["jobId" .= jid]))

jobRoutes :: Pool -> JWT.JWTConfig -> ScottyM ()
jobRoutes pool authCfg = do
  get "/api/v1/jobs" $ withAuth authCfg $ \_ -> do
    status <- optionalParam "status"
    jobType <- optionalParam "type"
    let jobFilter = JobFilter (fmap jobStatusFromText status) jobType
    jobs <- liftIO $ DBJobQueue.listJobs pool jobFilter
    json (APIOk jobs)

  get "/api/v1/jobs/:id" $ withAuth authCfg $ \_ -> do
    jid <- param "id"
    mj <- liftIO $ DBJobQueue.getJob pool jid
    maybe (json (APIError $ ErrNotFound "Job not found")) (json . APIOk) mj

  post "/api/v1/jobs" $ withAuth authCfg $ \_ -> do
    request <- jsonData
    case validateJobRequest request of
      Left err -> json (APIError $ ErrBadRequest err)
      Right valid -> do
        jid <- liftIO $ DBJobQueue.enqueueJob pool valid
        mj <- liftIO $ DBJobQueue.getJob pool jid
        maybe (json (APIError $ ErrInternal "Failed to load job")) (json . APIOk) mj

  patch "/api/v1/jobs/:id/status" $ withAuth authCfg $ \_ -> do
    jid <- param "id"
    statusUpdate <- jsonData
    let newStatus = jobStatusFromText (jsuStatus statusUpdate)
    updated <- liftIO $ DBJobQueue.setJobStatus pool jid newStatus (jsuMessage statusUpdate)
    if updated
      then json (APIOk (object ["updated" .= jid, "status" .= jsuStatus statusUpdate]))
      else json (APIError $ ErrNotFound "Job not found")

  post "/api/v1/jobs/:id/dependencies" $ withAuth authCfg $ \_ -> do
    jid <- param "id"
    req <- jsonData
    let dependencyTypeText = fromMaybe "BLOCKS" (dependencyType req)
    added <- liftIO $ DBJobQueue.addJobDependency pool jid (dependsOnId req) dependencyTypeText
    if added
      then json (APIOk (object ["added" .= True, "jobId" .= jid, "dependsOn" .= dependsOnId req]))
      else json (APIError $ ErrInternal "dependency already exists or failed")

productionRoutes :: Pool -> JWT.JWTConfig -> ScottyM ()
productionRoutes pool authCfg = do
  get "/api/v1/production/tech" $ withAuth authCfg $ \_ -> do
    name <- optionalParam "name"
    goodsId <- optionalParam "goodsId"
    let goodsId64 = fmap fromIntegral (goodsId :: Maybe Int)
    techs <- liftIO $ DBProduction.listTechs pool TechFilter { tfName = name, tfGoodsId = goodsId64 }
    json (APIOk techs)

  get "/api/v1/production/tech-cards" $ withAuth authCfg $ \_ -> do
    cards <- liftIO $ DBTechCard.listTechCards pool
    json (APIOk cards)

  get "/api/v1/production/tech-cards/:id" $ withAuth authCfg $ \_ -> do
    tid <- param "id"
    card <- liftIO $ DBTechCard.getTechCard pool (fromIntegral (tid :: Int))
    maybe (json (APIError $ ErrNotFound "Tech card not found")) (json . APIOk) card

  get "/api/v1/production/tech/:id" $ withAuth authCfg $ \_ -> do
    techId <- param "id"
    mtech <- liftIO $ DBProduction.getTech pool (fromIntegral (techId :: Int))
    maybe (json (APIError $ ErrNotFound "Technology not found")) (json . APIOk) mtech

  get "/api/v1/production/resources" $ withAuth authCfg $ \_ -> do
    resources <- liftIO $ DBProduction.listResources pool
    json (APIOk resources)

  get "/api/v1/production/work-orders" $ withAuth authCfg $ \_ -> do
    orders <- liftIO $ DBProduction.listWorkOrders pool
    json (APIOk orders)

  post "/api/v1/production/work-orders" $ withAuth authCfg $ \_ -> do
    WorkOrderInput{..} <- jsonData
    wid <- liftIO $ DBProduction.createWorkOrder pool woiCode woiDate woiDueDate woiProductId woiQuantity
    json (APIOk (object ["id" .= wid]))

  post "/api/v1/production/work-orders/:id/release" $ withAuth authCfg $ \_ -> do
    oid <- param "id"
    dt <- param "date"
    ok <- liftIO $ DBProduction.releaseWorkOrder pool oid dt
    json (APIOk (object ["released" .= ok]))

  post "/api/v1/production/work-orders/:id/complete" $ withAuth authCfg $ \_ -> do
    oid <- param "id"
    qty <- param "output"
    ok <- liftIO $ DBProduction.completeWorkOrder pool oid qty
    json (APIOk (object ["completed" .= ok]))

  get "/api/v1/production/tech-cards/:id/lines" $ withAuth authCfg $ \_ -> do
    tid <- param "id"
    lines <- liftIO $ DBTechCard.listTechLines pool (fromIntegral (tid :: Int))
    json (APIOk lines)

  post "/api/v1/production/tech-cards" $ withAuth authCfg $ \_ -> do
    input <- jsonData
    case validateTechCardInput input of
      Left err -> json (APIError $ ErrBadRequest err)
      Right valid -> case traverse validateTechLineInput (tciLines valid) of
        Left errLine -> json (APIError $ ErrBadRequest errLine)
        Right validatedLines -> do
          tid <- liftIO $ DBTechCard.createTechCard pool
            (tciProcessorId valid)
            (tciGoodsGroupId valid)
            (tciKind valid)
            (tciFormula valid)
          forM_ validatedLines $ \line ->
            liftIO $ DBTechCard.addTechLine pool
              tid
              (tliLineNo line)
              (tliGoodsId line)
              (tliQtty line)
              (tliSign line)
              (tliFormula line)
              (tliLineTime line)
              (tliLineCost line)
          json (APIOk (object ["techCardId" .= tid]))

  post "/api/v1/production/tech-cards/:id/lines" $ withAuth authCfg $ \_ -> do
    tid <- param "id"
    line <- jsonData
    case validateTechLineInput line of
      Left err -> json (APIError $ ErrBadRequest err)
      Right validLine -> do
        _ <- liftIO $ DBTechCard.addTechLine pool
          (fromIntegral (tid :: Int))
          (tliLineNo validLine)
          (tliGoodsId validLine)
          (tliQtty validLine)
          (tliSign validLine)
          (tliFormula validLine)
          (tliLineTime validLine)
          (tliLineCost validLine)
        json (APIOk validLine)
  get "/api/v1/production/bom/:product" $ withAuth authCfg $ \_ -> do
    productId <- param "product"
    entries <- liftIO $ DBProduction.listBOMForProduct pool productId
    json (APIOk entries)

  post "/api/v1/production/mrp" $ withAuth authCfg $ \_ -> do
    needs <- jsonData
    uuid <- liftIO UUIDv4.nextRandom
    let payloadText = toStrict $ TLE.decodeUtf8 $ encode needs
        jobReq = JobRequest
          { jrCode = T.concat ["mrp-plan-", T.pack (show (toText uuid))]
          , jrName = "MRP plan"
          , jrType = "mrp_plan"
          , jrPriority = 5
          , jrPayload = Just payloadText
          , jrScheduled = Nothing
          }
    jid <- liftIO $ DBJobQueue.enqueueJob pool jobReq
    json (APIOk (object ["jobId" .= jid]))

  get "/api/v1/production/plan-snapshots" $ withAuth authCfg $ \_ -> do
    snaps <- liftIO $ DBProduction.listProductionPlanSnapshots pool
    json (APIOk snaps)

  get "/api/v1/production/tech/:id/time" $ withAuth authCfg $ \_ -> do
    techId <- param "id"
    duration <- liftIO $ DBProduction.calculateTechTime pool (fromIntegral (techId :: Int))
    json (APIOk (object ["techId" .= techId, "durationMinutes" .= duration]))

  get "/api/v1/production/tech/:id/cost" $ withAuth authCfg $ \_ -> do
    techId <- param "id"
    materialCost <- paramWithDefault "materialCost" 0.0
    cost <- liftIO $ DBProduction.calculateTechCost pool (fromIntegral (techId :: Int)) materialCost
    json (APIOk (object ["techId" .= techId, "materialCost" .= materialCost, "totalCost" .= cost]))

paramWithDefault :: Parsable a => Text -> a -> ActionM a
paramWithDefault name def = (param name) `rescue` const (return def)

optionalParam :: Parsable a => Text -> ActionM (Maybe a)
optionalParam name = (Just <$> param name) `rescue` const (return Nothing)

withAuth :: JWT.JWTConfig -> (JWT.TokenClaims -> ActionM a) -> ActionM a
withAuth cfg action = do
  claims <- requireAuth cfg
  action claims

requireAuth :: JWT.JWTConfig -> ActionM JWT.TokenClaims
requireAuth cfg = do
  mHeader <- header \"Authorization\"
  token <- case mHeader of
    Nothing -> authError \"missing authorization header\"
    Just hdr -> return $ extractToken hdr
  decoded <- liftIO $ JWT.verifyToken cfg token
  case decoded of
    Right claims -> return claims
    Left err -> authError err

authError :: Text -> ActionM a
authError msg = json (APIError $ ErrBadRequest msg) >> finish

extractToken :: Text -> Text
extractToken hdr = fromMaybe hdr (T.stripPrefix \"Bearer \" hdr)
