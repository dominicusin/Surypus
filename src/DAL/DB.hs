-- ============================================================================
-- SURYPUS DATABASE LAYER - Simple In-Memory Implementation
-- ============================================================================
{-# LANGUAGE OverloadedStrings #-}

module DAL.DB where

import DAL.Types (Bill (..), Goods (..), Location (..), Person (..), Stock (..))
import Data.IORef (IORef, modifyIORef, newIORef, readIORef)
import Data.Int (Int64)
import Data.List (find)

-- ============================================================================
-- IN-MEMORY STORAGE
-- ============================================================================

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
  [ Person {pId = 1, pCode = Just "001", pName = "Company A", pINN = Just "1234567891", pKPP = Just "123456791", pPersonType = 1, pStatus = 0},
    Person {pId = 2, pCode = Just "002", pName = "Company B", pINN = Just "1234567892", pKPP = Just "123456792", pPersonType = 1, pStatus = 0},
    Person {pId = 3, pCode = Just "003", pName = "Supplier X", pINN = Just "1234567893", pKPP = Just "123456793", pPersonType = 2, pStatus = 0}
  ]

testGoods :: [Goods]
testGoods =
  [ Goods {gId = 1, gCode = Just "001", gName = "Product A", gBarcode = Just "1234567890123", gUnitId = 1, gParentId = Nothing},
    Goods {gId = 2, gCode = Just "002", gName = "Product B", gBarcode = Just "1234567890124", gUnitId = 1, gParentId = Nothing},
    Goods {gId = 3, gCode = Just "003", gName = "Product C", gBarcode = Just "1234567890125", gUnitId = 1, gParentId = Nothing}
  ]

testLocations :: [Location]
testLocations =
  [ Location {lId = 1, lCode = Just "WH-01", lName = "Main Warehouse", lType = 1},
    Location {lId = 2, lCode = Just "WH-02", lName = "Second Warehouse", lType = 1},
    Location {lId = 3, lCode = Just "SHOP-01", lName = "Retail Shop", lType = 2}
  ]

testBills :: [Bill]
testBills = []

testStock :: [Stock]
testStock =
  [ Stock {sId = 1, sGoodsId = 1, sLocationId = 1, sQtty = 100, sResrvQtty = 0},
    Stock {sId = 2, sGoodsId = 2, sLocationId = 1, sQtty = 50, sResrvQtty = 0},
    Stock {sId = 3, sGoodsId = 1, sLocationId = 2, sQtty = 200, sResrvQtty = 0}
  ]

-- ============================================================================
-- DB ACTIONS
-- ============================================================================

-- Persons
queryPersons :: Database -> Int -> Int -> IO [Person]
queryPersons db limit offset = do
  xs <- readIORef (dbPersons db)
  pure . take limit $ drop offset xs

queryPersonById :: Database -> Int64 -> IO (Maybe Person)
queryPersonById db pid = do
  xs <- readIORef (dbPersons db)
  pure $ find (\p -> pId p == pid) xs

insertPerson :: Database -> Person -> IO Int64
insertPerson db p = do
  modifyIORef (dbPersons db) (p :)
  pure $ pId p

updatePerson :: Database -> Int64 -> Person -> IO ()
updatePerson db pid p = do
  modifyIORef (dbPersons db) (fmap (\x -> if pId x == pid then p else x))

deletePerson :: Database -> Int64 -> IO ()
deletePerson db pid = do
  modifyIORef (dbPersons db) (filter (\p -> pId p /= pid))

-- Goods
queryGoods :: Database -> Int -> Int -> IO [Goods]
queryGoods db limit offset = do
  xs <- readIORef (dbGoods db)
  pure . take limit $ drop offset xs

queryGoodsById :: Database -> Int64 -> IO (Maybe Goods)
queryGoodsById db gid = do
  xs <- readIORef (dbGoods db)
  pure $ find (\g -> gId g == gid) xs

insertGoods :: Database -> Goods -> IO Int64
insertGoods db g = do
  modifyIORef (dbGoods db) (g :)
  pure $ gId g

updateGoods :: Database -> Int64 -> Goods -> IO ()
updateGoods db gid g = do
  modifyIORef (dbGoods db) (fmap (\x -> if gId x == gid then g else x))

deleteGoods :: Database -> Int64 -> IO ()
deleteGoods db gid = do
  modifyIORef (dbGoods db) (filter (\g -> gId g /= gid))

-- Locations
queryLocations :: Database -> Int -> Int -> IO [Location]
queryLocations db limit offset = do
  xs <- readIORef (dbLocations db)
  pure . take limit $ drop offset xs

queryLocationById :: Database -> Int64 -> IO (Maybe Location)
queryLocationById db lid = do
  xs <- readIORef (dbLocations db)
  pure $ find (\l -> lId l == lid) xs

insertLocation :: Database -> Location -> IO Int64
insertLocation db l = do
  modifyIORef (dbLocations db) (l :)
  pure $ lId l

updateLocation :: Database -> Int64 -> Location -> IO ()
updateLocation db lid l = do
  modifyIORef (dbLocations db) (fmap (\x -> if lId x == lid then l else x))

deleteLocation :: Database -> Int64 -> IO ()
deleteLocation db lid = do
  modifyIORef (dbLocations db) (filter (\l -> lId l /= lid))

-- Bills
queryBills :: Database -> Int -> Int -> Maybe Int -> Maybe Int -> IO [Bill]
queryBills db limit offset _mtype _mperson = do
  xs <- readIORef (dbBills db)
  pure . take limit $ drop offset xs

queryBillById :: Database -> Int64 -> IO (Maybe Bill)
queryBillById db bid = do
  xs <- readIORef (dbBills db)
  pure $ find (\b -> bId b == bid) xs

queryBillLines :: Database -> Int64 -> IO [(Int64, Double)]
queryBillLines _db _bid = pure []

insertBill :: Database -> Bill -> IO Int64
insertBill db b = do
  modifyIORef (dbBills db) (b :)
  pure $ bId b

postBill :: Database -> Int64 -> IO Bool
postBill _db _bid = pure True

-- Stock
queryStock :: Database -> Maybe Int64 -> Maybe Int64 -> IO [Stock]
queryStock db mgid mlid = do
  xs <- readIORef (dbStock db)
  pure $ case (mgid, mlid) of
    (Just gid, Just lid) -> filter (\s -> sGoodsId s == gid && sLocationId s == lid) xs
    (Just gid, Nothing) -> filter (\s -> sGoodsId s == gid) xs
    (Nothing, Just lid) -> filter (\s -> sLocationId s == lid) xs
    (Nothing, Nothing) -> xs

reserveStock :: Database -> Int64 -> Int64 -> Double -> IO Bool
reserveStock _db _gid _lid _qty = pure True
