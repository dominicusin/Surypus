{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE UndecidableInstances #-}

module Surypus.API.Root
  ( LoginRequest (..),
    LoginResponse (..),
    LogoutResponse (..),
    RefreshRequest (..),
    RefreshResponse (..),
    CurrentUserResponse (..),
    RoleCreateRequest (..),
    RoleInfoResponse (..),
    GrantsListResponse (..),
    GrantCreateRequest (..),
    GrantUpdateRequest (..),
    GrantInfoResponse (..),
    AuditListResponse (..),
    CleanupResponse (..),
    HealthResponse (..),
    HealthLiveResponse (..),
    HealthReadyResponse (..),
    MetricsResponse (..),
    RolesListResponse (..),
    JobRequest (..),
    JobResponse (..),
    JobsPendingResponse (..),
    UsersResponse (..),
    AuditLogListResponse (..),
    JobsResponse (..),
    ReportResponse (..),
    ReportJRXMLResponse (..),
    DashboardResponse (..),
    ReportsResponse (..),
    ReportsMetadataResponse (..),
    EmployeeResponse (..),
    SalaryResponse (..),
    SalariesResponse (..),
    AccEntryResponse (..),
    PayrollResponse (..),
    EmployeesResponse (..),
    AccEntryRequest (..),
    AccEntriesResponse (..),
    AccPlanRequest (..),
    AccPlanResponse (..),
    AccountsResponse (..),
    StockResponse (..),
    StockItemResponse (..),
    CurrencyResponse (..),
    CurrenciesResponse (..),
    CurrencyRequest (..),
    PersonRequest (..),
    PersonsResponse (..),
    PersonResponse (..),
    GoodRequest (..),
    GoodsResponse (..),
    GoodResponse (..),
    LocationRequest (..),
    LocationsResponse (..),
    LocationResponse (..),
    BillRequest (..),
    BillsResponse (..),
    BillResponse (..),
    PaymentRequest (..),
    PaymentsResponse (..),
    PaymentResponse (..),
    OrderRequest (..),
    OrdersResponse (..),
    OrderResponse (..),
    TaxResponse (..),
    TaxesResponse (..),
    TaxRequest (..),
    VATCalcRequest (..),
    VATCalcResponse (..),
    APIv1,
    ProtectedAPI,
    API,
    APIWithDoc,
    apiSwagger,
  )
where

import DAL.Types (AuditLog)
import Data.Aeson (FromJSON, ToJSON, Value, object, (.=))
import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (Day)
import GHC.Generics (Generic)
import Servant
import Surypus.API.Balance (BalanceAPI)
import Surypus.API.Types
  ( LoginRequest (..),
    LoginResponse (..),
    UserResponse (..),
  )
import Surypus.RBAC (AuditEntry)

type APIv1 = "v1" :> (AuthAPI :<|> ProtectedAPI)

type API = APIv1

type ProtectedAPI = PersonsAPI :<|> GoodsAPI :<|> LocationsAPI :<|> BillsAPI :<|> PaymentsAPI :<|> OrdersAPI :<|> TaxesAPI :<|> VATAPI :<|> CurrenciesAPI :<|> StockAPI :<|> AccountingAPI :<|> PayrollAPI :<|> ReportsAPI :<|> DashboardAPI :<|> BalanceAPI :<|> UsersAPI :<|> AuditLogAPI :<|> RbacAPI :<|> HealthAPI :<|> MetricsAPI

-- | Full API with Swagger documentation
type APIWithDoc = "api" :> APIv1 :<|> "swagger.json" :> Get '[JSON] Value

apiSwagger :: Value
apiSwagger =
  object
    [ "openapi" .= ("3.0.0" :: Text),
      "info" .= object ["title" .= ("Surypus API" :: Text), "version" .= ("1.0.0" :: Text)],
      "paths" .= object []
    ]

type AuthAPI =
  "login" :> ReqBody '[JSON] LoginRequest :> Post '[JSON] LoginResponse
    :<|> "logout" :> Post '[JSON] LogoutResponse
    :<|> "refresh" :> ReqBody '[JSON] RefreshRequest :> Post '[JSON] RefreshResponse
    :<|> "me" :> Get '[JSON] CurrentUserResponse

type PersonsAPI =
  "persons"
    :> ( QueryParam "name" Text :> QueryParam "inn" Text :> QueryParam "type" Int :> QueryParam "status" Int :> QueryParam "limit" Int :> Get '[JSON] PersonsResponse
           :<|> ReqBody '[JSON] PersonRequest :> Post '[JSON] PersonResponse
           :<|> Capture "id" Int64 :> Get '[JSON] PersonResponse
           :<|> Capture "id" Int64 :> ReqBody '[JSON] PersonRequest :> Put '[JSON] PersonResponse
           :<|> Capture "id" Int64 :> Delete '[JSON] ()
           :<|> "search" :> QueryParam "q" Text :> Get '[JSON] PersonsResponse
       )

type GoodsAPI =
  "goods"
    :> ( QueryParam "name" Text :> QueryParam "barcode" Text :> QueryParam "code" Text :> Get '[JSON] GoodsResponse
           :<|> ReqBody '[JSON] GoodRequest :> Post '[JSON] GoodResponse
           :<|> Capture "id" Int64 :> Get '[JSON] GoodResponse
           :<|> Capture "id" Int64 :> ReqBody '[JSON] GoodRequest :> Put '[JSON] GoodResponse
           :<|> Capture "id" Int64 :> Delete '[JSON] ()
           :<|> "search" :> QueryParam "q" Text :> Get '[JSON] GoodsResponse
       )

type LocationsAPI =
  "locations"
    :> ( Get '[JSON] LocationsResponse
           :<|> ReqBody '[JSON] LocationRequest :> Post '[JSON] LocationResponse
           :<|> Capture "id" Int64 :> Get '[JSON] LocationResponse
           :<|> Capture "id" Int64 :> ReqBody '[JSON] LocationRequest :> Put '[JSON] LocationResponse
           :<|> Capture "id" Int64 :> Delete '[JSON] ()
       )

type BillsAPI =
  "bills"
    :> ( Get '[JSON] BillsResponse
           :<|> ReqBody '[JSON] BillRequest :> Post '[JSON] BillResponse
           :<|> Capture "id" Int64 :> Get '[JSON] BillResponse
           :<|> Capture "id" Int64 :> ReqBody '[JSON] BillRequest :> Put '[JSON] BillResponse
           :<|> Capture "id" Int64 :> Delete '[JSON] ()
           :<|> Capture "id" Int64 :> "status" :> QueryParam "status" Text :> Put '[JSON] BillResponse
       )

type PaymentsAPI =
  "payments"
    :> ( Get '[JSON] PaymentsResponse
           :<|> ReqBody '[JSON] PaymentRequest :> Post '[JSON] PaymentResponse
           :<|> Capture "id" Int64 :> Get '[JSON] PaymentResponse
           :<|> Capture "id" Int64 :> ReqBody '[JSON] PaymentRequest :> Put '[JSON] PaymentResponse
           :<|> Capture "id" Int64 :> Delete '[JSON] ()
       )

type OrdersAPI =
  "orders"
    :> ( Get '[JSON] OrdersResponse
           :<|> ReqBody '[JSON] OrderRequest :> Post '[JSON] OrderResponse
           :<|> Capture "id" Int64 :> Get '[JSON] OrderResponse
           :<|> Capture "id" Int64 :> "status" :> QueryParam "status" Int :> Put '[JSON] OrderResponse
           :<|> Capture "id" Int64 :> Delete '[JSON] ()
       )

type TaxesAPI =
  "taxes"
    :> ( Get '[JSON] TaxesResponse
           :<|> ReqBody '[JSON] TaxRequest :> Post '[JSON] TaxResponse
           :<|> Capture "id" Int64 :> Get '[JSON] TaxResponse
           :<|> Capture "id" Int64 :> ReqBody '[JSON] TaxRequest :> Put '[JSON] TaxResponse
           :<|> Capture "id" Int64 :> Delete '[JSON] ()
       )

type CurrenciesAPI =
  "currencies"
    :> ( Get '[JSON] CurrenciesResponse
           :<|> ReqBody '[JSON] CurrencyRequest :> Post '[JSON] CurrencyResponse
           :<|> Capture "id" Int64 :> Get '[JSON] CurrencyResponse
           :<|> Capture "id" Int64 :> ReqBody '[JSON] CurrencyRequest :> Put '[JSON] CurrencyResponse
           :<|> Capture "id" Int64 :> Delete '[JSON] ()
       )

type StockAPI =
  "stock"
    :> ( Get '[JSON] StockResponse
           :<|> "summary" :> Get '[JSON] StockResponse
           :<|> Capture "gid" Int64 :> "locations" :> Capture "lid" Int64 :> Get '[JSON] StockItemResponse
           :<|> "goods" :> Capture "gid" Int64 :> Get '[JSON] StockResponse
       )

type AccountingAPI =
  "accounting"
    :> ( Get '[JSON] AccountsResponse
           :<|> ReqBody '[JSON] AccPlanRequest :> Post '[JSON] AccPlanResponse
           :<|> Capture "id" Int64 :> Get '[JSON] AccPlanResponse
           :<|> Capture "id" Int64 :> ReqBody '[JSON] AccPlanRequest :> Put '[JSON] AccPlanResponse
           :<|> Capture "id" Int64 :> Delete '[JSON] ()
           :<|> "entries" :> Get '[JSON] AccEntriesResponse
           :<|> "entries" :> ReqBody '[JSON] AccEntryRequest :> Post '[JSON] AccEntryResponse
           :<|> "entries" :> Capture "id" Int64 :> Get '[JSON] AccEntryResponse
           :<|> "entries" :> Capture "id" Int64 :> ReqBody '[JSON] AccEntryRequest :> Put '[JSON] AccEntryResponse
           :<|> "entries" :> Capture "id" Int64 :> Delete '[JSON] ()
       )

type PayrollAPI =
  "payroll"
    :> ( Get '[JSON] PayrollResponse
           :<|> "employees" :> Get '[JSON] EmployeesResponse
           :<|> "employees" :> Capture "id" Int64 :> Get '[JSON] EmployeeResponse
           :<|> "salaries" :> Get '[JSON] SalariesResponse
           :<|> "salary" :> Capture "eid" Int64 :> Get '[JSON] SalaryResponse
       )

type ReportsAPI =
  "reports"
    :> ( Get '[JSON] ReportsResponse
           :<|> "metadata" :> Get '[JSON] ReportsMetadataResponse
           :<|> "templates" :> Get '[JSON] ReportsResponse
           :<|> Capture "id" Int64 :> Get '[JSON] ReportResponse
           :<|> "jrxml" :> Capture "name" Text :> Get '[JSON] ReportJRXMLResponse
       )

type DashboardAPI = "dashboard" :> Get '[JSON] DashboardResponse

type UsersAPI = "users" :> Get '[JSON] UsersResponse

type AuditLogAPI =
  "audit-log"
    :> QueryParam "entity_type" Text
    :> QueryParam "limit" Int64
    :> QueryParam "offset" Int64
    :> Get '[JSON] AuditLogListResponse

type RbacAPI =
  "rbac"
    :> ( "roles"
           :> ( Get '[JSON] RolesListResponse
                  :<|> ReqBody '[JSON] RoleCreateRequest :> Post '[JSON] RoleInfoResponse
                  :<|> Capture "name" Text :> ReqBody '[JSON] RoleCreateRequest :> Put '[JSON] RoleInfoResponse
                  :<|> Capture "name" Text :> Delete '[JSON] ()
              )
           :<|> "grants"
             :> ( Get '[JSON] GrantsListResponse
                    :<|> ReqBody '[JSON] GrantCreateRequest :> Post '[JSON] GrantInfoResponse
                    :<|> "active" :> QueryParam "principal" Text :> Get '[JSON] GrantsListResponse
                    :<|> "cleanup" :> Post '[JSON] CleanupResponse
                    :<|> Capture "from" Text :> Capture "to" Text :> Capture "permission" Text :> QueryParam "resource" Text :> ReqBody '[JSON] GrantUpdateRequest :> Put '[JSON] GrantInfoResponse
                    :<|> Capture "from" Text :> Capture "to" Text :> Capture "permission" Text :> QueryParam "resource" Text :> Delete '[JSON] ()
                )
           :<|> "audit"
             :> ( QueryParam "principal" Text :> QueryParam "resource" Text :> QueryParam "offset" Int64 :> QueryParam "limit" Int64 :> Get '[JSON] AuditListResponse
                    :<|> "cleanup" :> QueryParam "keep" Int64 :> Post '[JSON] CleanupResponse
                )
       )

type JobsAPI =
  "jobs"
    :> ( Get '[JSON] JobsResponse
           :<|> "pending" :> Get '[JSON] JobsPendingResponse
           :<|> ReqBody '[JSON] JobRequest :> Post '[JSON] JobResponse
       )

type HealthAPI = "health" :> (Get '[JSON] HealthResponse :<|> "live" :> Get '[JSON] HealthLiveResponse :<|> "ready" :> Get '[JSON] HealthReadyResponse)

type MetricsAPI = "metrics" :> Get '[JSON] MetricsResponse

data HealthResponse = HealthResponse
  { status :: Text,
    checks :: Value
  }
  deriving (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

data HealthLiveResponse = HealthLiveResponse
  { liveStatus :: Text
  }
  deriving (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

data HealthReadyResponse = HealthReadyResponse
  { readyStatus :: Text,
    readyDb :: Text
  }
  deriving (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

data MetricsResponse = MetricsResponse
  { httpRequestsTotal :: Int64,
    httpResponses4xx :: Int64,
    httpResponses5xx :: Int64,
    dbConnectionsActive :: Int64,
    dbConnectionsIdle :: Int64,
    jobsPending :: Int64,
    jobsRunning :: Int64,
    jobsCompleted :: Int64,
    jobsFailed :: Int64
  }
  deriving (Show, Eq, Generic)
  deriving anyclass (ToJSON)

data RolesResponse = RolesResponse
  { roles :: [Value]
  }
  deriving (Show, Eq, Generic)
  deriving anyclass (ToJSON)

data RoleCreateRequest = RoleCreateRequest
  { rcrName :: Text,
    rcrPermissions :: [Text],
    rcrResources :: [Maybe Text]
  }
  deriving (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

data RoleInfoResponse = RoleInfoResponse
  { rirName :: Text,
    rirPermissions :: [Text]
  }
  deriving (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

data RolesListResponse = RolesListResponse
  { rlrRoles :: [RoleInfoResponse]
  }
  deriving (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

data GrantCreateRequest = GrantCreateRequest
  { gcrFrom :: Text,
    gcrTo :: Text,
    gcrPermission :: Text,
    gcrResource :: Maybe Text,
    gcrExpiresInMinutes :: Maybe Int64
  }
  deriving (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

data GrantUpdateRequest = GrantUpdateRequest
  { gurExpiresInMinutes :: Maybe Int64
  }
  deriving (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

data GrantInfoResponse = GrantInfoResponse
  { girFrom :: Text,
    girTo :: Text,
    girPermission :: Text,
    girResource :: Maybe Text,
    girExpiresAt :: Maybe Text
  }
  deriving (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

data GrantsListResponse = GrantsListResponse
  { glrGrants :: [GrantInfoResponse]
  }
  deriving (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

data AuditListResponse = AuditListResponse
  { alrEntries :: [AuditEntry]
  }
  deriving (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

data AuditLogListResponse = AuditLogListResponse
  { allrEntries :: [AuditLog]
  }
  deriving (Show, Eq, Generic)
  deriving anyclass (ToJSON)

data CleanupResponse = CleanupResponse
  { clrRemoved :: Int64
  }
  deriving (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

data LogoutResponse = LogoutResponse
  { logoutSuccess :: Bool
  }
  deriving (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

data CurrentUserResponse = CurrentUserResponse
  { userId :: Int64,
    userName :: Text,
    role :: Text
  }
  deriving (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

data RefreshRequest = RefreshRequest
  { refreshToken :: Text
  }
  deriving (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

data RefreshResponse = RefreshResponse
  { accessToken :: Text,
    refreshToken :: Text,
    expiresIn :: Int
  }
  deriving (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

data PersonRequest = PersonRequest
  { personName :: Text,
    personINN :: Maybe Text,
    personKPP :: Maybe Text,
    personType :: Maybe Int,
    personStatus :: Maybe Int
  }
  deriving (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

data PersonResponse = PersonResponse
  { personId :: Int64,
    personName :: Text,
    personINN :: Maybe Text,
    personKPP :: Maybe Text,
    personType :: Int,
    personStatus :: Int
  }
  deriving (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

data PersonsResponse = PersonsResponse
  { persons :: [PersonResponse],
    total :: Int64
  }
  deriving (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

data GoodRequest = GoodRequest
  { goodName :: Text,
    goodArticle :: Maybe Text,
    goodUnit :: Maybe Text
  }
  deriving (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

data GoodResponse = GoodResponse
  { goodId :: Int64,
    goodName :: Text,
    goodArticle :: Maybe Text,
    goodUnit :: Maybe Text
  }
  deriving (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

data GoodsResponse = GoodsResponse
  { goods :: [GoodResponse],
    total :: Int64
  }
  deriving (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

data PriceResponse = PriceResponse
  { priceId :: Int64,
    priceGoodsId :: Int64,
    priceValue :: Double,
    priceCurrency :: Text
  }
  deriving (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

data PricesResponse = PricesResponse
  { prices :: [PriceResponse]
  }
  deriving (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

data LocationRequest = LocationRequest
  { locationName :: Text,
    locationType :: Maybe Int
  }
  deriving (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

data LocationResponse = LocationResponse
  { locationId :: Int64,
    locationName :: Text,
    locationType :: Maybe Int
  }
  deriving (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

data LocationsResponse = LocationsResponse
  { locations :: [LocationResponse]
  }
  deriving (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

data BillRequest = BillRequest
  { billName :: Text,
    billType :: Int,
    billDate :: Maybe Day
  }
  deriving (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

data BillResponse = BillResponse
  { billId :: Int64,
    billName :: Text,
    billType :: Int,
    billStatus :: Int,
    billDate :: Day
  }
  deriving (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

data BillsResponse = BillsResponse
  { bills :: [BillResponse]
  }
  deriving (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

data PaymentRequest = PaymentRequest
  { paymentBillId :: Int64,
    paymentAmount :: Double,
    paymentDate :: Maybe Day
  }
  deriving (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

data PaymentResponse = PaymentResponse
  { paymentId :: Int64,
    paymentBillId :: Int64,
    paymentAmount :: Double,
    paymentDate :: Day
  }
  deriving (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

data PaymentsResponse = PaymentsResponse
  { payments :: [PaymentResponse]
  }
  deriving (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

data OrderRequest = OrderRequest
  { orderName :: Text,
    orderDate :: Maybe Day
  }
  deriving (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

data OrderResponse = OrderResponse
  { orderId :: Int64,
    orderName :: Text,
    orderStatus :: Int,
    orderDate :: Day
  }
  deriving (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

data OrdersResponse = OrdersResponse
  { orders :: [OrderResponse]
  }
  deriving (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

data TaxRequest = TaxRequest
  { taxName :: Text,
    taxRate :: Double,
    taxType :: Maybe Text,
    taxInclusive :: Maybe Bool
  }
  deriving (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

data TaxResponse = TaxResponse
  { taxId :: Int64,
    taxName :: Text,
    taxRate :: Double,
    taxType :: Maybe Text,
    taxInclusive :: Maybe Bool
  }
  deriving (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

data TaxesResponse = TaxesResponse
  { taxes :: [TaxResponse]
  }
  deriving (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

-- | VAT calculation request
data VATCalcRequest = VATCalcRequest
  { vatAmount :: Double,
    vatRate :: Double,
    vatInclusive :: Bool
  }
  deriving (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

-- | VAT calculation response
data VATCalcResponse = VATCalcResponse
  { vatNetAmount :: Double,
    vatTaxAmount :: Double,
    vatGrossAmount :: Double,
    vatAppliedRate :: Double
  }
  deriving (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

-- | VAT API endpoint
type VATAPI =
  "vat"
    :> ( "calculate" :> ReqBody '[JSON] VATCalcRequest :> Post '[JSON] VATCalcResponse
           :<|> "rates" :> Get '[JSON] TaxesResponse
       )

data CurrencyRequest = CurrencyRequest
  { currencyName :: Text,
    currencyCode :: Text
  }
  deriving (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

data CurrencyResponse = CurrencyResponse
  { currencyId :: Int64,
    currencyName :: Text,
    currencyCode :: Text
  }
  deriving (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

data CurrenciesResponse = CurrenciesResponse
  { currencies :: [CurrencyResponse]
  }
  deriving (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

data StockItemResponse = StockItemResponse
  { stockGoodsId :: Int64,
    stockLocationId :: Int64,
    stockQuantity :: Double
  }
  deriving (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

data StockResponse = StockResponse
  { items :: [StockItemResponse]
  }
  deriving (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

data InventoryResponse = InventoryResponse
  { documents :: [Value]
  }
  deriving (Show, Eq, Generic)
  deriving anyclass (ToJSON)

data AccPlanRequest = AccPlanRequest
  { accPlanCode :: Text,
    accPlanName :: Text
  }
  deriving (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

data AccPlanResponse = AccPlanResponse
  { accPlanId :: Int64,
    accPlanCode :: Text,
    accPlanName :: Text
  }
  deriving (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

data AccountsResponse = AccountsResponse
  { accounts :: [AccPlanResponse]
  }
  deriving (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

data AccEntryRequest = AccEntryRequest
  { accEntryAccId :: Int64,
    accEntryDebit :: Double,
    accEntryCredit :: Double
  }
  deriving (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

data AccEntryResponse = AccEntryResponse
  { accEntryId :: Int64,
    accEntryAccId :: Int64,
    accEntryDebit :: Double,
    accEntryCredit :: Double
  }
  deriving (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

data AccEntriesResponse = AccEntriesResponse
  { entries :: [AccEntryResponse]
  }
  deriving (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

data EmployeeResponse = EmployeeResponse
  { employeeId :: Int64,
    employeeName :: Text
  }
  deriving (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

data EmployeesResponse = EmployeesResponse
  { employees :: [EmployeeResponse]
  }
  deriving (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

data SalaryResponse = SalaryResponse
  { salaryEmployeeId :: Int64,
    salaryAmount :: Double
  }
  deriving (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

data SalariesResponse = SalariesResponse
  { salaries :: [SalaryResponse]
  }
  deriving (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

data PayrollResponse = PayrollResponse
  { payrollData :: [Value]
  }
  deriving (Show, Eq, Generic)
  deriving anyclass (ToJSON)

data ReportResponse = ReportResponse
  { reportId :: Int64,
    reportName :: Text
  }
  deriving (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

data ReportJRXMLResponse = ReportJRXMLResponse
  { reportName :: Text,
    jrxml :: Text
  }
  deriving (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

data ReportsResponse = ReportsResponse
  { reports :: [ReportResponse]
  }
  deriving (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

data ReportsMetadataResponse = ReportsMetadataResponse
  { metadata :: [Value]
  }
  deriving (Show, Eq, Generic)
  deriving anyclass (ToJSON)

data DashboardResponse = DashboardResponse
  { dashboardStats :: Value
  }
  deriving (Show, Eq, Generic)
  deriving anyclass (ToJSON)

data SalesSummaryResponse = SalesSummaryResponse
  { salesSummary :: Value
  }
  deriving (Show, Eq, Generic)
  deriving anyclass (ToJSON)

data UsersResponse = UsersResponse
  { users :: [UserResponse]
  }
  deriving (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

data JobRequest = JobRequest
  { jobName :: Text
  }
  deriving (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

data JobResponse = JobResponse
  { jobId :: Int64
  }
  deriving (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

data JobsResponse = JobsResponse
  { jobs :: [JobResponse]
  }
  deriving (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

data JobsPendingResponse = JobsPendingResponse
  { pendingCount :: Int
  }
  deriving (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)
