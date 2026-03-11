{-# LANGUAGE FunctionalDependencies #-}
{-# LANGUAGE MultiParamTypeClasses  #-}
-- ============================================================================
-- SURYPUS HASKELL TYPES - Object-Oriented Domain Model
-- ============================================================================
-- Reflects PostgreSQL schema-as-classes design
-- Uses type classes for polymorphism
-- ============================================================================
{-# LANGUAGE TypeFamilies           #-}

module Surypus.Types where

import           Data.Int  (Int64)
import           Data.Text (Text)
import           Data.Time (Day, UTCTime)
import           Data.UUID (UUID)

-- ============================================================================
-- BASE OBJECT SYSTEM
-- ============================================================================

-- | BaseObject - абстрактный базовый класс для всех сущностей
class BaseObject a where
  getId :: a -> Int64
  getUuid :: a -> UUID
  getCode :: a -> Maybe Text
  getName :: a -> Text
  getStatus :: a -> Int
  getFlags :: a -> Int

-- | ObjectType - типы объектов системы
data ObjectType
  = OT_Goods
  | OT_Person
  | OT_Employee
  | OT_Document
  | OT_Bill
  | OT_Order
  | OT_Location
  | OT_Account
  | OT_Tax
  | OT_Currency
  | OT_Report
  deriving (Show, Eq)

-- | BaseEntity - базовая сущность с идентификатором
data BaseEntity = BaseEntity
  { beId        :: Int64,
    beUuid      :: UUID,
    beCode      :: Maybe Text,
    beName      :: Text,
    beObjType   :: ObjectType,
    beFlags     :: Int,
    beStatus    :: Int,
    beCreatedAt :: UTCTime,
    beUpdatedAt :: UTCTime
  }
  deriving (Show, Eq)

instance BaseObject BaseEntity where
  getId = beId
  getUuid = beUuid
  getCode = beCode
  getName = beName
  getStatus = beStatus
  getFlags = beFlags

-- ============================================================================
-- SECURITY & ACCESS CONTROL
-- ============================================================================

-- | Right - право доступа к ресурсу
data Right = Right
  { rightId       :: Int64,
    rightResource :: Text, -- ресурс (таблица/схема)
    rightAction   :: Text, -- действие (select, insert, update, delete)
    rightGranted  :: Bool
  }
  deriving (Show, Eq)

-- | Role - роль пользователя
data Role = Role
  { roleId          :: Int64,
    roleName        :: Text,
    roleDescription :: Text,
    rolePermissions :: [(Text, Text)] -- (resource, action)
  }
  deriving (Show, Eq)

-- | User - пользователь системы
data User = User
  { userId        :: Int64,
    userLogin     :: Text,
    userPersonId  :: Maybe Int64,
    userName      :: Text,
    userEmail     :: Maybe Text,
    userRoleIds   :: [Int64],
    userStatus    :: Int,
    userLastLogin :: Maybe UTCTime
  }
  deriving (Show, Eq)

instance BaseObject User where
  getId = userId
  getUuid = undefined -- User doesn't have UUID
  getCode = Just . userLogin
  getName = userName
  getStatus = userStatus
  getFlags = const 0

-- ============================================================================
-- PERSONS (Counteragents)
-- ============================================================================

-- | PersonType - тип контрагента
data PersonType = PT_Company | PT_Individual | PT_Entrepreneur
  deriving (Show, Eq)

-- | Person - контрагент
data Person = Person
  { personId          :: Int64,
    personCode        :: Maybe Text,
    personName        :: Text,
    personINN         :: Maybe Text,
    personKPP         :: Maybe Text,
    personOKPO        :: Maybe Text,
    personType        :: PersonType,
    personAddressId   :: Maybe Int64,
    personPhone       :: Maybe Text,
    personEmail       :: Maybe Text,
    personContact     :: Maybe Text,
    personCreditLimit :: Double,
    personDiscount    :: Double,
    personStatus      :: Int
  }
  deriving (Show, Eq)

instance BaseObject Person where
  getId = personId
  getUuid = undefined
  getCode = personCode
  getName = personName
  getStatus = personStatus
  getFlags = const 0

-- | Employee - сотрудник (наследует Person)
data Employee = Employee
  { empPerson     :: Person,
    empPositionId :: Int64,
    empHireDate   :: Day,
    empFireDate   :: Maybe Day,
    empSalary     :: Double,
    empDepartment :: Text
  }
  deriving (Show, Eq)

-- | Manager - менеджер (наследует Employee)
data Manager = Manager
  { mgrEmployee :: Employee,
    mgrTeamId   :: Int64,
    mgrQuota    :: Double
  }
  deriving (Show, Eq)

-- ============================================================================
-- GOODS (Products)
-- ============================================================================

-- | GoodsType - тип товара
data GoodsType = GT_Item | GT_Service | GT_Bundle
  deriving (Show, Eq)

-- | Goods - товар
data Goods = Goods
  { goodsId             :: Int64,
    goodsCode           :: Maybe Text,
    goodsName           :: Text,
    goodsBarcode        :: Maybe Text,
    goodsUnitId         :: Int64,
    goodsParentId       :: Maybe Int64,
    goodsType           :: GoodsType,
    goodsTaxId          :: Maybe Int64,
    goodsCountryId      :: Maybe Int64,
    goodsManufacturerId :: Maybe Int64,
    goodsWeight         :: Maybe Double,
    goodsVolume         :: Maybe Double,
    goodsMinStock       :: Double,
    goodsMaxStock       :: Maybe Double,
    goodsReorderPoint   :: Double
  }
  deriving (Show, Eq)

instance BaseObject Goods where
  getId = goodsId
  getUuid = undefined
  getCode = goodsCode
  getName = goodsName
  getStatus = const 0
  getFlags = const 0

-- | GoodsPrice - цена товара
data GoodsPrice = GoodsPrice
  { gpId         :: Int64,
    gpGoodsId    :: Int64,
    gpPriceType  :: PriceType,
    gpPrice      :: Double,
    gpCurrencyId :: Int64,
    gpMinQtty    :: Double,
    gpValidFrom  :: Maybe Day,
    gpValidTo    :: Maybe Day
  }
  deriving (Show, Eq)

data PriceType = PT_Retail | PT_Wholesale | PT_Cost
  deriving (Show, Eq)

-- | Service - услуга (наследует Goods)
data Service = Service
  { svcGoods        :: Goods,
    svcDurationMin  :: Int,
    svcWarrantyDays :: Int
  }
  deriving (Show, Eq)

-- | Bundle - комплект (наследует Goods)
data Bundle = Bundle
  { bndGoods :: Goods,
    bndItems :: [(Int64, Double)] -- (goods_id, qtty)
  }
  deriving (Show, Eq)

-- ============================================================================
-- WAREHOUSE & STOCK
-- ============================================================================

-- | LocationType - тип склада
data LocationType = LT_Warehouse | LT_Store | LT_Office
  deriving (Show, Eq)

-- | Location - место хранения
data Location = Location
  { locId        :: Int64,
    locCode      :: Maybe Text,
    locName      :: Text,
    locType      :: LocationType,
    locAddressId :: Maybe Int64,
    locCapacity  :: Maybe Double,
    locIsActive  :: Bool
  }
  deriving (Show, Eq)

instance BaseObject Location where
  getId = locId
  getUuid = undefined
  getCode = locCode
  getName = locName
  getStatus = const 0
  getFlags = const 0

-- | Stock - остаток товара
data Stock = Stock
  { stockId         :: Int64,
    stockGoodsId    :: Int64,
    stockLocationId :: Int64,
    stockQtty       :: Double,
    stockResrvQtty  :: Double,
    stockCost       :: Double,
    stockPrice      :: Double,
    stockBatch      :: Maybe Text,
    stockExpiryDate :: Maybe Day
  }
  deriving (Show, Eq)

-- | MovementType - тип движения
data MovementType = MT_Receipt | MT_Issue | MT_Transfer | MT_Adjustment
  deriving (Show, Eq)

-- | StockMovement - движение товара
data StockMovement = StockMovement
  { smId             :: Int64,
    smGoodsId        :: Int64,
    smLocationFromId :: Maybe Int64,
    smLocationToId   :: Maybe Int64,
    smQtty           :: Double,
    smType           :: MovementType,
    smBillId         :: Maybe Int64,
    smDate           :: Day,
    smUserId         :: Maybe Int64,
    smNotes          :: Maybe Text
  }
  deriving (Show, Eq)

-- ============================================================================
-- DOCUMENTS
-- ============================================================================

-- | DocumentStatus - статус документа
data DocumentStatus = DS_Draft | DS_Registered | DS_Posted | DS_Annulled
  deriving (Show, Eq, Enum)

-- | Document - базовый документ
data Document = Document
  { docId         :: Int64,
    docCode       :: Maybe Text,
    docName       :: Text,
    docDate       :: Day,
    docPersonId   :: Maybe Int64,
    docLocationId :: Maybe Int64,
    docTotal      :: Double,
    docTaxAmount  :: Double,
    docDiscount   :: Double,
    docCurrencyId :: Maybe Int64,
    docUserId     :: Maybe Int64,
    docStatus     :: DocumentStatus
  }
  deriving (Show, Eq)

instance BaseObject Document where
  getId = docId
  getUuid = undefined
  getCode = docCode
  getName = docName
  getStatus = fromEnum . docStatus
  getFlags = const 0

-- | BillType - тип документа
data BillType = BT_Sale | BT_Purchase | BT_Return
  deriving (Show, Eq)

-- | Bill - накладная/чек
data Bill = Bill
  { billDocument      :: Document,
    billType          :: BillType,
    billPaymentMethod :: Int,
    billTerminalId    :: Maybe Int64
  }
  deriving (Show, Eq)

-- | BillLine - строка документа
data BillLine = BillLine
  { blId              :: Int64,
    blBillId          :: Int64,
    blGoodsId         :: Int64,
    blQtty            :: Double,
    blPrice           :: Double,
    blDiscountPercent :: Double,
    blDiscountAmount  :: Double,
    blTaxRate         :: Double,
    blTaxAmount       :: Double,
    blAmount          :: Double
  }
  deriving (Show, Eq)

-- | Order - заказ
data Order = Order
  { ordDocument        :: Document,
    ordDeliveryAddress :: Maybe Text,
    ordDeliveryDate    :: Maybe Day,
    ordPriority        :: Int
  }
  deriving (Show, Eq)

-- ============================================================================
-- ACCOUNTING
-- ============================================================================

-- | AccountType - тип счета
data AccountType = AT_Asset | AT_Liability | AT_Equity | AT_Revenue | AT_Expense
  deriving (Show, Eq)

-- | Account - план счетов
data Account = Account
  { accId           :: Int64,
    accCode         :: Text,
    accName         :: Text,
    accType         :: AccountType,
    accParentCode   :: Maybe Text,
    accKind         :: Int,
    accIsAnalytical :: Bool
  }
  deriving (Show, Eq)

instance BaseObject Account where
  getId = accId
  getUuid = undefined
  getCode = Just . accCode
  getName = accName
  getStatus = const 0
  getFlags = const 0

-- | AccountingEntry - проводка
data AccountingEntry = AccountingEntry
  { aeId          :: Int64,
    aeBillId      :: Maybe Int64,
    aeDebitAccId  :: Int64,
    aeCreditAccId :: Int64,
    aeAmount      :: Double,
    aeCurrencyId  :: Maybe Int64,
    aeDate        :: Day,
    aeMemos       :: Maybe Text
  }
  deriving (Show, Eq)

-- | AccountBalance - остаток по счету
data AccountBalance = AccountBalance
  { abAccId        :: Int64,
    abDate         :: Day,
    abDebitAmount  :: Double,
    abCreditAmount :: Double
  }
  deriving (Show, Eq)

-- ============================================================================
-- HR & SALARY
-- ============================================================================

-- | Position - должность
data Position = Position
  { posId         :: Int64,
    posCode       :: Maybe Text,
    posName       :: Text,
    posSalaryFrom :: Double,
    posSalaryTo   :: Double,
    posDepartment :: Text
  }
  deriving (Show, Eq)

instance BaseObject Position where
  getId = posId
  getUuid = undefined
  getCode = posCode
  getName = posName
  getStatus = const 0
  getFlags = const 0

-- | Salary - зарплата
data Salary = Salary
  { salId         :: Int64,
    salEmployeeId :: Int64,
    salPeriod     :: Day,
    salBase       :: Double,
    salBonus      :: Double,
    salPenalty    :: Double,
    salTax        :: Double,
    salNet        :: Double,
    salPaidAt     :: Maybe UTCTime
  }
  deriving (Show, Eq)

-- ============================================================================
-- PAYMENTS
-- ============================================================================

-- | PaymentMethod - способ оплаты
data PaymentMethod = PM_Cash | PM_Card | PM_Transfer
  deriving (Show, Eq)

-- | PaymentStatus - статус платежа
data PaymentStatus = PS_Pending | PS_Completed | PS_Failed | PS_Refunded
  deriving (Show, Eq)

-- | Payment - платеж
data Payment = Payment
  { payId           :: Int64,
    payBillId       :: Maybe Int64,
    payDate         :: Day,
    payAmount       :: Double,
    payMethod       :: PaymentMethod,
    payStatus       :: PaymentStatus,
    payCurrencyId   :: Int64,
    payExchangeRate :: Double,
    payUserId       :: Maybe Int64
  }
  deriving (Show, Eq)

-- | Currency - валюта
data Currency = Currency
  { curId         :: Int64,
    curCode       :: Text,
    curName       :: Text,
    curSymbol     :: Text,
    curRateToBase :: Double,
    curIsBase     :: Bool
  }
  deriving (Show, Eq)

-- ============================================================================
-- TAXES
-- ============================================================================

-- | TaxType - тип налога
data TaxType = TT_VAT | TT_Excise | TT_Property
  deriving (Show, Eq)

-- | Tax - налог
data Tax = Tax
  { taxId         :: Int64,
    taxCode       :: Text,
    taxName       :: Text,
    taxRate       :: Double,
    taxType       :: TaxType,
    taxIsIncluded :: Bool,
    taxAccountId  :: Maybe Int64
  }
  deriving (Show, Eq)

instance BaseObject Tax where
  getId = taxId
  getUuid = undefined
  getCode = Just . taxCode
  getName = taxName
  getStatus = const 0
  getFlags = const 0

-- ============================================================================
-- REPORTS
-- ============================================================================

-- | ReportType - тип отчета
data ReportType = RT_Sales | RT_Inventory | RT_Financial | RT_Tax
  deriving (Show, Eq)

-- | ReportTemplate - шаблон отчета
data ReportTemplate = ReportTemplate
  { rtId           :: Int64,
    rtCode         :: Text,
    rtName         :: Text,
    rtType         :: ReportType,
    rtJasperFile   :: Maybe Text,
    rtParameters   :: [(Text, Text)],
    rtOutputFormat :: Text
  }
  deriving (Show, Eq)

-- | ReportStatus - статус генерации
data ReportStatus = RPS_Pending | RPS_Processing | RPS_Completed | RPS_Failed
  deriving (Show, Eq)

-- | ReportJob - задача отчета
data ReportJob = ReportJob
  { rjId          :: Int64,
    rjTemplateId  :: Int64,
    rjUserId      :: Int64,
    rjParameters  :: [(Text, Text)],
    rjStatus      :: ReportStatus,
    rjFilePath    :: Maybe Text,
    rjError       :: Maybe Text,
    rjCreatedAt   :: UTCTime,
    rjCompletedAt :: Maybe UTCTime
  }
  deriving (Show, Eq)

-- ============================================================================
-- AUDIT & LOGGING
-- ============================================================================

-- | LogLevel - уровень логирования
data LogLevel = LL_Debug | LL_Info | LL_Warning | LL_Error
  deriving (Show, Eq)

-- | AuditAction - тип действия
data AuditAction = AA_Create | AA_Update | AA_Delete | AA_View
  deriving (Show, Eq)

-- | AuditLog - запись аудита
data AuditLog = AuditLog
  { alId        :: Int64,
    alUserId    :: Maybe Int64,
    alAction    :: AuditAction,
    alTableName :: Text,
    alRecordId  :: Maybe Int64,
    alOldValues :: Maybe Text,
    alNewValues :: Maybe Text,
    alIPAddress :: Maybe Text,
    alTimestamp :: UTCTime
  }
  deriving (Show, Eq)

-- | SystemLog - системный лог
data SystemLog = SystemLog
  { slId        :: Int64,
    slLevel     :: LogLevel,
    slModule    :: Text,
    slMessage   :: Text,
    slDetails   :: Maybe Text,
    slUserId    :: Maybe Int64,
    slTimestamp :: UTCTime
  }
  deriving (Show, Eq)

-- ============================================================================
-- POLYMORPHIC OPERATIONS
-- ============================================================================

-- | Тип-класс для объектов с ценой
class HasPrice a where
  getPrice :: a -> Double
  setPrice :: a -> Double -> a

instance HasPrice Goods where
  getPrice g = goodsMinStock g -- placeholder
  setPrice g p = g {goodsMinStock = p}

instance HasPrice BillLine where
  getPrice = blPrice
  setPrice bl p = bl {blPrice = p}

-- | Тип-класс для объектов с количеством
class HasQuantity a where
  getQuantity :: a -> Double
  setQuantity :: a -> Double -> a

instance HasQuantity Stock where
  getQuantity = stockQtty
  setQuantity s q = s {stockQtty = q}

instance HasQuantity BillLine where
  getQuantity = blQtty
  setQuantity bl q = bl {blQtty = q}

-- | Тип-класс для объектов которые можно активировать/деактивировать
class Activatable a where
  activate :: a -> a
  deactivate :: a -> a
  isActive :: a -> Bool

instance Activatable Location where
  activate l = l {locIsActive = True}
  deactivate l = l {locIsActive = False}
  isActive = locIsActive

instance Activatable User where
  activate u = u {userStatus = 0}
  deactivate u = u {userStatus = 1}
  isActive u = userStatus u == 0
