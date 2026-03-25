-- ============================================================================
-- SURYPUS CORE - Unified Domain Model
-- ============================================================================
-- Radically refactored: Single module with all entities, type classes, instances
-- Replaces 155+ fragmented modules with coherent design
-- ============================================================================
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeFamilies #-}

module Surypus.Core where

import Data.Int (Int64)
import Data.Map (Map)
import qualified Data.Map as Map
import Data.Set (Set)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (Day, DiffTime, UTCTime)
import Data.UUID (UUID)
import GHC.Generics (Generic)

-- ============================================================================
-- CORE TYPE CLASSES (Unified Interface)
-- ============================================================================

-- | Base entity with ID
class Entity a where
  entityId :: a -> Int64
  entityCode :: a -> Maybe Text
  entityName :: a -> Text

-- | Timestamped entity
class Timestamped a where
  createdAt :: a -> UTCTime
  updatedAt :: a -> UTCTime

-- | Status entity
class Statusable a where
  status :: a -> EntityStatus

-- | Flagged entity
class Flagged a where
  flags :: a -> Int64

-- | Entity status
data EntityStatus = StatusActive | StatusBlocked | StatusDeleted | StatusDraft
  deriving (Show, Eq, Enum)

-- ============================================================================
-- CORE DOMAIN TYPES
-- ============================================================================

-- | Person (Counteragent)
data Person = Person
  { pId :: !Int64,
    pCode :: !(Maybe Text),
    pName :: !Text,
    pINN :: !(Maybe Text),
    pKPP :: !(Maybe Text),
    pPersonKind :: !PersonKind,
    pStatus :: !EntityStatus,
    pPhone :: !(Maybe Text),
    pEmail :: !(Maybe Text),
    pAddress :: !(Maybe Text),
    pTaxId :: !(Maybe Int64),
    pCreditLimit :: !Double,
    pDiscount :: !Double,
    pCreatedAt :: !UTCTime,
    pUpdatedAt :: !UTCTime
  }
  deriving (Show, Generic)

instance Entity Person where
  entityId = pId
  entityCode = pCode
  entityName = pName

instance Timestamped Person where
  createdAt = pCreatedAt
  updatedAt = pUpdatedAt

instance Statusable Person where
  status = pStatus

-- | Person kinds
data PersonKind = PK_Company | PK_Individual | PK_Entrepreneur | PK_Foreign | PK_Bank
  deriving (Show, Eq, Enum)

-- | Employee (extends Person)
data Employee = Employee
  { empPerson :: !Person,
    empPositionId :: !Int64,
    empHireDate :: !Day,
    empFireDate :: !(Maybe Day),
    empSalary :: !Double,
    empDepartment :: !Text
  }
  deriving (Show, Generic)

-- | Goods (Product)
data Goods = Goods
  { gId :: !Int64,
    gCode :: !(Maybe Text),
    gName :: !Text,
    gBarcode :: !(Maybe Text),
    gUnitId :: !Int64,
    gParentId :: !(Maybe Int64),
    gGoodsType :: !GoodsType,
    gTaxId :: !(Maybe Int64),
    gBrandId :: !(Maybe Int64),
    gStatus :: !EntityStatus,
    gMinStock :: !Double,
    gMaxStock :: !(Maybe Double),
    gWeight :: !(Maybe Double),
    gVolume :: !(Maybe Double),
    gCreatedAt :: !UTCTime,
    gUpdatedAt :: !UTCTime
  }
  deriving (Show, Generic)

instance Entity Goods where
  entityId = gId
  entityCode = gCode
  entityName = gName

instance Timestamped Goods where
  createdAt = gCreatedAt
  updatedAt = gUpdatedAt

instance Statusable Goods where
  status = gStatus

data GoodsType = GT_Item | GT_Service | GT_Bundle | GT_Material | GT_Product
  deriving (Show, Eq, Enum)

-- | Location (Warehouse)
data Location = Location
  { lId :: !Int64,
    lCode :: !(Maybe Text),
    lName :: !Text,
    lLocationType :: !LocationType,
    lAddress :: !(Maybe Text),
    lStatus :: !EntityStatus,
    lCapacity :: !(Maybe Double),
    lParentId :: !(Maybe Int64),
    lCreatedAt :: !UTCTime,
    lUpdatedAt :: !UTCTime
  }
  deriving (Show, Generic)

instance Entity Location where
  entityId = lId
  entityCode = lCode
  entityName = lName

instance Timestamped Location where
  createdAt = lCreatedAt
  updatedAt = lUpdatedAt

instance Statusable Location where
  status = lStatus

