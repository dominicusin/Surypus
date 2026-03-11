-- | Database Queries
module DAL.Queries where

import           DAL.Types
import           Data.Int  (Int64)
import           Data.Text (Text)
import qualified Data.Text as T

-- | Get all persons
getPersons :: QueryResult [Person]
getPersons = QuerySuccess []

-- | Get person by ID
getPersonById :: Int64 -> QueryResult Person
getPersonById _ = QuerySuccess (Person 0 Nothing (T.pack "Person") Nothing Nothing 0 0)

-- | Get person by code
getPersonByCode :: Text -> QueryResult Person
getPersonByCode _ = QuerySuccess (Person 0 Nothing (T.pack "Person") Nothing Nothing 0 0)

-- | Get all goods
getGoods :: QueryResult [Goods]
getGoods = QuerySuccess []

-- | Get goods by ID
getGoodsById :: Int64 -> QueryResult Goods
getGoodsById _ = QuerySuccess (Goods 0 Nothing (T.pack "Goods") Nothing 0 Nothing)

-- | Get goods by barcode
getGoodsByBarcode :: Text -> QueryResult Goods
getGoodsByBarcode _ = QuerySuccess (Goods 0 Nothing (T.pack "Goods") Nothing 0 Nothing)

-- | Search goods
searchGoods :: Text -> QueryResult [Goods]
searchGoods _ = QuerySuccess []

-- | Get all bills
getBills :: QueryResult [Bill]
getBills = QuerySuccess []

-- | Get bill by ID
getBillById :: Int64 -> QueryResult Bill
getBillById _ = QuerySuccess (Bill 0 Nothing 0 0 undefined Nothing Nothing 0 0 0)

-- | Get bill lines
getBillLines :: Int64 -> QueryResult [BillLine]
getBillLines _ = QuerySuccess []

-- | Get all locations
getLocations :: QueryResult [Location]
getLocations = QuerySuccess []

-- | Get stock by goods and location
getStock :: Int64 -> Int64 -> QueryResult Stock
getStock _ _ = QuerySuccess (Stock 0 0 0 0 0)

-- | Get stock for location
getStockByLocation :: Int64 -> QueryResult [Stock]
getStockByLocation _ = QuerySuccess []

-- | Get stock for goods
getStockByGoods :: Int64 -> QueryResult [Stock]
getStockByGoods _ = QuerySuccess []

-- | Get all accounts
getAccPlans :: QueryResult [AccPlan]
getAccPlans = QuerySuccess []

-- | Get accounting turns
getAccTurns :: Maybe Int64 -> QueryResult [AccTurn]
getAccTurns _ = QuerySuccess []

-- | Get users
getUsers :: QueryResult [User]
getUsers = QuerySuccess []

-- | Get orders
getOrders :: QueryResult [Order]
getOrders = QuerySuccess []

-- | Get payments
getPayments :: Int64 -> QueryResult [Payment]
getPayments _ = QuerySuccess []

-- | Get dashboard stats
getDashboardStats :: QueryResult DashboardStats
getDashboardStats = QuerySuccess DashboardStats
  { dsRevenueToday = 0
  , dsOrdersToday = 0
  , dsGoodsCount = 0
  , dsClientsCount = 0
  }

-- | Dashboard statistics
data DashboardStats = DashboardStats
  { dsRevenueToday :: Double
  , dsOrdersToday  :: Int
  , dsGoodsCount   :: Int
  , dsClientsCount :: Int
  } deriving (Show, Eq)
