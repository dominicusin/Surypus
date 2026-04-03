{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeOperators #-}

module Surypus.API.Root where

import Data.Aeson (FromJSON, ToJSON, Value)
import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (Day)
import GHC.Generics (Generic)
import Servant
import Surypus.API.Types
  ( ApiRole (..),
    LoginRequest (..),
    LoginResponse (..),
    UserResponse (..),
  )
import Surypus.JWT (JWTPayload (..))

type APIv1 = "v1" :> (AuthAPI :<|> ProtectedAPI)

type ProtectedAPI = PersonsAPI :<|> GoodsAPI :<|> LocationsAPI :<|> BillsAPI :<|> PaymentsAPI :<|> OrdersAPI :<|> TaxesAPI :<|> CurrenciesAPI :<|> StockAPI :<|> AccountingAPI :<|> PayrollAPI :<|> ReportsAPI :<|> DashboardAPI :<|> UsersAPI :<|> JobsAPI :<|> HealthAPI :<|> MetricsAPI

type AuthAPI =
  "login" :> ReqBody '[JSON] LoginRequest :> Post '[JSON] LoginResponse
    :<|> "logout" :> Post '[JSON] LogoutResponse
    :<|> "refresh" :> ReqBody '[JSON] RefreshRequest :> Post '[JSON] RefreshResponse
    :<|> "me" :> Get '[JSON] CurrentUserResponse

type RolesAPI = "roles" :> Get '[JSON] [ApiRole]

type PersonsAPI =
  "persons"
    :> ( Get '[JSON] PersonsResponse
           :<|> ReqBody '[JSON] PersonRequest :> Post '[JSON] PersonResponse
           :<|> Capture "id" Int64 :> Get '[JSON] PersonResponse
           :<|> Capture "id" Int64 :> ReqBody '[JSON] PersonRequest :> Put '[JSON] PersonResponse
           :<|> Capture "id" Int64 :> Delete '[JSON] ()
           :<|> "search" :> Capture "query" Text :> Get '[JSON] PersonsResponse
       )

type GoodsAPI = "goods" :> Get '[JSON] GoodsResponse

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

type JobsAPI =
  "jobs"
    :> ( Get '[JSON] JobsResponse
           :<|> "pending" :> Get '[JSON] JobsPendingResponse
           :<|> ReqBody '[JSON] JobRequest :> Post '[JSON] JobResponse
       )

type HealthAPI = "health" :> Get '[JSON] HealthResponse

type MetricsAPI = "metrics" :> Get '[JSON] MetricsResponse

data HealthResponse = HealthResponse
  { status :: Text
  }
  deriving (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

data MetricsResponse = MetricsResponse
  { httpRequestsTotal :: Int64,
    httpResponses4xx :: Int64,
    httpResponses5xx :: Int64
  }
  deriving (Show, Eq, Generic)
  deriving anyclass (ToJSON)

data RolesResponse = RolesResponse
  { roles :: [Value]
  }
  deriving (Show, Eq, Generic)
  deriving anyclass (ToJSON)

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
    refreshToken :: Text
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
    locationType :: Int
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
    taxRate :: Double
  }
  deriving (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

data TaxResponse = TaxResponse
  { taxId :: Int64,
    taxName :: Text,
    taxRate :: Double
  }
  deriving (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

data TaxesResponse = TaxesResponse
  { taxes :: [TaxResponse]
  }
  deriving (Show, Eq, Generic)
  deriving anyclass (FromJSON, ToJSON)

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

api :: Proxy API
api = Proxy

type API = "api" :> APIv1