data LocationType = LT_Warehouse | LT_Store | LT_Office | LT_Transit
  deriving (Show, Eq, Enum)

-- | Bill (Document)
data Bill = Bill
  { bId :: !Int64,
    bCode :: !(Maybe Text),
    bBillType :: !BillType,
    bDate :: !Day,
    bPersonId :: !(Maybe Int64),
    bLocationId :: !(Maybe Int64),
    bTotal :: !Double,
    bTax :: !Double,
    bDiscount :: !Double,
    bStatus :: !BillStatus,
    bCurrencyId :: !(Maybe Int64),
    bUserId :: !(Maybe Int64),
    bNotes :: !(Maybe Text),
    bCreatedAt :: !UTCTime,
    bPostedAt :: !(Maybe UTCTime)
  }
  deriving (Show, Generic)

instance Entity Bill where
  entityId = bId
  entityCode = bCode
  entityName bill = case bCode bill of
    Just c -> c
    Nothing -> T.pack "Bill"

data BillType = BT_Sale | BT_Purchase | BT_Return | BT_Transfer
  deriving (Show, Eq, Enum)

data BillStatus = BS_Draft | BS_Registered | BS_Posted | BS_Annulled
  deriving (Show, Eq, Enum)

-- | BillLine
data BillLine = BillLine
  { blId :: !Int64,
    blBillId :: !Int64,
    blGoodsId :: !Int64,
    blQtty :: !Double,
    blPrice :: !Double,
    blDiscount :: !Double,
    blTaxRate :: !Double,
    blTax :: !Double,
    blAmount :: !Double
  }
  deriving (Show, Generic)

-- | Stock
data Stock = Stock
  { sId :: !Int64,
    sGoodsId :: !Int64,
    sLocationId :: !Int64,
    sQtty :: !Double,
    sResrvQtty :: !Double,
    sCost :: !Double,
    sPrice :: !Double,
    sBatch :: !(Maybe Text),
    sExpiryDate :: !(Maybe Day)
  }
  deriving (Show, Generic)

-- | Account (Accounting Plan)
data Account = Account
  { aId :: !Int64,
    aCode :: !Text,
    aName :: !Text,
    aAccountType :: !AccountType,
    aParentId :: !(Maybe Int64),
    aIsAnalytic :: !Bool,
    aStatus :: !EntityStatus
  }
  deriving (Show, Generic)

instance Entity Account where
  entityId = aId
  entityCode = Just . aCode
  entityName = aName

instance Statusable Account where
  status = aStatus

data AccountType = AT_Asset | AT_Liability | AT_Equity | AT_Revenue | AT_Expense
  deriving (Show, Eq, Enum)

-- | Accounting Entry
data AccTurn = AccTurn
  { atId :: !Int64,
    atBillId :: !(Maybe Int64),
    atDebitAccId :: !Int64,
    atCreditAccId :: !Int64,
    atAmount :: !Double,
    atCurrencyId :: !(Maybe Int64),
    atDate :: !Day,
    atMemos :: !(Maybe Text)
  }
  deriving (Show, Generic)

-- | Payment
data Payment = Payment
  { payId :: !Int64,
    payBillId :: !(Maybe Int64),
    payDate :: !Day,
    payAmount :: !Double,
    payMethod :: !PaymentMethod,
    payStatus :: !PaymentStatus,
    payCurrencyId :: !(Maybe Int64),
    payUserId :: !(Maybe Int64)
  }
  deriving (Show, Generic)

data PaymentMethod = PM_Cash | PM_Card | PM_Transfer | PM_Bonus
  deriving (Show, Eq, Enum)

data PaymentStatus = PS_Pending | PS_Completed | PS_Failed | PS_Refunded
  deriving (Show, Eq, Enum)

-- | Currency
data Currency = Currency
  { cId :: !Int64,
    cCode :: !Text,
    cNumCode :: !Int,
    cName :: !Text,
    cSymbol :: !Text,
    cRateToBase :: !Double,
    cIsBase :: !Bool
  }
  deriving (Show, Generic)

instance Entity Currency where
  entityId = cId
  entityCode = Just . cCode
  entityName = cName

-- | Tax
data Tax = Tax
  { tId :: !Int64,
    tCode :: !Text,
    tName :: !Text,
    tRate :: !Double,
    tTaxType :: !TaxType,
    tIsIncluded :: !Bool
  }
  deriving (Show, Generic)

instance Entity Tax where
  entityId = tId
  entityCode = Just . tCode
  entityName = tName

