-- ============================================================================
-- API V1 - Orders
-- Simple orders endpoints (pilot placeholder)
-- ============================================================================

-- ============================================================================
-- API V1 - Orders
-- Orders endpoints (pilot with input validation)
-- ============================================================================

module API.V1.Orders (ordersAPI) where

import           DAL.Types          (OrderInput (..))
import           Data.Aeson         (FromJSON, Value, encode, object, (.=))
import           Data.Aeson         as A
import           Data.Int           (Int64)
import           Data.Text          (Text)
import           Data.Text          as T
import           Servant
import           Surypus.Validation (ValidationError (..), validateOrderInput)

-- | Orders API (placeholder)
ordersAPI :: a -> API
ordersAPI _ = "orders" :> (getOrders :<|> createOrder)

getOrders :: Handler Value
getOrders = pure $ object ["status" .= ("ok" :: Text)]

createOrder :: Value -> Handler Value
createOrder input = case (A.fromJSON input :: A.Result OrderInput) of
  A.Success ord -> case validateOrderInput ord of
    Left errs -> do
      let errMsgs = T.intercalate ", " (fmap (\(ValidationError x) -> x) errs)
      throwError err400 {errBody = encode $ object ["error" .= errMsgs]}
    Right _ -> pure $ object ["order_id" .= (1 :: Int64)]
  A.Error err -> throwError err400 {errBody = encode $ object ["error" .= (T.pack (show err))]}
