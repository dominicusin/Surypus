{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DeriveFunctor #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE DerivingStrategies #-}
-- | DAL.Types module
module DAL.Types (
    DashboardStats   (..),
    QueryResult   (..),
    MutationResult   (..),
    Bill   (..),
    BillInput   (..),
    BillLine   (..),
    BillLineInput   (..),
    Goods   (..),
    GoodsInput   (..),
    Person   (..),
    PersonInput   (..),
    Payment   (..),
    PaymentInput   (..),
    UserInput   (..),
    Location   (..),
    LocationInput   (..),
    Stock   (..),
    User   (..),
    AccPlan   (..),
    AccPlanInput   (..),
    AccTurn   (..),
    AccTurnInput   (..),
    Salary   (..),
    Employee   (..),
    ReportTemplate   (..),
    Order   (..),
    OrderInput   (..),
    GoodsPrice   (..),
    PriceInput   (..),
    Unit   (..),
    Tax   (..),
    TaxInput   (..),
    Currency   (..),
    CurrencyInput   (..),
    TechCard   (..),
    WorkOrder   (..),
    -- Sort and filter types
    PersonSortBy   (..),
    GoodsSortBy   (..),
    BillSortBy   (..),
    OrderSortBy   (..),
    SortDir   (..),
    PersonFilter   (..),
    GoodsFilter   (..),
    BillFilter   (..),
    OrderFilter   (..),
    DocumentRegisterType   (..),
    Pagination   (..),
    PaginatedResult   (..),
    Workflow   (..),
    WorkflowInstance   (..),
    WorkflowStatus   (..),
    WorkflowInput   (..),
    -- Classifiers
    OksmRecord   (..),
    OkvRecord   (..),
    OkeiRecord   (..),
    Okpd2Record   (..),
    Okved2Record   (..),
    TnvedRecord   (..),
    OkatoRecord   (..),
    OktmoRecord   (..),
    OkofRecord   (..),
    OkpRecord   (..),
    OkdpRecord   (..),
    OksoRecord   (..),
    OkunRecord   (..),
    OkudRecord   (..),
    OkfsRecord   (..),
    OknpoRecord   (..)
) where

import Data.Aeson (FromJSON, ToJSON)
import GHC.Generics (Generic)
import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (Day, UTCTime)

-- | Dashboard statistics
data DashboardStats = DashboardStats
  { dsBills :: Int,
    dsOrders :: Int,
    dsGoods :: Int,
    dsPersons :: Int
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON DashboardStats
instance FromJSON DashboardStats

-- | Query result type
data QueryResult a
  = QuerySuccess a
  | QueryError Text
  deriving stock (Show, Eq, Generic, Functor)

instance ToJSON a => ToJSON (QueryResult a)
instance FromJSON a => FromJSON (QueryResult a)

-- | Bill type (simplified for API)
data Bill = Bill
  { billId :: !Int64,
    billCode :: !(Maybe Text),
    billType :: !Int,
    billStatus :: !Int,
    billDate :: !Day,
    billPersonId :: !(Maybe Int64),
    billLocationId :: !(Maybe Int64),
    billTotal :: !Double,
    billDiscount :: !Double,
    billTaxAmount :: !Double
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON Bill
instance FromJSON Bill

-- | Bill input type (for API requests)
data BillInput = BillInput
  { biCode :: !(Maybe Text),
    biType :: !Int,
    biStatus :: !Int,
    biDate :: !Day,
    biPersonId :: !(Maybe Int64),
    biLocationId :: !(Maybe Int64),
    biTotal :: !Double,
    biDiscount :: !Double,
    biTax :: !Double
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON BillInput
instance FromJSON BillInput

-- | Bill line type
data BillLine = BillLine
  { lineId :: !Int64,
    lineBillId :: !Int64,
    lineGoodId :: !Int64,
    lineQtty :: !Double,
    linePrice :: !Double,
    lineDiscount :: !Double,
    lineAmount :: !Double
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON BillLine
instance FromJSON BillLine

-- | Bill line input type for API requests
data BillLineInput = BillLineInput
  { bliGoodsId :: !Int64,
    bliQtty :: !Double,
    bliPrice :: !Double,
    bliDiscount :: !Double,
    bliAmount :: !Double
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON BillLineInput
instance FromJSON BillLineInput

-- | Goods type (simplified for API)
data Goods = Goods
  { goodsId :: !Int64,
    goodsCode :: !(Maybe Text),
    goodsName :: !Text,
    goodsFullName :: !(Maybe Text),
    goodsBarcode :: !(Maybe Text),
    goodsUnitId :: !(Maybe Int64),
    goodsCategoryId :: !(Maybe Int64),
    goodsType :: !(Maybe Int),
    goodsStatus :: !(Maybe Int),
    goodsMinStock :: !(Maybe Double),
    goodsMaxStock :: !(Maybe Double),
    goodsWeight :: !(Maybe Double),
    goodsVolume :: !(Maybe Double),
    goodsCreatedAt :: !(Maybe UTCTime),
    goodsUpdatedAt :: !(Maybe UTCTime)
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON Goods
instance FromJSON Goods

-- | Goods input type
data GoodsInput = GoodsInput
  { giCode :: !(Maybe Text),
    giName :: !Text,
    giBarcode :: !(Maybe Text),
    giUnitId :: !Int64,
    giParentId :: !(Maybe Int64)
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON GoodsInput
instance FromJSON GoodsInput

-- | Person type (simplified for API)
data Person = Person
  { personId :: !Int64,
    personCode :: !(Maybe Text),
    personName :: !Text,
    personINN :: !(Maybe Text),
    personKPP :: !(Maybe Text),
    personType :: !Int,
    personStatus :: !(Maybe Int)
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON Person
instance FromJSON Person

-- | Person input type
data PersonInput = PersonInput
  { piCode :: !(Maybe Text),
    piName :: !Text,
    piINN :: !(Maybe Text),
    piKPP :: !(Maybe Text),
    piPersonType :: !Int,
    piStatus :: !Int
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON PersonInput
instance FromJSON PersonInput

-- | Payment type (simplified for API)
data Payment = Payment
  { paymentId :: !Int64,
    paymentPersonId :: !Int64,
    paymentAmount :: !Double,
    paymentDate :: !Day
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON Payment
instance FromJSON Payment

-- | Payment input type
data PaymentInput = PaymentInput
  { piBillId :: !Int64,
    piPayDate :: !Day,
    piAmount :: !Double,
    piPayMethod :: !Int,
    piPayStatus :: !Int
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON PaymentInput
instance FromJSON PaymentInput

-- | Location type
data Location = Location
  { locationId :: !Int64,
    locationCode :: !(Maybe Text),
    locationName :: !Text,
    locationType :: !Int
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON Location
instance FromJSON Location

-- | Stock type
data Stock = Stock
  { stockId :: !Int64,
    stockGoodsId :: !Int64,
    stockLocationId :: !Int64,
    stockQtty :: !Double,
    stockResrvQtty :: !Double
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON Stock
instance FromJSON Stock

-- | User type
data User = User
  { userId :: !Int64,
    userName :: !Text,
    userPassword :: !(Maybe Text),
    userEmail :: !(Maybe Text),
    userPersonId :: !(Maybe Int64),
    userStatus :: !Int,
    userTenantId :: !Int64
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON User
instance FromJSON User

-- | User input type for API requests
data UserInput = UserInput
  { uiLogin :: !Text,
    uiPasswordHash :: !Text,
    uiPersonId :: !(Maybe Int64),
    uiStatus :: !Int
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON UserInput
instance FromJSON UserInput

-- | Mutation result type
data MutationResult = MutationResult
  { mrSuccess :: Bool,
    mrId :: Maybe Int64,
    mrMessage :: Text
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON MutationResult
instance FromJSON MutationResult

-- | Location input type
data LocationInput = LocationInput
  { liCode :: !(Maybe Text),
    liName :: !Text,
    liType :: !Int
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON LocationInput
instance FromJSON LocationInput

-- | AccPlan input type
data AccPlanInput = AccPlanInput
  { apiCode :: !Text,
    apiName :: !Text,
    apiType :: !Int,
    apiParentCode :: !(Maybe Text),
    apiKind :: !Int,
    apiIsAnalytical :: !Bool
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON AccPlanInput
instance FromJSON AccPlanInput

-- | AccTurn input type
data AccTurnInput = AccTurnInput
  { atiDbtAccId :: !Int64,
    atiCrdAccId :: !Int64,
    atiAmount :: !Double,
    atiDate :: !Day,
    atiBillId :: !(Maybe Int64)
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON AccTurnInput
instance FromJSON AccTurnInput

-- | AccPlan type
data AccPlan = AccPlan
  { accPlanId :: !Int64,
    accPlanCode :: !Text,
    accPlanName :: !Text,
    accPlanType :: !Int
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON AccPlan
instance FromJSON AccPlan

-- | AccTurn type
data AccTurn = AccTurn
  { accTurnId :: !Int64,
    accTurnDocId :: !(Maybe Int64),
    accTurnAccId :: !Int64,
    accTurnCorrId :: !Int64,
    accTurnAmount :: !Double,
    accTurnDate :: !Day
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON AccTurn
instance FromJSON AccTurn

-- | Salary type
data Salary = Salary
  { salaryId :: !Int64,
    salaryEmpId :: !Int64,
    salaryDate :: !Day,
    salaryGross :: !Double,
    salaryNet :: !Double,
    salaryTax :: !Double,
    salaryPension :: !Double,
    salaryOther :: !Double
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON Salary
instance FromJSON Salary

-- | Employee type
data Employee = Employee
  { employeeId :: !Int64,
    employeeName :: !Text,
    employeeCode :: !Text,
    employeeTabNum :: !(Maybe Text),
    employeeHireDate :: !(Maybe Day),
    employeeStatus :: !Int
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON Employee
instance FromJSON Employee

-- | ReportTemplate type
data ReportTemplate = ReportTemplate
  { reportTemplateId :: !Int64,
    reportTemplateName :: !Text,
    reportTemplateCode :: !Text,
    reportTemplateType :: !Int,
    reportTemplateContent :: !Text,
    reportTemplateFormat :: !Text
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON ReportTemplate
instance FromJSON ReportTemplate

-- | Order type
data Order = Order
  { orderId :: !Int64,
    orderCode :: !(Maybe Text),
    orderName :: !(Maybe Text),
    orderDate :: !Day,
    orderPersonId :: !(Maybe Int64),
    orderLocationId :: !(Maybe Int64),
    orderType :: !Int,
    orderTotal :: !Double,
    orderDiscount :: !Double,
    orderTax :: !Double
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON Order
instance FromJSON Order

-- | Order input type
data OrderInput = OrderInput
  { oiCode :: !(Maybe Text),
    oiName :: !(Maybe Text),
    oiDate :: !Day,
    oiPersonId :: !(Maybe Int64),
    oiLocationId :: !(Maybe Int64),
    oiStatus :: !Int,
    oiTotal :: !Double,
    oiDiscount :: !Double,
    oiTax :: !Double
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON OrderInput
instance FromJSON OrderInput

-- | GoodsPrice type
data GoodsPrice = GoodsPrice
  { goodsPriceId :: !Int64,
    goodsPriceGoodsId :: !Int64,
    goodsPriceType :: !Int,
    goodsPricePrice :: !Double,
    goodsPriceMinPrice :: !Double,
    goodsPriceStartDate :: !(Maybe Day),
    goodsPriceEndDate :: !(Maybe Day)
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON GoodsPrice
instance FromJSON GoodsPrice

-- | Price input type
data PriceInput = PriceInput
  { priGoodsId :: !Int64,
    priPriceType :: !Int,
    priPrice :: !Double,
    priCurrencyId :: !Int64,
    priFromDate :: !Day,
    priToDate :: !(Maybe Day)
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON PriceInput
instance FromJSON PriceInput

-- | Unit type
data Unit = Unit
  { unitId :: !Int64,
    unitCode :: !Text,
    unitName :: !Text,
    unitSymbol :: !(Maybe Text)
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON Unit
instance FromJSON Unit

-- | Tax type
data Tax = Tax
  { taxId :: !Int64,
    taxCode :: !Text,
    taxName :: !Text,
    taxRate :: !Double
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON Tax
instance FromJSON Tax

-- | Tax input type
data TaxInput = TaxInput
  { tiName :: !Text,
    tiRate :: !Double,
    tiTaxType :: !Int,
    tiIncluded :: !Bool
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON TaxInput
instance FromJSON TaxInput

-- | Currency type
data Currency = Currency
  { currencyId :: !Int64,
    currencyCode :: !(Maybe Text),
    currencySymbol :: !(Maybe Text),
    currencyName :: !(Maybe Text),
    currencyRate :: !Double,
    currencyDefault :: !Bool
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON Currency
instance FromJSON Currency

-- | Currency input type
data CurrencyInput = CurrencyInput
  { ciCode :: !Text,
    ciSymbol :: !Text,
    ciName :: !Text,
    ciRate :: !Double,
    ciDefault :: !Bool
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON CurrencyInput
instance FromJSON CurrencyInput

-- | TechCard type
data TechCard = TechCard
  { techCardId :: !(Maybe Int64),
    tgGoodsId :: !Int64,
    tgName :: !Text,
    tgVersion :: !Text,
    tgStatus :: !Int,
    techCardCreatedAt :: !UTCTime,
    techCardUpdatedAt :: !UTCTime,
    techCardNote :: !(Maybe Text)
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON TechCard
instance FromJSON TechCard

-- | WorkOrder type
data WorkOrder = WorkOrder
  { workOrderId :: !(Maybe Int64),
    workOrderCode :: !Text,
    workOrderGoodsId :: !Int64,
    workOrderParentId :: !(Maybe Int64),
    workOrderPlannedQtty :: !Double,
    workOrderFactQtty :: !Double,
    workOrderStatus :: !Int,
    workOrderStartDate :: !(Maybe Day),
    workOrderEndDate :: !(Maybe Day),
    workOrderAssignedTo :: !(Maybe Int64),
    workOrderNote :: !(Maybe Text),
    workOrderCreatedAt :: !UTCTime,
    workOrderUpdatedAt :: !UTCTime,
    workOrderClosedAt :: !(Maybe Text)
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON WorkOrder
instance FromJSON WorkOrder

-- | Sort by options for Person
data PersonSortBy = PersonSortByName | PersonSortByINN
  deriving stock (Show, Eq, Generic)

instance ToJSON PersonSortBy
instance FromJSON PersonSortBy

-- | Sort by options for Goods
data GoodsSortBy = GoodsSortByName | GoodsSortByCode
  deriving stock (Show, Eq, Generic)

instance ToJSON GoodsSortBy
instance FromJSON GoodsSortBy

-- | Sort by options for Bill
data BillSortBy = BillSortByDate | BillSortByTotal
  deriving stock (Show, Eq, Generic)

instance ToJSON BillSortBy
instance FromJSON BillSortBy

-- | Sort direction
data SortDir = Asc | Desc
  deriving stock (Show, Eq, Generic)

instance ToJSON SortDir
instance FromJSON SortDir

-- | Person filter options
data PersonFilter = PersonFilter
  { pfName :: !(Maybe Text),
    pfINN :: !(Maybe Text),
    pfPersonType :: !(Maybe Int),
    pfStatus :: !(Maybe Int)
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON PersonFilter
instance FromJSON PersonFilter

-- | Document register type
data DocumentRegisterType = DocumentRegisterType
  { drtId :: !Int64,
    drtCode :: !Text,
    drtName :: !Text,
    drtDescription :: !(Maybe Text)
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON DocumentRegisterType
instance FromJSON DocumentRegisterType

-- | Goods filter options
data GoodsFilter = GoodsFilter
  { gfName :: !(Maybe Text),
    gfCode :: !(Maybe Text),
    gfBarcode :: !(Maybe Text),
    gfCategoryId :: !(Maybe Int64),
    gfStatus :: !(Maybe Int)
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON GoodsFilter
instance FromJSON GoodsFilter

-- | Bill filter options
data BillFilter = BillFilter
  { bfCode :: !(Maybe Text),
    bfBillType :: !(Maybe Int),
    bfStatus :: !(Maybe Int),
    bfPersonId :: !(Maybe Int64),
    bfLocationId :: !(Maybe Int64),
    bfDateFrom :: !(Maybe Day),
    bfDateTo :: !(Maybe Day)
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON BillFilter
instance FromJSON BillFilter

-- | Order filter options
data OrderFilter = OrderFilter
  { ofCode :: !(Maybe Text),
    ofType :: !(Maybe Int),
    ofStatus :: !(Maybe Int),
    ofPersonId :: !(Maybe Int64),
    ofDateFrom :: !(Maybe Day),
    ofDateTo :: !(Maybe Day)
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON OrderFilter
instance FromJSON OrderFilter

-- | Sort by options for Order
data OrderSortBy = OrderSortByDate | OrderSortByTotal
  deriving stock (Show, Eq, Generic)

instance ToJSON OrderSortBy
instance FromJSON OrderSortBy

-- | Pagination parameters
data Pagination = Pagination
  { pgLimit :: !Int,
    pgOffset :: !Int
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON Pagination
instance FromJSON Pagination

-- | Paginated result wrapper
data PaginatedResult a = PaginatedResult
  { prItems :: ![a],
    prTotal :: !Int,
    prLimit :: !Int,
    prOffset :: !Int
  }
  deriving stock (Show, Eq, Generic, Functor)

instance ToJSON a => ToJSON (PaginatedResult a)
instance FromJSON a => FromJSON (PaginatedResult a)

-- | Workflow type
data Workflow = Workflow
  { wfId :: !Int64,
    wfCode :: !Text,
    wfName :: !(Maybe Text),
    wfDescription :: !Text,
    wfEnabled :: !Bool,
    wfDefinition :: !Text
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON Workflow
instance FromJSON Workflow

-- | Workflow instance type
data WorkflowInstance = WorkflowInstance
  { wiId :: !Int64,
    wiWorkflowId :: !Int64,
    wiStatus :: !WorkflowStatus,
    wiCurrentStep :: !(Maybe Text),
    wiInput :: !(Maybe WorkflowInput),
    wiStartedAt :: !(Maybe UTCTime),
    wiCompletedAt :: !(Maybe UTCTime)
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON WorkflowInstance
instance FromJSON WorkflowInstance

-- | Workflow status
data WorkflowStatus = WorkflowPending | WorkflowRunning | WorkflowCompleted | WorkflowFailed
  deriving stock (Show, Eq, Generic)

instance ToJSON WorkflowStatus
instance FromJSON WorkflowStatus

-- | Workflow input
data WorkflowInput = WorkflowInput
  { wiInputData :: !(Maybe Text),
    wiUserId :: !(Maybe Int64),
    wiContext :: !(Maybe Text)
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON WorkflowInput
instance FromJSON WorkflowInput

-- ============================================================
-- All-Russian Classifiers (Общероссийские классификаторы)
-- ============================================================

-- | OKSM - Countries of the world
data OksmRecord = OksmRecord
  { oksmId :: !Int64,
    oksmCode :: !Text,
    oksmName :: !Text,
    oksmFullName :: !(Maybe Text),
    oksmAlpha2 :: !(Maybe Text),
    oksmAlpha3 :: !(Maybe Text)
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON OksmRecord
instance FromJSON OksmRecord

-- | OKV - Currencies
data OkvRecord = OkvRecord
  { okvId :: !Int64,
    okvCode :: !Text,
    okvLetterCode :: !(Maybe Text),
    okvName :: !Text,
    okvCountries :: !(Maybe Text)
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON OkvRecord
instance FromJSON OkvRecord

-- | OKEI - Units of measurement
data OkeiRecord = OkeiRecord
  { okeiId :: !Int64,
    okeiCode :: !Text,
    okeiName :: !Text,
    okeiNationalSymbol :: !(Maybe Text),
    okeiInternationalSymbol :: !(Maybe Text),
    okeiNationalLetterCode :: !(Maybe Text),
    okeiInternationalLetterCode :: !(Maybe Text),
    okeiSection :: !(Maybe Text)
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON OkeiRecord
instance FromJSON OkeiRecord

-- | OKPD2 - Product classification by economic activity
data Okpd2Record = Okpd2Record
  { okpd2Id :: !Int64,
    okpd2Code :: !Text,
    okpd2Name :: !Text,
    okpd2ParentCode :: !(Maybe Text)
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON Okpd2Record
instance FromJSON Okpd2Record

-- | OKVED2 - Types of economic activity
data Okved2Record = Okved2Record
  { okved2Id :: !Int64,
    okved2Code :: !Text,
    okved2Name :: !Text,
    okved2ParentCode :: !(Maybe Text)
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON Okved2Record
instance FromJSON Okved2Record

-- | TNVED - Foreign trade nomenclature
data TnvedRecord = TnvedRecord
  { tnvedId :: !Int64,
    tnvedCode :: !Text,
    tnvedName :: !Text,
    tnvedParentCode :: !(Maybe Text),
    tnvedSectionNum :: !(Maybe Text),
    tnvedGroupNum :: !(Maybe Text)
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON TnvedRecord
instance FromJSON TnvedRecord

-- | OKATO - Administrative-Territorial Division
data OkatoRecord = OkatoRecord
  { okatoId :: !Int64,
    okatoCode :: !Text,
    okatoName :: !Text,
    okatoParentCode :: !(Maybe Text),
    okatoLevel :: !Int
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON OkatoRecord
instance FromJSON OkatoRecord

-- | OKTMO - Municipal Territories
data OktmoRecord = OktmoRecord
  { oktmoId :: !Int64,
    oktmoCode :: !Text,
    oktmoName :: !Text,
    oktmoParentCode :: !(Maybe Text)
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON OktmoRecord
instance FromJSON OktmoRecord

-- | OKOF - Fixed Assets
data OkofRecord = OkofRecord
  { okofId :: !Int64,
    okofCode :: !Text,
    okofName :: !Text,
    okofParentCode :: !(Maybe Text)
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON OkofRecord
instance FromJSON OkofRecord

-- | OKP - Products
data OkpRecord = OkpRecord
  { okpId :: !Int64,
    okpCode :: !Text,
    okpName :: !Text,
    okpParentCode :: !(Maybe Text)
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON OkpRecord
instance FromJSON OkpRecord

-- | OKDP - Economic Activities
data OkdpRecord = OkdpRecord
  { okdpId :: !Int64,
    okdpCode :: !Text,
    okdpName :: !Text,
    okdpParentCode :: !(Maybe Text)
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON OkdpRecord
instance FromJSON OkdpRecord

-- | OKSO - Occupations
data OksoRecord = OksoRecord
  { oksoId :: !Int64,
    oksoCode :: !Text,
    oksoName :: !Text
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON OksoRecord
instance FromJSON OksoRecord

-- | OKUN - Services
data OkunRecord = OkunRecord
  { okunId :: !Int64,
    okunCode :: !Text,
    okunName :: !Text,
    okunParentCode :: !(Maybe Text)
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON OkunRecord
instance FromJSON OkunRecord

-- | OKUD - Management Documentation
data OkudRecord = OkudRecord
  { okudId :: !Int64,
    okudCode :: !Text,
    okudName :: !Text
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON OkudRecord
instance FromJSON OkudRecord

-- | OKFS - Forms of Ownership
data OkfsRecord = OkfsRecord
  { okfsId :: !Int64,
    okfsCode :: !Text,
    okfsName :: !Text
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON OkfsRecord
instance FromJSON OkfsRecord

-- | OKNPO - Primary Professional Education
data OknpoRecord = OknpoRecord
  { oknpoId :: !Int64,
    oknpoCode :: !Text,
    oknpoName :: !Text
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON OknpoRecord
instance FromJSON OknpoRecord