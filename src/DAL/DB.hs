-- ============================================================================
-- SURYPUS DATABASE LAYER - Simple In-Memory Implementation
-- ============================================================================
{-# LANGUAGE OverloadedStrings #-}

module DAL.DB where
import qualified Data.List as L

import Data.IORef (IORef, newIORef, readIORef, modifyIORef')
import Data.Int (Int64)
import Data.List (find)
import Data.Text (Text)
import qualified Data.Text as T

-- ============================================================================
-- IN-MEMORY STORAGE - Using compatible stub types
-- ============================================================================

-- Заглушки для типов (заменить на реальные типы из DAL.Types когда они будут определены)
data Person = PersonStub
  { pId :: Int64
  , pCode :: Maybe Text
  , pName :: Text
  , pINN :: Maybe Text
  , pKPP :: Maybe Text
  , pPersonType :: Int
  , pStatus :: Int
  } deriving (Show, Eq)

data Goods = GoodsStub
  { gId :: Int64
  , gCode :: Maybe Text
  , gName :: Text
  , gBarcode :: Maybe Text
  , gUnitId :: Int
  , gParentId :: Maybe Int64
  } deriving (Show, Eq)

data Location = LocationStub
  { lId :: Int64
  , lCode :: Maybe Text
  , lName :: Text
  , lType :: Int
  } deriving (Show, Eq)

data Bill = BillStub
  { billId :: Int64
  , billTotal :: Double
  } deriving (Show, Eq)

data Stock = StockStub
  { sId :: Int64
  , sGoodsId :: Int64
  , sLocationId :: Int64
  , sQtty :: Int
  , sResrvQtty :: Int
  } deriving (Show, Eq)

data Database = Database
  { dbPersons :: IORef [Person],
    dbGoods :: IORef [Goods],
    dbLocations :: IORef [Location],
    dbBills :: IORef [Bill],
    dbStock :: IORef [Stock]
  }

-- Create initial database
newDatabase :: IO Database
newDatabase = do
  persons <- newIORef testPersons
  goods <- newIORef testGoods
  locations <- newIORef testLocations
  bills <- newIORef testBills
  stock <- newIORef testStock
  pure Database {dbPersons = persons, dbGoods = goods, dbLocations = locations, dbBills = bills, dbStock = stock}

-- Test data - using record syntax
testPersons :: [Person]
testPersons =
  [ PersonStub {pId = 1, pCode = Just "001", pName = T.pack "Company A", pINN = Just "1234567891", pKPP = Just "123456791", pPersonType = 1, pStatus = 0},
    PersonStub {pId = 2, pCode = Just "002", pName = T.pack "Company B", pINN = Just "1234567892", pKPP = Just "123456792", pPersonType = 1, pStatus = 0},
    PersonStub {pId = 3, pCode = Just "003", pName = T.pack "Supplier X", pINN = Just "1234567893", pKPP = Just "123456793", pPersonType = 2, pStatus = 0}
  ]

testGoods :: [Goods]
testGoods =
  [ GoodsStub {gId = 1, gCode = Just "001", gName = T.pack "Product A", gBarcode = Just "1234567890123", gUnitId = 1, gParentId = Nothing},
    GoodsStub {gId = 2, gCode = Just "002", gName = T.pack "Product B", gBarcode = Just "1234567890124", gUnitId = 1, gParentId = Nothing},
    GoodsStub {gId = 3, gCode = Just "003", gName = T.pack "Product C", gBarcode = Just "1234567890125", gUnitId = 1, gParentId = Nothing}
  ]

testLocations :: [Location]
testLocations =
  [ LocationStub {lId = 1, lCode = Just "WH-01", lName = T.pack "Main Warehouse", lType = 1},
    LocationStub {lId = 2, lCode = Just "WH-02", lName = T.pack "Second Warehouse", lType = 1},
    LocationStub {lId = 3, lCode = Just "SHOP-01", lName = T.pack "Retail Shop", lType = 2}
  ]

testBills :: [Bill]
testBills = []

testStock :: [Stock]
testStock =
  [ StockStub {sId = 1, sGoodsId = 1, sLocationId = 1, sQtty = 100, sResrvQtty = 0},
    StockStub {sId = 2, sGoodsId = 2, sLocationId = 1, sQtty = 50, sResrvQtty = 0},
    StockStub {sId = 3, sGoodsId = 1, sLocationId = 2, sQtty = 200, sResrvQtty = 0}
  ]

-- ============================================================================
-- DB ACTIONS
-- ============================================================================

-- Persons
queryPersons :: Database -> Int -> Int -> IO [Person]
queryPersons db limit offset = do
  ps <- readIORef (dbPersons db)
  return $ drop offset $ take limit ps

-- Goods
queryGoods :: Database -> Int -> Int -> IO [Goods]
queryGoods db limit offset = do
  gs <- readIORef (dbGoods db)
  return $ drop offset $ take limit gs

-- Locations
queryLocations :: Database -> Int -> Int -> IO [Location]
queryLocations db limit offset = do
  ls <- readIORef (dbLocations db)
  return $ drop offset $ take limit ls

-- Bills
queryBills :: Database -> Int -> Int -> IO [Bill]
queryBills db limit offset = do
  bs <- readIORef (dbBills db)
  return $ drop offset $ take limit bs

-- Stock
queryStock :: Database -> Int -> Int -> IO [Stock]
queryStock db limit offset = do
  st <- readIORef (dbStock db)
  return $ drop offset $ take limit st

-- Find operations
findPersonById :: Database -> Int64 -> IO (Maybe Person)
findPersonById db pid = do
  ps <- readIORef (dbPersons db)
  return $ find (\p -> pId p == pid) ps

findGoodsById :: Database -> Int64 -> IO (Maybe Goods)
findGoodsById db gid = do
  gs <- readIORef (dbGoods db)
  return $ find (\g -> gId g == gid) gs

findLocationById :: Database -> Int64 -> IO (Maybe Location)
findLocationById db lid = do
  ls <- readIORef (dbLocations db)
  return $ find (\l -> lId l == lid) ls

-- Insert operations
insertPerson :: Database -> Person -> IO ()
insertPerson db p = modifyIORef' (dbPersons db) (p :)

insertGoods :: Database -> Goods -> IO ()
insertGoods db g = modifyIORef' (dbGoods db) (g :)

insertLocation :: Database -> Location -> IO ()
insertLocation db l = modifyIORef' (dbLocations db) (l :)

insertBill :: Database -> Bill -> IO ()
insertBill db b = modifyIORef' (dbBills db) (b :)

insertStock :: Database -> Stock -> IO ()
insertStock db s = modifyIORef' (dbStock db) (s :)
