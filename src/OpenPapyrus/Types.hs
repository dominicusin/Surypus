-- | OpenPapyrus basic types
module OpenPapyrus.Types where

import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (Day)

type Money = Double

type DocDate = Day

type ID = Int

type GoodsID = Int

type LocationID = Int

type BillID = Int

type LotID = Int

type AgentID = Int

data BillType
  = PPOPT_GOODSRECEIPT
  | PPOPT_GOODSRETURN
  | PPOPT_SALES
  | PPOPT_SALERETURN
  | PPOPT_TRANSFER
  | PPOPT_WRITEON
  | PPOPT_INVENTORY
  | PPOPT_ACCTURN
  | PPOPT_PAYMENT
  | PPOPT_DRAFTRECEIPT
  | PPOPT_DRAFTSHIPMENT
  deriving (Eq, Show)

billTypeToInt :: BillType -> Int
billTypeToInt PPOPT_GOODSRECEIPT = 1
billTypeToInt PPOPT_GOODSRETURN = 2
billTypeToInt PPOPT_SALES = 3
billTypeToInt PPOPT_SALERETURN = 4
billTypeToInt PPOPT_TRANSFER = 5
billTypeToInt PPOPT_WRITEON = 6
billTypeToInt PPOPT_INVENTORY = 7
billTypeToInt PPOPT_ACCTURN = 8
billTypeToInt PPOPT_PAYMENT = 9
billTypeToInt PPOPT_DRAFTRECEIPT = 10
billTypeToInt PPOPT_DRAFTSHIPMENT = 11

data AmountTypeID
  = PPAMT_MAIN
  | PPAMT_COST
  | PPAMT_VATAX
  | PPAMT_CVAT
  | PPAMT_PVAT
  | PPAMT_EXCISE
  | PPAMT_SALESTAX
  deriving (Eq, Show)

data TaxType
  = GTAX_VAT
  | GTAX_EXCISE
  | GTAX_SALES
  deriving (Eq, Show)

newtype BillFlags = BillFlags Int
  deriving (Eq, Show)

newtype TransferFlags = TransferFlags Int
  deriving (Eq, Show)

data OpResult a = OpSuccess a | OpFailure String
  deriving (Eq, Show)

instance Functor OpResult where
  fmap f (OpSuccess a) = OpSuccess (f a)
  fmap _ (OpFailure e) = OpFailure e

instance Applicative OpResult where
  pure = OpSuccess
  (OpSuccess f) <*> (OpSuccess a) = OpSuccess (f a)
  (OpFailure e) <*> _ = OpFailure e
  _ <*> (OpFailure e) = OpFailure e

instance Monad OpResult where
  return = OpSuccess
  (OpSuccess a) >>= f = f a
  (OpFailure e) >>= _ = OpFailure e

isOk :: OpResult a -> Bool
isOk (OpSuccess _) = True
isOk _ = False

fromResult :: a -> OpResult a -> a
fromResult _ (OpSuccess a) = a
fromResult defaultVal (OpFailure _) = defaultVal

round2 :: Double -> Double
round2 d = fromInteger (round (d * 100)) / 100

round4 :: Double -> Double
round4 d = fromInteger (round (d * 10000)) / 10000

isZero :: Double -> Bool
isZero d = d == 0

safeDiv :: Double -> Double -> Double
safeDiv _ 0 = 0
safeDiv a b = a / b

formatMoney :: Double -> String
formatMoney d = show (round2 d)

data DateRange = DateRange
  { drStart :: Day,
    drEnd :: Day
  }
  deriving (Eq, Show)

inDateRange :: Day -> DateRange -> Bool
inDateRange d r = d >= drStart r && d <= drEnd r

testGoods :: [(GoodsID, String)]
testGoods =
  [ (1, "Goods A"),
    (2, "Goods B"),
    (3, "Goods C")
  ]

testLocations :: [(LocationID, String)]
testLocations =
  [ (1, "Main Warehouse"),
    (2, "Retail Store")
  ]

testAgents :: [(AgentID, String)]
testAgents =
  [ (1, "Supplier LLC"),
    (2, "Customer IE")
  ]
