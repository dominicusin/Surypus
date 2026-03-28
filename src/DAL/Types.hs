{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Database Types
module DAL.Types where

import Data.Aeson (FromJSON, ToJSON, object, toJSON, (.=))
import Data.Int (Int16, Int64)
import Data.Text (Text)
import Data.Time (Day, UTCTime)
import GHC.Generics (Generic)
import Surypus.Types (Decimal (..))

-- ============================================================================
-- INPUT TYPES (for Create/Update operations)
-- ============================================================================

data PersonInput = PersonInput
  { piCode :: Maybe Text,
    piName :: Text,
    piINN :: Maybe Text,
    piKPP :: Maybe Text,
    piPersonType :: Int16,
    piStatus :: Int16
  }
  deriving (Show, Eq, Generic)

instance FromJSON PersonInput

data GoodsInput = GoodsInput
  { giCode :: Maybe Text,
    giName :: Text,
    giBarcode :: Maybe Text,
    giUnitId :: Int64,
    giParentId :: Maybe Int64
  }
  deriving (Show, Eq, Generic)

instance FromJSON GoodsInput

data LocationInput = LocationInput
  { liCode :: Maybe Text,
    liName :: Text,
    liType :: Int
  }
  deriving (Show, Eq, Generic)

instance FromJSON LocationInput

-- ============================================================================
-- OUTPUT TYPES
-- ============================================================================

-- | Person types
data Person = Person
  { pId :: Int64,
    pCode :: Maybe Text,
    pName :: Text,
    pINN :: Maybe Text,
    pKPP :: Maybe Text,
    pPersonType :: Int16,
    pStatus :: Int16
  }
  deriving (Show, Eq, Generic)

instance ToJSON Person

-- | Goods types
data Goods = Goods
  { gId :: Int64,
    gCode :: Maybe Text,
    gName :: Text,
    gBarcode :: Maybe Text,
    gUnitId :: Int64,
    gParentId :: Maybe Int64
  }
  deriving (Show, Eq, Generic)

instance ToJSON Goods

-- | Bill types
data Bill = Bill
  { bId :: Int64,
    bCode :: Maybe Text,
    bType :: Int,
    bStatus :: Int,
    bDate :: Day,
    bPersonId :: Maybe Int64,
    bLocationId :: Maybe Int64,
    bTotal :: Decimal,
    bDiscount :: Decimal,
    bTax :: Decimal
  }
  deriving (Show, Eq, Generic)

instance ToJSON Bill

-- | BillLine types
data BillLine = BillLine
  { blId :: Int64,
    blBillId :: Int64,
    blGoodsId :: Int64,
    blQtty :: Decimal,
    blPrice :: Decimal,
    blDiscount :: Decimal,
    blAmount :: Decimal
  }
  deriving (Show, Eq, Generic)

instance ToJSON BillLine

-- | Unit types (for goods)
data Unit = Unit
  { unId :: Int64,
    unCode :: Text,
    unName :: Text,
    unShortName :: Maybe Text
  }
  deriving (Show, Eq, Generic)

instance ToJSON Unit

-- | Location types
data Location = Location
  { lId :: Int64,
    lCode :: Maybe Text,
    lName :: Text,
    lType :: Int
  }
  deriving (Show, Eq, Generic)

instance ToJSON Location

-- | Stock types
data Stock = Stock
  { sId :: Int64,
    sGoodsId :: Int64,
    sLocationId :: Int64,
    sQtty :: Decimal,
    sResrvQtty :: Decimal
  }
  deriving (Show, Eq, Generic)

instance ToJSON Stock

-- | AccPlan types
data AccPlan = AccPlan
  { apId :: Int64,
    apCode :: Text,
    apName :: Text,
    apType :: Int
  }
  deriving (Show, Eq, Generic)

instance ToJSON AccPlan

-- | AccTurn types
data AccTurn = AccTurn
  { atId :: Int64,
    atBillId :: Maybe Int64,
    atDbtAccId :: Int64,
    atCrdAccId :: Int64,
    atAmount :: Decimal,
    atDate :: Day
  }
  deriving (Show, Eq, Generic)

instance ToJSON AccTurn

-- | User types
data User = User
  { uId :: Int64,
    uLogin :: Text,
    uPersonId :: Maybe Int64,
    uName :: Maybe Text,
    uEmail :: Maybe Text,
    uRoleId :: Maybe Int64,
    uStatus :: Int
  }
  deriving (Show, Eq, Generic)

instance ToJSON User

-- | Order types (similar to Bill)
data Order = Order
  { oId :: Int64,
    oCode :: Maybe Text,
    oName :: Maybe Text,
    oDate :: Day,
    oPersonId :: Maybe Int64,
    oLocationId :: Maybe Int64,
    oStatus :: Int,
    oTotal :: Decimal,
    oDiscount :: Decimal,
    oTax :: Decimal
  }
  deriving (Show, Eq, Generic)

instance ToJSON Order

-- | GoodsPrice types
data GoodsPrice = GoodsPrice
  { gpId :: Int64,
    gpGoodsId :: Int64,
    gpPriceType :: Int,
    gpPrice :: Decimal,
    gpMinQtty :: Decimal,
    gpValidFrom :: Maybe Day,
    gpValidTo :: Maybe Day
  }
  deriving (Show, Eq, Generic)

instance ToJSON GoodsPrice

-- | Payment types
data Payment = Payment
  { payId :: Int64,
    payBillId :: Int64,
    payDate :: Day,
    payAmount :: Decimal,
    payMethod :: Int,
    payStatus :: Int
  }
  deriving (Show, Eq, Generic)

instance ToJSON Payment

-- | Payment input
data PaymentInput = PaymentInput
  { piBillId :: Int64,
    piPayDate :: Day,
    piAmount :: Double,
    piPayMethod :: Int,
    piPayStatus :: Int
  }
  deriving (Show, Eq, Generic)

instance FromJSON PaymentInput

-- | Salary types
data Salary = Salary
  { salId :: Int64,
    salEmployeeId :: Int64,
    salPeriod :: Day,
    salBaseSalary :: Decimal,
    salBonus :: Decimal,
    salPenalty :: Decimal,
    salTax :: Decimal,
    salNetSalary :: Decimal
  }
  deriving (Show, Eq, Generic)

instance ToJSON Salary

-- | Employee types (for payroll)
data Employee = Employee
  { empId :: Int64,
    empCode :: Text,
    empName :: Text,
    empEmail :: Maybe Text,
    empPosition :: Maybe Text,
    empStatus :: Int
  }
  deriving (Show, Eq, Generic)

instance ToJSON Employee

-- | ReportTemplate types
data ReportTemplate = ReportTemplate
  { rtId :: Int64,
    rtCode :: Text,
    rtName :: Text,
    rtReportType :: Int,
    rtJasperFile :: Text,
    rtOutputFormat :: Text
  }
  deriving (Show, Eq, Generic)

instance ToJSON ReportTemplate

-- | Job types
data Job = Job
  { jobId :: Int64,
    jobName :: Text,
    jobStatus :: Text,
    jobCreatedAt :: Day
  }
  deriving (Show, Eq, Generic)

instance ToJSON Job

-- | Tax types
data Tax = Tax
  { taxId :: Int64,
    taxCode :: Text,
    taxName :: Text,
    taxRate :: Decimal
  }
  deriving (Show, Eq, Generic)

instance ToJSON Tax

-- | Currency types
data Currency = Currency
  { currId :: Int64,
    currCode :: Text,
    currName :: Text,
    currSymbol :: Text,
    currRateToBase :: Decimal,
    currIsBase :: Bool
  }
  deriving (Show, Eq, Generic)

instance ToJSON Currency

-- | DashboardStats types
data DashboardStats = DashboardStats
  { dsRevenueToday :: Int,
    dsOrdersToday :: Int,
    dsGoodsCount :: Int,
    dsClientsCount :: Int
  }
  deriving (Show, Eq, Generic)

instance ToJSON DashboardStats

-- | Result type
data QueryResult a = QuerySuccess a | QueryError Text deriving (Show, Eq)

instance (ToJSON a) => ToJSON (QueryResult a) where
  toJSON (QuerySuccess a) = object ["success" .= True, "data" .= a]
  toJSON (QueryError e) = object ["success" .= False, "error" .= e]

-- | Pagination types
data Pagination = Pagination
  { pgLimit :: Int,
    pgOffset :: Int
  }
  deriving (Show, Eq, Generic)

instance FromJSON Pagination

defaultPagination :: Pagination
defaultPagination = Pagination 50 0

-- | Paginated result type
data PaginatedResult a = PaginatedResult
  { prItems :: [a],
    prTotal :: Int64,
    prLimit :: Int,
    prOffset :: Int
  }
  deriving (Show, Eq, Generic)

instance (ToJSON a) => ToJSON (PaginatedResult a) where
  toJSON (PaginatedResult items total limit offset) =
    object
      [ "items" .= items,
        "total" .= total,
        "limit" .= limit,
        "offset" .= offset
      ]

-- | Person filter
data PersonFilter = PersonFilter
  { pfName :: Maybe Text,
    pfINN :: Maybe Text,
    pfPersonType :: Maybe Int,
    pfStatus :: Maybe Int
  }
  deriving (Show, Eq, Generic)

instance FromJSON PersonFilter

defaultPersonFilter :: PersonFilter
defaultPersonFilter = PersonFilter Nothing Nothing Nothing Nothing

-- | Goods filter
data GoodsFilter = GoodsFilter
  { gfName :: Maybe Text,
    gfBarcode :: Maybe Text,
    gfCode :: Maybe Text
  }
  deriving (Show, Eq, Generic)

instance FromJSON GoodsFilter

defaultGoodsFilter :: GoodsFilter
defaultGoodsFilter = GoodsFilter Nothing Nothing Nothing

-- | Bill filter
data BillFilter = BillFilter
  { bfBillType :: Maybe Int,
    bfStatus :: Maybe Int,
    bfPersonId :: Maybe Int64,
    bfDateFrom :: Maybe Day,
    bfDateTo :: Maybe Day
  }
  deriving (Show, Eq, Generic)

instance FromJSON BillFilter

defaultBillFilter :: BillFilter
defaultBillFilter = BillFilter Nothing Nothing Nothing Nothing Nothing

-- | Order filter
data OrderFilter = OrderFilter
  { ofStatus :: Maybe Int,
    ofPersonId :: Maybe Int64,
    ofDateFrom :: Maybe Day,
    ofDateTo :: Maybe Day
  }
  deriving (Show, Eq, Generic)

instance FromJSON OrderFilter

defaultOrderFilter :: OrderFilter
defaultOrderFilter = OrderFilter Nothing Nothing Nothing Nothing

-- | Sort direction
data SortDir = Asc | Desc
  deriving (Show, Eq, Generic)

instance FromJSON SortDir

-- | Sort field for persons
data PersonSortBy = PersonSortById | PersonSortByName | PersonSortByINN
  deriving (Show, Eq, Generic)

instance FromJSON PersonSortBy

-- | Sort field for goods
data GoodsSortBy = GoodsSortById | GoodsSortByName | GoodsSortByCode
  deriving (Show, Eq, Generic)

instance FromJSON GoodsSortBy

-- | Sort field for bills
data BillSortBy = BillSortById | BillSortByDate | BillSortByTotal
  deriving (Show, Eq, Generic)

instance FromJSON BillSortBy

-- | Sort field for orders
data OrderSortBy = OrderSortById | OrderSortByDate | OrderSortByTotal
  deriving (Show, Eq, Generic)

instance FromJSON OrderSortBy

-- | Mutation result type
data MutationResult = MutationResult
  { mrSuccess :: Bool,
    mrId :: Maybe Int64,
    mrMessage :: Text
  }
  deriving (Show, Eq, Generic)

instance ToJSON MutationResult

-- | Bill input for creation
data BillInput = BillInput
  { biCode :: Maybe Text,
    biType :: Int,
    biStatus :: Int,
    biDate :: Day,
    biPersonId :: Maybe Int64,
    biLocationId :: Maybe Int64,
    biTotal :: Decimal,
    biDiscount :: Decimal,
    biTax :: Decimal
  }
  deriving (Show, Eq, Generic)

instance FromJSON BillInput

-- | Order input for creation
data OrderInput = OrderInput
  { oiCode :: Maybe Text,
    oiName :: Maybe Text,
    oiDate :: Day,
    oiPersonId :: Maybe Int64,
    oiLocationId :: Maybe Int64,
    oiStatus :: Int,
    oiTotal :: Decimal,
    oiDiscount :: Decimal,
    oiTax :: Decimal
  }
  deriving (Show, Eq, Generic)

instance FromJSON OrderInput

-- | Bill line input
data BillLineInput = BillLineInput
  { bliGoodsId :: Int64,
    bliQtty :: Decimal,
    bliPrice :: Decimal,
    bliDiscount :: Decimal,
    bliAmount :: Decimal
  }
  deriving (Show, Eq, Generic)

instance FromJSON BillLineInput

-- | Price input
data PriceInput = PriceInput
  { priGoodsId :: Int64,
    priPriceType :: Int,
    priPrice :: Decimal,
    priCurrencyId :: Int64,
    priFromDate :: Day,
    priToDate :: Maybe Day
  }
  deriving (Show, Eq, Generic)

instance FromJSON PriceInput

-- | Tax input
data TaxInput = TaxInput
  { tiName :: Text,
    tiRate :: Double,
    tiTaxType :: Int,
    tiIncluded :: Bool
  }
  deriving (Show, Eq, Generic)

instance FromJSON TaxInput

-- | Currency input
data CurrencyInput = CurrencyInput
  { ciCode :: Text,
    ciName :: Text,
    ciSymbol :: Text,
    ciRate :: Double
  }
  deriving (Show, Eq, Generic)

instance FromJSON CurrencyInput

-- | Accounting plan input
data AccPlanInput = AccPlanInput
  { apiCode :: Text,
    apiName :: Text,
    apiType :: Int,
    apiParentCode :: Maybe Text,
    apiKind :: Int,
    apiIsAnalytical :: Bool
  }
  deriving (Show, Eq, Generic)

instance FromJSON AccPlanInput

-- | Accounting turn input
data AccTurnInput = AccTurnInput
  { atiDbtAccId :: Int64,
    atiCrdAccId :: Int64,
    atiAmount :: Double,
    atiDate :: Day,
    atiBillId :: Maybe Int64
  }
  deriving (Show, Eq, Generic)

instance FromJSON AccTurnInput

-- ============================================================================
-- RBAC TYPES
-- ============================================================================

data EntityType = EntityPersons | EntityGoods | EntityBills | EntityOrders | EntityPrices | EntityReports | EntityAccounting | EntityPayroll
  deriving (Show, Eq, Generic)

instance ToJSON EntityType

data Permission
  = PermRead EntityType
  | PermWrite EntityType
  | PermExecute EntityType
  | PermAdmin
  deriving (Show, Eq, Generic)

instance ToJSON Permission

data Role = Role
  { rId :: Int64,
    rName :: Text,
    rPermissions :: [Permission]
  }
  deriving (Show, Eq, Generic)

instance ToJSON Role

data UserWithRole = UserWithRole
  { uwrUserId :: Int64,
    uwrLogin :: Text,
    uwrName :: Maybe Text,
    uwrRole :: Role
  }
  deriving (Show, Eq, Generic)

instance ToJSON UserWithRole

-- ============================================================================
-- AUDIT LOG TYPES
-- ============================================================================

data AuditAction
  = AuditCreate
  | AuditUpdate
  | AuditDelete
  | AuditLogin
  | AuditLogout
  | AuditAccess
  deriving (Show, Eq, Generic)

instance ToJSON AuditAction

data AuditLog = AuditLog
  { alId :: Int64,
    alUserId :: Maybe Int64,
    alAction :: AuditAction,
    alEntity :: Text,
    alEntityId :: Maybe Int64,
    alDetails :: Maybe Text,
    alTimestamp :: UTCTime,
    alIP :: Maybe Text
  }
  deriving (Show, Eq, Generic)

instance ToJSON AuditLog

-- ============================================================================
-- MISSING INPUT TYPES
-- ============================================================================

-- | Employee input for creation/update
data EmployeeInput = EmployeeInput
  { eiCode :: Maybe Text,
    eiName :: Text,
    eiEmail :: Maybe Text,
    eiPosition :: Maybe Text,
    eiStatus :: Int
  }
  deriving (Show, Eq, Generic)

instance FromJSON EmployeeInput

-- | Report template input
data ReportTemplateInput = ReportTemplateInput
  { rtiCode :: Text,
    rtiName :: Text,
    rtiReportType :: Int,
    rtiJasperFile :: Text,
    rtiOutputFormat :: Text
  }
  deriving (Show, Eq, Generic)

instance FromJSON ReportTemplateInput

-- | Order line input
data OrderLineInput = OrderLineInput
  { oliGoodsId :: Int64,
    oliQtty :: Double,
    oliPrice :: Double,
    oliDiscount :: Double,
    oliAmount :: Double
  }
  deriving (Show, Eq, Generic)

instance FromJSON OrderLineInput

-- | Stock adjustment input
data StockAdjustInput = StockAdjustInput
  { saiGoodsId :: Int64,
    saiLocationId :: Int64,
    saiQtty :: Double,
    saiReason :: Maybe Text
  }
  deriving (Show, Eq, Generic)

instance FromJSON StockAdjustInput

-- | Job input for creation
data JobInput = JobInput
  { jiName :: Text,
    jiStatus :: Text
  }
  deriving (Show, Eq, Generic)

instance FromJSON JobInput