data TaxType = TT_VAT | TT_Excise | TT_Property
  deriving (Show, Eq, Enum)

-- | Unit
data Unit = Unit
  { uUnitId :: !Int64,
    uCode :: !Text,
    uUnitName :: !Text,
    uSymbol :: !Text,
    uRatio :: !Double
  }
  deriving (Show, Generic)

instance Entity Unit where
  entityId = uUnitId
  entityCode = Just . uCode
  entityName = uUnitName

-- | User
data User = User
  { uUserId :: !Int64,
    uLogin :: !Text,
    uPersonId :: !(Maybe Int64),
    uUserName :: !Text,
    uEmail :: !(Maybe Text),
    uRoleId :: !(Maybe Int64),
    uStatus :: !EntityStatus,
    uLastLogin :: !(Maybe UTCTime)
  }
  deriving (Show, Generic)

instance Entity User where
  entityId = uUserId
  entityCode = Just . uLogin
  entityName = uUserName

instance Statusable User where
  status = uStatus

-- | Role
data Role = Role
  { rId :: !Int64,
    rName :: !Text,
    rPermissions :: !(Set Text)
  }
  deriving (Show, Generic)

instance Entity Role where
  entityId = rId
  entityCode = const Nothing
  entityName = rName

-- | Order
data Order = Order
  { oId :: !Int64,
    oCode :: !(Maybe Text),
    oDate :: !Day,
    oPersonId :: !(Maybe Int64),
    oStatus :: !OrderStatus,
    oTotal :: !Double,
    oDeliveryAddr :: !(Maybe Text),
    oDeliveryDate :: !(Maybe Day)
  }
  deriving (Show, Generic)

instance Entity Order where
  entityId = oId
  entityCode = oCode
  entityName order = case oCode order of
    Just c -> c
    Nothing -> T.pack "Order"

data OrderStatus = OS_Pending | OS_Confirmed | OS_InProgress | OS_Completed | OS_Cancelled
  deriving (Show, Eq, Enum)

-- | Stock Movement
data StockMovement = StockMovement
  { smId :: !Int64,
    smGoodsId :: !Int64,
    smLocationFromId :: !(Maybe Int64),
    smLocationToId :: !(Maybe Int64),
    smQtty :: !Double,
    smMovementType :: !MovementType,
    smBillId :: !(Maybe Int64),
    smDate :: !Day,
    smUserId :: !(Maybe Int64),
    smNotes :: !(Maybe Text)
  }
  deriving (Show, Generic)

data MovementType = MT_Receipt | MT_Issue | MT_Transfer | MT_Adjustment | MT_Inventory
  deriving (Show, Eq, Enum)

-- ============================================================================
-- GADT FOR TYPE-SAFE OPERATIONS
-- ============================================================================

-- | Type-safe entity operation
data EntityOp a where
  Create :: a -> EntityOp a
  Update :: a -> EntityOp a
  Delete :: Int64 -> EntityOp ()
  Get :: Int64 -> EntityOp (Maybe a)
  List :: EntityFilter a -> EntityOp [a]

-- | Entity filter
data EntityFilter a where
  ById :: Int64 -> EntityFilter a
  ByCode :: Text -> EntityFilter a
  ByStatus :: EntityStatus -> EntityFilter a
  ByDate :: Day -> Day -> EntityFilter a
  All :: EntityFilter a

-- ============================================================================
-- CORE OPERATIONS (Type Classes)
-- ============================================================================

-- | Price operations
class HasPrice a where
  getPrice :: a -> Double
  setPrice :: Double -> a -> a

instance HasPrice Goods where
  getPrice = const 0 -- Placeholder
  setPrice _ g = g

instance HasPrice BillLine where
  getPrice = blPrice
  setPrice p bl = bl {blPrice = p}

-- | Quantity operations
class HasQuantity a where
  getQuantity :: a -> Double
  setQuantity :: Double -> a -> a

instance HasQuantity Stock where
  getQuantity = sQtty
  setQuantity q s = s {sQtty = q}

instance HasQuantity BillLine where
  getQuantity = blQtty
  setQuantity q bl = bl {blQtty = q}

-- | Active/Inactive
class Activatable a where
  activate :: a -> a
  deactivate :: a -> a
  isActive :: a -> Bool

instance Activatable Person where
  activate p = p {pStatus = StatusActive}
  deactivate p = p {pStatus = StatusBlocked}
  isActive p = pStatus p == StatusActive

instance Activatable Location where
  activate l = l {lStatus = StatusActive}
  deactivate l = l {lStatus = StatusBlocked}
  isActive l = lStatus l == StatusActive

