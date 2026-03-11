-- | Database Mutations (Write operations)
module DAL.Mutations where

import           DAL.Types
import           Data.Int  (Int64)
import           Data.Text (Text)
import           Data.Time (Day)

-- | Create person
createPerson :: Person -> QueryResult Int64
createPerson _ = QuerySuccess 0

-- | Update person
updatePerson :: Person -> QueryResult ()
updatePerson _ = QuerySuccess ()

-- | Delete person
deletePerson :: Int64 -> QueryResult ()
deletePerson _ = QuerySuccess ()

-- | Create goods
createGoods :: Goods -> QueryResult Int64
createGoods _ = QuerySuccess 0

-- | Update goods
updateGoods :: Goods -> QueryResult ()
updateGoods _ = QuerySuccess ()

-- | Delete goods
deleteGoods :: Int64 -> QueryResult ()
deleteGoods _ = QuerySuccess ()

-- | Create bill
createBill :: Bill -> QueryResult Int64
createBill _ = QuerySuccess 0

-- | Update bill status
updateBillStatus :: Int64 -> Int -> QueryResult ()
updateBillStatus _ _ = QuerySuccess ()

-- | Post bill (accounting)
postBill :: Int64 -> QueryResult ()
postBill _ = QuerySuccess ()

-- | Add bill line
addBillLine :: BillLine -> QueryResult Int64
addBillLine _ = QuerySuccess 0

-- | Delete bill line
deleteBillLine :: Int64 -> QueryResult ()
deleteBillLine _ = QuerySuccess ()

-- | Create location
createLocation :: Location -> QueryResult Int64
createLocation _ = QuerySuccess 0

-- | Update stock
updateStock :: Int64 -> Int64 -> Double -> QueryResult ()
updateStock _ _ _ = QuerySuccess ()

-- | Reserve stock
reserveStock :: Int64 -> Int64 -> Double -> QueryResult ()
reserveStock _ _ _ = QuerySuccess ()

-- | Release stock
releaseStock :: Int64 -> Int64 -> Double -> QueryResult ()
releaseStock _ _ _ = QuerySuccess ()

-- | Create order
createOrder :: Order -> QueryResult Int64
createOrder _ = QuerySuccess 0

-- | Update order status
updateOrderStatus :: Int64 -> Int -> QueryResult ()
updateOrderStatus _ _ = QuerySuccess ()

-- | Create payment
createPayment :: Payment -> QueryResult Int64
createPayment _ = QuerySuccess 0

-- | Create user
createUser :: User -> QueryResult Int64
createUser _ = QuerySuccess 0

-- | Update user
updateUser :: User -> QueryResult ()
updateUser _ = QuerySuccess ()

-- | Authenticate user
authenticateUser :: Text -> Text -> QueryResult (Maybe User)
authenticateUser _ _ = QuerySuccess Nothing
