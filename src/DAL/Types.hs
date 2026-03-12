{-# LANGUAGE DeriveGeneric #-}

-- | Database Types
module DAL.Types where

import Data.Aeson (Object, ToJSON, toJSON, (.=))
import Data.Int (Int32, Int64)
import Data.Text (Text)
import Data.Time (Day, UTCTime)
import GHC.Generics (Generic)
import Surypus.Types (Decimal (..))

-- | Person types
data Person = Person
  { pId :: Int64,
    pCode :: Maybe Text,
    pName :: Text,
    pINN :: Maybe Text,
    pKPP :: Maybe Text,
    pPersonType :: Int32,
    pStatus :: Int32
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

-- | Order types
data Order = Order
  { oId :: Int64,
    oCode :: Maybe Text,
    oDate :: Day,
    oPersonId :: Maybe Int64,
    oStatus :: Int,
    oTotal :: Decimal
  }
  deriving (Show, Eq, Generic)

instance ToJSON Order

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