instance Activatable User where
  activate u = u {uStatus = StatusActive}
  deactivate u = u {uStatus = StatusBlocked}
  isActive u = uStatus u == StatusActive

-- ============================================================================
-- CALCULATION FUNCTIONS
-- ============================================================================

-- | Calculate bill line amount
calcBillLineAmount :: BillLine -> Double
calcBillLineAmount bl =
  let discount = blQtty bl * blPrice bl * blDiscount bl / 100
   in blQtty bl * blPrice bl - discount

-- | Calculate bill total
calcBillTotal :: [BillLine] -> Double
calcBillTotal lines = sum (fmap calcBillLineAmount lines)

-- | Calculate stock available
calcStockAvailable :: Stock -> Double
calcStockAvailable s = sQtty s - sResrvQtty s

-- | Check if stock needs reorder
needsReorder :: Stock -> Double -> Bool
needsReorder s minStock = calcStockAvailable s < minStock

-- | Calculate tax amount
calcTax :: Double -> Double -> Double
calcTax amount rate = amount * rate / 100

-- | Calculate discount amount
calcDiscount :: Double -> Double -> Double
calcDiscount amount percent = amount * percent / 100

-- | Calculate final price with discount and tax
calcFinalPrice :: Double -> Double -> Double -> Double
calcFinalPrice price qty discountRate =
  let base = price * qty
      discount = calcDiscount base discountRate
      afterDiscount = base - discount
   in afterDiscount

-- ============================================================================
-- VALIDATION FUNCTIONS
-- ============================================================================

-- | Validate INN (Russian tax number)
validateINN :: Text -> Bool
validateINN inn =
  let len = T.length inn
   in len == 10 || len == 12

-- | Validate KPP (Russian registration reason)
validateKPP :: Text -> Bool
validateKPP kpp = T.length kpp == 9

-- | Validate barcode
validateBarcode :: Text -> Bool
validateBarcode bc =
  let len = T.length bc
   in len >= 8 && len <= 14

-- | Validate email
validateEmail :: Text -> Bool
validateEmail email =
  T.isInfixOf (T.pack "@") email && T.isInfixOf (T.pack ".") email

-- | Validate phone
validatePhone :: Text -> Bool
validatePhone phone =
  let digits = filter (\c -> c `elem` ['0' .. '9']) (T.unpack phone)
   in length digits >= 10

-- ============================================================================
-- ENTITY CREATION HELPERS
-- ============================================================================

-- | Create new person
mkPerson :: Int64 -> Text -> PersonKind -> Text -> Person
mkPerson id name kind inn =
  Person
    { pId = id,
      pCode = Nothing,
      pName = name,
      pINN = Just inn,
      pKPP = Nothing,
      pPersonKind = kind,
      pStatus = StatusActive,
      pPhone = Nothing,
      pEmail = Nothing,
      pAddress = Nothing,
      pTaxId = Nothing,
      pCreditLimit = 0,
      pDiscount = 0,
      pCreatedAt = undefined,
      pUpdatedAt = undefined
    }

-- | Create new goods
mkGoods :: Int64 -> Text -> GoodsType -> Int64 -> Goods
mkGoods id name gtype unitId =
  Goods
    { gId = id,
      gCode = Nothing,
      gName = name,
      gBarcode = Nothing,
      gUnitId = unitId,
      gParentId = Nothing,
      gGoodsType = gtype,
      gTaxId = Nothing,
      gBrandId = Nothing,
      gStatus = StatusActive,
      gMinStock = 0,
      gMaxStock = Nothing,
      gWeight = Nothing,
      gVolume = Nothing,
      gCreatedAt = undefined,
      gUpdatedAt = undefined
    }

-- | Create new location
mkLocation :: Int64 -> Text -> LocationType -> Location
mkLocation id name ltype =
  Location
    { lId = id,
      lCode = Nothing,
      lName = name,
      lLocationType = ltype,
      lAddress = Nothing,
      lStatus = StatusActive,
      lCapacity = Nothing,
      lParentId = Nothing,
      lCreatedAt = undefined,
      lUpdatedAt = undefined
    }

-- ============================================================================
-- LOOKUP TABLES (Static Data)
-- ============================================================================

-- | Standard units
stdUnits :: [Unit]
stdUnits =
  [ Unit 1 (T.pack "PC") (T.pack "Штука") (T.pack "шт") 1,
    Unit 2 (T.pack "KG") (T.pack "Килограмм") (T.pack "кг") 1,
    Unit 3 (T.pack "M") (T.pack "Метр") (T.pack "м") 1,
    Unit 4 (T.pack "L") (T.pack "Литр") (T.pack "л") 1,
    Unit 5 (T.pack "HR") (T.pack "Час") (T.pack "ч") 1,
    Unit 6 (T.pack "DAY") (T.pack "День") (T.pack "дн") 1
  ]

