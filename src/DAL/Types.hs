{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DeriveFunctor #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE DerivingStrategies #-}
-- | DAL.Types module
module DAL.Types (
    DashboardStats (..),
    QueryResult (..),
    Decimal (..),
    Bill (..),
    BillInput (..),
    BillLine (..),
    Goods (..),
    GoodsInput (..),
    Person (..),
    PersonInput (..),
    Payment (..),
    PaymentInput (..),
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

-- | Decimal type for monetary values
newtype Decimal = Decimal Double
  deriving stock (Show, Eq, Ord, Generic)
  deriving newtype Num

instance ToJSON Decimal
instance FromJSON Decimal

-- | Bill type (simplified for API)
data Bill = Bill
  { billId :: !Int64,
    billNumber :: !(Maybe Text),
    billStatus :: !Int,
    billAmount :: !Double,
    billLines :: ![BillLine],
    billCreatedAt :: !UTCTime,
    billUpdatedAt :: !(Maybe UTCTime),
    billPersonId :: !(Maybe Int64),
    billLocationId :: !(Maybe Int64)
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON Bill
instance FromJSON Bill

-- | Bill input type
data BillInput = BillInput
  { biCode :: !(Maybe Text),
    biType :: !Int,
    biStatus :: !Int,
    biAmount :: !Double,
    biDate :: !Day
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON BillInput
instance FromJSON BillInput

-- | Bill line type
data BillLine = BillLine
  { lineId :: !Int64,
    lineBillId :: !Int64,
    lineGoodId :: !Int64,
    lineQuantity :: !Int,
    linePrice :: !Double,
    lineTotal :: !Double,
    lineTaxRate :: !(Maybe Double)
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON BillLine
instance FromJSON BillLine

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
  { gInputName :: !Text,
    gInputCode :: !(Maybe Text),
    gInputBarcode :: !(Maybe Text),
    gInputUnitId :: !(Maybe Int64),
    gInputCategoryId :: !(Maybe Int64),
    gInputType :: !(Maybe Int),
    gInputMinStock :: !(Maybe Double),
    gInputMaxStock :: !(Maybe Double),
    gInputWeight :: !(Maybe Double),
    gInputVolume :: !(Maybe Double)
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON GoodsInput
instance FromJSON GoodsInput

-- | Person type (simplified for API)
data Person = Person
  { personId :: !Int64,
    personName :: !Text,
    personCode :: !(Maybe Text),
    personStatus :: !(Maybe Int)
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON Person
instance FromJSON Person

-- | Person input type
data PersonInput = PersonInput
  { pInputName :: !Text,
    pInputCode :: !(Maybe Text),
    pInputStatus :: !(Maybe Int)
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