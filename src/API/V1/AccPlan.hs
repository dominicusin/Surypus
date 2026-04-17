-- ============================================================================
-- API V1 - AccPlan
-- Accrual Plans endpoints (pilot with validation)
-- ============================================================================

module API.V1.AccPlan (accPlanAPI) where

import           DAL.Types          (AccPlanInput (..))
import           Data.Aeson         (Value, encode, object, (.=))
import qualified Data.Aeson         as A
import           Data.Int           (Int64)
import           Data.Text          (Text)
import qualified Data.Text          as T
import           Servant
import           Surypus.Validation (ValidationError (..), validateAccPlanInput)

-- | AccPlan API (placeholder)
accPlanAPI :: a -> API
accPlanAPI _ = "acc_plans" :> (getPlans :<|> postPlan)

getPlans :: Handler Value
getPlans = pure $ object ["plans" .= ([] :: [Value])]

postPlan :: Value -> Handler Value
postPlan input = case (A.fromJSON input :: A.Result AccPlanInput) of
  A.Success acc -> case validateAccPlanInput acc of
    Left errs -> do
      let errMsgs = T.intercalate ", " (fmap (\(ValidationError x) -> x) errs)
      throwError err400 {errBody = encode $ object ["error" .= errMsgs]}
    Right _ -> pure $ object ["acc_plan_id" .= (1 :: Int64)]
  A.Error err -> throwError err400 {errBody = encode $ object ["error" .= (T.pack (show err))]}
