module Surypus.Domain.Stock where

import Database.Persist.Sql
import Surypus.DB.Queries
import Surypus.DB.Schema

deductStock :: GoodId -> Rational -> IO (Either StockError ())
deductStock = deductStockTx
