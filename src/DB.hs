-- ============================================================================
-- SURYPUS DATABASE LAYER - Simple In-Memory Implementation
-- ============================================================================

{-# LANGUAGE OverloadedStrings #-}

module DB where

import Data.Int (Int64)
import Data.IORef (IORef, newIORef, readIORef, modifyIORef)
import Data.Maybe (listToMaybe)
import qualified Data.Text as T
import APIServer (Person(..), Goods(..), Location(..), Bill(..), Stock(..))

-- ============================================================================
-- IN-MEMORY STORAGE
-- ============================================================================

data Database = Database
    { dbPersons   :: IORef [Person]
    , dbGoods     :: IORef [Goods]
    , dbLocations :: IORef [Location]
    , dbBills     :: IORef [Bill]
    , dbStock     :: IORef [Stock]
    }

-- Create initial database
newDatabase :: IO Database
newDatabase = do
    persons <- newIORef testPersons
    goods <- newIORef testGoods
    locations <- newIORef testLocations
    bills <- newIORef testBills
    stock <- newIORef testStock
    return Database { dbPersons = persons, dbGoods = goods, dbLocations = locations, dbBills = bills, dbStock = stock }

-- Test data - using record syntax
testPersons :: [Person]
testPersons = 
    [ Person { pId = Just 1, pCode = Just "001", pName = "Company A", pINN = Just "1234567891", pKPP = Just "123456791", pPersonKind = 1, pStatus = 0, pPhone = Nothing, pEmail = Nothing, pAddress = Nothing, pCreditLimit = 100000, pDiscount = 5 }
    , Person { pId = Just 2, pCode = Just "002", pName = "Company B", pINN = Just "1234567892", pKPP = Just "123456792", pPersonKind = 1, pStatus = 0, pPhone = Nothing, pEmail = Nothing, pAddress = Nothing, pCreditLimit = 50000, pDiscount = 3 }
    , Person { pId = Just 3, pCode = Just "003", pName = "Supplier X", pINN = Just "1234567893", pKPP = Just "123456793", pPersonKind = 2, pStatus = 0, pPhone = Nothing, pEmail = Nothing, pAddress = Nothing, pCreditLimit = 200000, pDiscount = 10 }
    ]

testGoods :: [Goods]
testGoods = 
    [ Goods { gId = Just 1, gCode = Just "001", gName = "Product A", gBarcode = Just "1234567890123", gUnitId = 1, gParentId = Nothing, gGoodsType = 1, gTaxId = Just 1, gBrandId = Nothing, gStatus = 0, gMinStock = 10, gMaxStock = Nothing, gWeight = Nothing, gVolume = Nothing }
    , Goods { gId = Just 2, gCode = Just "002", gName = "Product B", gBarcode = Just "1234567890124", gUnitId = 1, gParentId = Nothing, gGoodsType = 1, gTaxId = Just 1, gBrandId = Nothing, gStatus = 0, gMinStock = 5, gMaxStock = Nothing, gWeight = Nothing, gVolume = Nothing }
    , Goods { gId = Just 3, gCode = Just "003", gName = "Product C", gBarcode = Just "1234567890125", gUnitId = 1, gParentId = Nothing, gGoodsType = 2, gTaxId = Just 1, gBrandId = Nothing, gStatus = 0, gMinStock = 20, gMaxStock = Nothing, gWeight = Nothing, gVolume = Nothing }
    ]

testLocations :: [Location]
testLocations = 
    [ Location { lId = Just 1, lCode = Just "WH-01", lName = "Main Warehouse", lLocationType = 1, lAddress = Nothing, lStatus = 0, lCapacity = Just 1000, lParentId = Nothing }
    , Location { lId = Just 2, lCode = Just "WH-02", lName = "Second Warehouse", lLocationType = 1, lAddress = Nothing, lStatus = 0, lCapacity = Just 500, lParentId = Nothing }
    , Location { lId = Just 3, lCode = Just "SHOP-01", lName = "Retail Shop", lLocationType = 2, lAddress = Nothing, lStatus = 0, lCapacity = Just 100, lParentId = Nothing }
    ]

testBills :: [Bill]
testBills = []

testStock :: [Stock]
testStock = 
    [ Stock { sId = Just 1, sGoodsId = 1, sLocationId = 1, sQtty = 100, sCost = 100.0, sPrice = 150.0, sBatch = Just "BATCH-001" }
    , Stock { sId = Just 2, sGoodsId = 2, sLocationId = 1, sQtty = 50, sCost = 80.0, sPrice = 120.0, sBatch = Just "BATCH-002" }
    , Stock { sId = Just 3, sGoodsId = 1, sLocationId = 2, sQtty = 200, sCost = 100.0, sPrice = 150.0, sBatch = Just "BATCH-003" }
    ]

-- ============================================================================
-- DB ACTIONS
-- ============================================================================

-- Persons
queryPersons :: Database -> Int -> Int -> IO [Person]
queryPersons db limit offset = do
    xs <- readIORef (dbPersons db)
    return $ take limit $ drop offset xs

queryPersonById :: Database -> Int64 -> IO (Maybe Person)
queryPersonById db pid = do
    xs <- readIORef (dbPersons db)
    return $ listToMaybe $ filter (\p -> pId p == Just pid) xs

insertPerson :: Database -> Person -> IO Int64
insertPerson db p = do
    modifyIORef (dbPersons db) (p:)
    return $ maybe 0 id (pId p)

updatePerson :: Database -> Int64 -> Person -> IO ()
updatePerson db pid p = do
    modifyIORef (dbPersons db) (map (\x -> if pId x == Just pid then p else x))

deletePerson :: Database -> Int64 -> IO ()
deletePerson db pid = do
    modifyIORef (dbPersons db) (filter (\p -> pId p /= Just pid))

-- Goods
queryGoods :: Database -> Int -> Int -> IO [Goods]
queryGoods db limit offset = do
    xs <- readIORef (dbGoods db)
    return $ take limit $ drop offset xs

queryGoodsById :: Database -> Int64 -> IO (Maybe Goods)
queryGoodsById db gid = do
    xs <- readIORef (dbGoods db)
    return $ listToMaybe $ filter (\g -> gId g == Just gid) xs

insertGoods :: Database -> Goods -> IO Int64
insertGoods db g = do
    modifyIORef (dbGoods db) (g:)
    return $ maybe 0 id (gId g)

updateGoods :: Database -> Int64 -> Goods -> IO ()
updateGoods db gid g = do
    modifyIORef (dbGoods db) (map (\x -> if gId x == Just gid then g else x))

deleteGoods :: Database -> Int64 -> IO ()
deleteGoods db gid = do
    modifyIORef (dbGoods db) (filter (\g -> gId g /= Just gid))

-- Locations
queryLocations :: Database -> Int -> Int -> IO [Location]
queryLocations db limit offset = do
    xs <- readIORef (dbLocations db)
    return $ take limit $ drop offset xs

queryLocationById :: Database -> Int64 -> IO (Maybe Location)
queryLocationById db lid = do
    xs <- readIORef (dbLocations db)
    return $ listToMaybe $ filter (\l -> lId l == Just lid) xs

insertLocation :: Database -> Location -> IO Int64
insertLocation db l = do
    modifyIORef (dbLocations db) (l:)
    return $ maybe 0 id (lId l)

updateLocation :: Database -> Int64 -> Location -> IO ()
updateLocation db lid l = do
    modifyIORef (dbLocations db) (map (\x -> if lId x == Just lid then l else x))

deleteLocation :: Database -> Int64 -> IO ()
deleteLocation db lid = do
    modifyIORef (dbLocations db) (filter (\l -> lId l /= Just lid))

-- Bills
queryBills :: Database -> Int -> Int -> Maybe Int -> Maybe Int -> IO [Bill]
queryBills db limit offset _mtype _mperson = do
    xs <- readIORef (dbBills db)
    return $ take limit $ drop offset xs

queryBillById :: Database -> Int64 -> IO (Maybe Bill)
queryBillById db bid = do
    xs <- readIORef (dbBills db)
    return $ listToMaybe $ filter (\b -> bId b == Just bid) xs

queryBillLines :: Database -> Int64 -> IO [(Int64, Double)]
queryBillLines _db _bid = return []

insertBill :: Database -> Bill -> IO Int64
insertBill db b = do
    modifyIORef (dbBills db) (b:)
    return $ maybe 0 id (bId b)

postBill :: Database -> Int64 -> IO Bool
postBill _db _bid = return True

-- Stock
queryStock :: Database -> Maybe Int64 -> Maybe Int64 -> IO [Stock]
queryStock db mgid mlid = do
    xs <- readIORef (dbStock db)
    return $ case (mgid, mlid) of
        (Just gid, Just lid) -> filter (\s -> sGoodsId s == gid && sLocationId s == lid) xs
        (Just gid, Nothing)  -> filter (\s -> sGoodsId s == gid) xs
        (Nothing, Just lid)  -> filter (\s -> sLocationId s == lid) xs
        (Nothing, Nothing)   -> xs

reserveStock :: Database -> Int64 -> Int64 -> Double -> IO Bool
reserveStock _db _gid _lid _qty = return True
