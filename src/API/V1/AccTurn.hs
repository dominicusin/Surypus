-- ============================================================================
-- API V1 - AccTurn
-- Accrual Turn endpoints (pilot placeholder)
-- ============================================================================

module API.V1.AccTurn (accTurnAPI) where

import           DAL.Types          (AccTurnInput (..))
import           Data.Aeson         (Value, encode, object, (.=))
import qualified Data.Aeson         as A
import           Data.Text          (Text)
import qualified Data.Text          as T
import           Servant
import           Surypus.Validation (ValidationError (..), validateAccTurnInput)

-- | AccTurn API (placeholder; uses Input type validation)
accTurnAPI :: a -> API
accTurnAPI _ = "acc_turns" :> (getAccTurns :<|> postAccTurn)

getAccTurns :: Handler Value
getAccTurns = pure $ object ["status" .= ("ok" :: Text)]

postAccTurn :: Value -> Handler Value
postAccTurn input = case (A.fromJSON input :: A.Result AccTurnInput) of
  A.Success acc -> case validateAccTurnInput acc of
    Left errs -> do
      let errMsgs = T.intercalate ", " (fmap (\(ValidationError t) -> t) errs)
      throwError err400 {errBody = encode $ object ["error" .= errMsgs]}
    Right _ -> pure $ object ["status" .= ("ok" :: Text)]
  A.Error err -> throwError err400 {errBody = encode $ object ["error" .= (T.pack (show err))]}
