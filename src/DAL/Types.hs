{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DeriveFunctor #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE DerivingStrategies #-}
-- | DAL.Types module
module DAL.Types (
    DashboardStats (..),
    QueryResult (..),
    MutationResult (..),
    Bill (..),
    BillInput (..),
    BillLine (..),
    Goods (..),
    GoodsInput (..),
    Person (..),
    PersonInput (..),
    Payment (..),
    PaymentInput (..),
    Location (..),
    LocationInput (..),
    Stock (..),
    User (..),
    AccPlan (..),
    AccPlanInput (..),
    AccTurn (..),
    AccTurnInput (..),
    Salary (..),
    Employee (..),
    ReportTemplate (..),
    Order (..),
    OrderInput (..),
    GoodsPrice (..),
    PriceInput (..),
    Unit (..),
    Tax (..),
    TaxInput (..),
    Currency (..),
    CurrencyInput (..),
    TechCard (..),
    WorkOrder (..)
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
  { payInputPersonId :: !Int64,
    payInputAmount :: !Double,
    payInputDate :: !Day
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
    userStatus :: !Int
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON User
instance FromJSON User

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

-- | TechCard type
data TechCard = TechCard
  { techCardId :: !(Maybe Int64),
    techCardGoodsId :: !Int64,
    techCardName :: !Text,
    techCardCode :: !Text,
    techCardStatus :: !Int,
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