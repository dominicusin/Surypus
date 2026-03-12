{-# LANGUAGE OverloadedStrings #-}

module DAL.Queries where

import DAL.Types
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (Day)
import Data.Time.Calendar (fromGregorian)
import qualified Hasql.Decoders as D
import qualified Hasql.Encoders as E
import Hasql.Pool (Pool, use)
import qualified Hasql.Session as Session
import Hasql.Statement (preparable)

-- Row decoders (example for Person)
personRowDecoder :: D.Row Person
personRowDecoder =
  Person
    <$> D.column (D.nonNullable D.int8) -- pId
    <*> D.column (D.nullable D.text) -- pCode
    <*> D.column (D.nonNullable D.text) -- pName
    <*> D.column (D.nullable D.text) -- pINN
    <*> D.column (D.nullable D.text) -- pKPP
    <*> D.column (D.nonNullable D.int4) -- pPersonType
    <*> D.column (D.nonNullable D.int4) -- pStatus

getPersons :: Pool -> IO (QueryResult [Person])
getPersons pool = do
  let stmt =
        preparable
          "SELECT id, code, name, inn, kpp, person_type, status FROM person ORDER BY id"
          E.noParams
          (D.rowList personRowDecoder)
  res <- use pool $ Session.statement () stmt
  case res of
    Right rows -> return $ QuerySuccess rows
    Left err -> return $ QueryError (T.pack $ show err)

getPersonById :: Pool -> Int64 -> IO (QueryResult Person)
getPersonById pool pid = do
  let stmt =
        preparable
          "SELECT id, code, name, inn, kpp, person_type, status FROM person WHERE id = $1"
          (E.param (E.nonNullable E.int8))
          (D.rowMaybe personRowDecoder)
  res <- use pool $ Session.statement pid stmt
  case res of
    Right (Just p) -> return $ QuerySuccess p
    Right Nothing -> return $ QueryError "Not Found"
    Left err -> return $ QueryError (T.pack $ show err)

-- Minimal placeholders for the rest, real implementation to follow in later patches
getGoods :: Pool -> IO (QueryResult [Goods])
getGoods _ = return $ QuerySuccess []

getGoodsById :: Pool -> Int64 -> IO (QueryResult Goods)
getGoodsById _ _ = return $ QuerySuccess $ Goods 0 Nothing (T.pack "Not Found") Nothing 0 Nothing

getGoodsByBarcode :: Pool -> Text -> IO (QueryResult Goods)
getGoodsByBarcode _ _ = return $ QuerySuccess $ Goods 0 Nothing (T.pack "Not Found") Nothing 0 Nothing

getLocations :: Pool -> IO (QueryResult [Location])
getLocations _ = return $ QuerySuccess []

getBills :: Pool -> IO (QueryResult [Bill])
getBills _ = return $ QuerySuccess []

getBillById :: Pool -> Int64 -> IO (QueryResult Bill)
getBillById _ _ = return $ QuerySuccess $ Bill 0 Nothing 0 0 (fromGregorian 1970 1 1) Nothing Nothing 0 0 0

getStock :: Pool -> Int64 -> Int64 -> IO (QueryResult Stock)
getStock _ _ _ = return $ QuerySuccess $ Stock 0 0 0 0 0

getStockByLocation :: Pool -> Int64 -> IO (QueryResult [Stock])
getStockByLocation _ _ = return $ QuerySuccess []

getStockByGoods :: Pool -> Int64 -> IO (QueryResult [Stock])
getStockByGoods _ _ = return $ QuerySuccess []

getUsers :: Pool -> IO (QueryResult [User])
getUsers _ = return $ QuerySuccess []

getDashboardStats :: Pool -> IO (QueryResult DashboardStats)
getDashboardStats _ = return $ QuerySuccess $ DashboardStats 0 0 0 0
