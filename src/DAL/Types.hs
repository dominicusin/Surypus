-- | Database Types
module DAL.Types where

import           Data.Int  (Int64)
import           Data.Text (Text)
import           Data.Time (Day, UTCTime)

-- | Person types
data Person = Person
  { pId         :: Int64,
    pCode       :: Maybe Text,
    pName       :: Text,
    pINN        :: Maybe Text,
    pKPP        :: Maybe Text,
    pPersonType :: Int,
    pStatus     :: Int
  }
  deriving (Show, Eq)

-- | Goods types
data Goods = Goods
  { gId       :: Int64,
    gCode     :: Maybe Text,
    gName     :: Text,
    gBarcode  :: Maybe Text,
    gUnitId   :: Int64,
    gParentId :: Maybe Int64
  }
  deriving (Show, Eq)

-- | Bill types
data Bill = Bill
  { bId         :: Int64,
    bCode       :: Maybe Text,
    bType       :: Int,
    bStatus     :: Int,
    bDate       :: Day,
    bPersonId   :: Maybe Int64,
    bLocationId :: Maybe Int64,
    bTotal      :: Double,
    bDiscount   :: Double,
    bTax        :: Double
  }
  deriving (Show, Eq)

-- | BillLine types
data BillLine = BillLine
  { blId       :: Int64,
    blBillId   :: Int64,
    blGoodsId  :: Int64,
    blQtty     :: Double,
    blPrice    :: Double,
    blDiscount :: Double,
    blAmount   :: Double
  }
  deriving (Show, Eq)

-- | Location types
data Location = Location
  { lId   :: Int64,
    lCode :: Maybe Text,
    lName :: Text,
    lType :: Int
  }
  deriving (Show, Eq)

-- | Stock types
data Stock = Stock
  { sId         :: Int64,
    sGoodsId    :: Int64,
    sLocationId :: Int64,
    sQtty       :: Double,
    sResrvQtty  :: Double
  }
  deriving (Show, Eq)

-- | AccPlan types
data AccPlan = AccPlan
  { apId   :: Int64,
    apCode :: Text,
    apName :: Text,
    apType :: Int
  }
  deriving (Show, Eq)

-- | AccTurn types
data AccTurn = AccTurn
  { atId       :: Int64,
    atBillId   :: Maybe Int64,
    atDbtAccId :: Int64,
    atCrdAccId :: Int64,
    atAmount   :: Double,
    atDate     :: Day
  }
  deriving (Show, Eq)

-- | User types
data User = User
  { uId       :: Int64,
    uLogin    :: Text,
    uPersonId :: Maybe Int64,
    uName     :: Maybe Text,
    uEmail    :: Maybe Text,
    uRoleId   :: Maybe Int64,
    uStatus   :: Int
  }
  deriving (Show, Eq)

-- | Order types
data Order = Order
  { oId       :: Int64,
    oCode     :: Maybe Text,
    oDate     :: Day,
    oPersonId :: Maybe Int64,
    oStatus   :: Int,
    oTotal    :: Double
  }
  deriving (Show, Eq)

-- | Payment types
data Payment = Payment
  { payId     :: Int64,
    payBillId :: Int64,
    payDate   :: Day,
    payAmount :: Double,
    payMethod :: Int,
    payStatus :: Int
  }
  deriving (Show, Eq)

-- | Result type
data QueryResult a = QuerySuccess a | QueryError Text deriving (Show, Eq)
