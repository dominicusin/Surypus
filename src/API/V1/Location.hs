-- ============================================================================
-- API V1 - Location
-- Lightweight Location endpoints (skeleton for validation coverage)
-- ============================================================================

module API.V1.Location (locationAPI) where

import           DAL.Types          (LocationInput (..))
import           Data.Aeson         (FromJSON, ToJSON, Value, encode, object,
                                     (.=))
import qualified Data.Aeson         as A
import           Data.Int           (Int64)
import           Data.Text          (Text)
import qualified Data.Text          as T
import           Servant
import           Surypus.Validation (ValidationError (..),
                                     validateLocationInput)

-- | Location API
locationAPI :: a -> API
locationAPI _svc =
  "locations" :> (getLocations :<|> createLocation)
  where
    getLocations :: Handler [Value]
    getLocations = return []

    createLocation :: Value -> Handler Value
    createLocation input = do
      -- Validate input using LocationInput and validator
      case (A.fromJSON input :: A.Result LocationInput) of
        A.Success locInput -> case validateLocationInput locInput of
          Left errs -> do
            let errMsgs = T.intercalate ", " (fmap (\(ValidationError t) -> t) errs)
            throwError err400 {errBody = encode $ object ["error" .= errMsgs]}
          Right _ -> do
            let newId = 1 :: Int64
            pure $ object ["location_id" .= newId, "name" .= liName locInput]
        A.Error err -> throwError err400 {errBody = encode $ object ["error" .= (T.pack (show err))]}
