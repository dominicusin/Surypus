module Surypus.DB.Queries where

import Data.Text (Text)
import Data.Time (UTCTime)
import Surypus.API.Types
import Surypus.DB.Schema

fetchSyncUpdates :: UTCTime -> Text -> IO ([ApiPerson], [ApiGood])
fetchSyncUpdates _ _ = pure ([], [])

data StockError = GoodNotFound Int | InsufficientStock Int Rational Rational
  deriving (Show)

deductStockTx :: GoodId -> Rational -> IO (Either StockError ())
deductStockTx _ _ = pure (Right ())
