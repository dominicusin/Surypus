-- ============================================================================
-- API V1 - Tax
-- Simple Tax endpoints (pilot placeholder)
-- ============================================================================

module API.V1.Tax (taxAPI) where

import           DAL.Types          (TaxInput (..))
import           Data.Aeson         (Value, encode, object, (.=))
import qualified Data.Aeson         as A
import           Data.Int           (Int64)
import           Data.Text          (Text)
import qualified Data.Text          as T
import           Servant
import           Surypus.Validation (ValidationError (..), validateTaxInput)

-- | Tax API (placeholder)
taxAPI :: a -> API
taxAPI _ = "tax" :> (getTax :<|> postTax)

getTax :: Handler Value
getTax = pure $ object ["rate" .= (0.0 :: Double)]

postTax :: Value -> Handler Value
postTax input = case (A.fromJSON input :: A.Result TaxInput) of
  A.Success tax -> case validateTaxInput tax of
    Left errs -> do
      let errMsgs = T.intercalate ", " (fmap (\(ValidationError x) -> x) errs)
      throwError err400 {errBody = encode $ object ["error" .= errMsgs]}
    Right _ -> pure $ object ["validated" .= True]
  A.Error err -> throwError err400 {errBody = encode $ object ["error" .= (T.pack (show err))]}
