-- | Currency API
module Surypus.API.Currency
  ( listCurrencies,
    getCurrency,
  )
where

import qualified DAL.Queries as Q
import DAL.Types
  ( Currency (..),
    QueryResult (..),
  )
import Data.Int (Int64)
import Hasql.Pool (Pool)

listCurrencies :: Pool -> IO (QueryResult [Currency])
listCurrencies = Q.getCurrencies

getCurrency :: Pool -> Int64 -> IO (QueryResult Currency)
getCurrency = Q.getCurrencyById