-- | Person kinds
personKinds :: [(PersonKind, Text)]
personKinds =
  [ (PK_Company, T.pack "Юридическое лицо"),
    (PK_Individual, T.pack "Физическое лицо"),
    (PK_Entrepreneur, T.pack "ИП"),
    (PK_Foreign, T.pack "Иностранная организация"),
    (PK_Bank, T.pack "Банк")
  ]

-- | Bill statuses
billStatuses :: [(BillStatus, Text)]
billStatuses =
  [ (BS_Draft, T.pack "Черновик"),
    (BS_Registered, T.pack "Проведен"),
    (BS_Posted, T.pack "Опубликован"),
    (BS_Annulled, T.pack "Аннулирован")
  ]

-- | Currencies
stdCurrencies :: [Currency]
stdCurrencies =
  [ Currency 1 (T.pack "RUB") 643 (T.pack "Российский рубль") (T.pack "₽") 1 True,
    Currency 2 (T.pack "USD") 840 (T.pack "Доллар США") (T.pack "$") 70 False,
    Currency 3 (T.pack "EUR") 978 (T.pack "Евро") (T.pack "€") 80 False
  ]

-- | Tax rates
stdTaxes :: [Tax]
stdTaxes =
  [ Tax 1 (T.pack "VAT0") (T.pack "НДС 0%") 0 TT_VAT False,
    Tax 2 (T.pack "VAT10") (T.pack "НДС 10%") 10 TT_VAT False,
    Tax 3 (T.pack "VAT20") (T.pack "НДС 20%") 20 TT_VAT False,
    Tax 4 (T.pack "EXCISE") (T.pack "Акциз") 0 TT_Excise True
  ]

-- ============================================================================
-- DATABASE SCHEMA MAPPING
-- ============================================================================

-- | Table name constants
tablePerson :: Text
tablePerson = T.pack "person"

tableGoods :: Text
tableGoods = T.pack "goods"

tableLocation :: Text
tableLocation = T.pack "location"

tableBill :: Text
tableBill = T.pack "bill"

tableBillLine :: Text
tableBillLine = T.pack "bill_line"

tableStock :: Text
tableStock = T.pack "stock"

tableAccount :: Text
tableAccount = T.pack "acc_plan"

tableAccTurn :: Text
tableAccTurn = T.pack "acc_turn"

tablePayment :: Text
tablePayment = T.pack "payment"

tableCurrency :: Text
tableCurrency = T.pack "currency"

tableTax :: Text
tableTax = T.pack "tax"

tableUnit :: Text
tableUnit = T.pack "unit"

tableUser :: Text
tableUser = T.pack "usr"

tableRole :: Text
tableRole = T.pack "role"

tableOrder :: Text
tableOrder = T.pack "order_head"

data Proxy a = Proxy

-- ============================================================================
-- EXAMPLE OPERATIONS
-- ============================================================================

-- | Process a sale
processSale :: Bill -> [BillLine] -> Either Text Bill
processSale bill billLines
  | bStatus bill /= BS_Draft = Left (T.pack "Bill must be in draft status")
  | null billLines = Left (T.pack "Bill must have at least one line")
  | otherwise = Right bill {bTotal = calcBillTotal billLines}

-- | Post a bill (generate accounting entries)
postBill :: Bill -> [BillLine] -> [AccTurn]
postBill bill = concatMap (generateEntries bill)

generateEntries :: Bill -> BillLine -> [AccTurn]
generateEntries bill line =
  [ AccTurn 0 (Just (bId bill)) 0 0 (blAmount line) Nothing (bDate bill) Nothing
  ]

-- | Reserve stock
reserveStock :: Stock -> Double -> Either Text Stock
reserveStock stock qty
  | qty <= 0 = Left (T.pack "Quantity must be positive")
  | calcStockAvailable stock < qty = Left (T.pack "Insufficient stock")
  | otherwise = Right stock {sResrvQtty = sResrvQtty stock + qty}

-- | Release stock reservation
releaseStock :: Stock -> Double -> Either Text Stock
releaseStock stock qty
  | qty <= 0 = Left (T.pack "Quantity must be positive")
  | sResrvQtty stock < qty = Left (T.pack "Cannot release more than reserved")
  | otherwise = Right stock {sResrvQtty = sResrvQtty stock - qty}
