-- ============================================================================
-- API V1 - Currency
-- Simple currency endpoint (pilot placeholder)
-- ============================================================================

module API.V1.Currency (currencyAPI) where

import           DAL.Types          (CurrencyInput (..))
import           Data.Aeson         (Value, encode, object, (.=))
import qualified Data.Aeson         as A
import           Data.Int           (Int64)
import           Data.Text          (Text)
import qualified Data.Text          as T
import           Servant
import           Surypus.Validation (ValidationError (..),
                                     validateCurrencyInput)

-- | Currency API (placeholder)
currencyAPI :: a -> API
currencyAPI _ = "currency" :> (getCurrency :<|> postCurrency)

getCurrency :: Handler Value
getCurrency = pure $ object ["rate" .= (1.0 :: Double)]

postCurrency :: Value -> Handler Value
postCurrency input = case (A.fromJSON input :: A.Result CurrencyInput) of
  A.Success curr -> case validateCurrencyInput curr of
    Left errs -> do
      let errMsgs = T.intercalate ", " (fmap (\(ValidationError x) -> x) errs)
      throwError err400 {errBody = encode $ object ["error" .= errMsgs]}
    Right _ -> pure $ object ["validated" .= True]
  A.Error err -> throwError err400 {errBody = encode $ object ["error" .= (T.pack (show err))]}
