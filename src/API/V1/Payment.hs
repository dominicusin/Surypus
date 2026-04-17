-- ============================================================================
-- API V1 - Payment
-- Simple payment endpoints (pilot placeholder)
-- ============================================================================

module API.V1.Payment (paymentAPI) where

import DAL.Types (PaymentInput (..))
import Data.Aeson (Value, encode, object, (.=))
import qualified Data.Aeson as A
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Servant
import Surypus.Validation (ValidationError (..), validatePaymentInput)

-- | Payment API (placeholder)
paymentAPI :: a -> API
paymentAPI _ = "payments" :> (getPayments :<|> postPayment)

getPayments :: Handler Value
getPayments = pure $ object ["status" .= ("ok" :: Text)]

postPayment :: Value -> Handler Value
postPayment input = case (A.fromJSON input :: A.Result PaymentInput) of
  A.Success p -> case validatePaymentInput p of
    Left errs -> do
      let errMsgs = T.intercalate ", " (map (\(ValidationError x) -> x) errs)
      throwError err400 {errBody = encode $ object ["error" .= errMsgs]}
    Right _ -> pure $ object ["payment_id" .= (1 :: Int64)]
  A.Error err -> throwError err400 {errBody = encode $ object ["error" .= (T.pack (show err))]}
