-- ============================================================================
-- API V1 - Bills
-- Lightweight Bills API endpoints with authentication
-- ============================================================================

-- ============================================================================
-- API V1 - Bills
-- Billing endpoints
-- ============================================================================
module API.V1.Bills (billAPI) where

import Control.Monad.IO.Class (MonadIO (..))
import DAL.Types (BillInput (..))
import Data.Aeson (FromJSON, ToJSON, Value, encode, fromJSON, object, (.=))
import qualified Data.Aeson as A
import Data.Aeson.Types (Result (..))
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Servant
import Service.Auth (HasJWT, requireJWT, requirePerm)
import qualified Service.BillService as BS
import Surypus.Validation (ValidationError (..), validateBillInput)

-- | Bills API (with auth per endpoint)
billAPI :: BS.BillService -> API
billAPI svc =
  "bills"
    :> capture "id" Int64
    :> ( ( requireJWT
             :. requirePerm "BillRead"
             :. getBillLines svc
             :<|> requireJWT
             :. requirePerm "BillWrite"
             :. postBill svc
         )
           :<|> requireJWT
           :. requirePerm "BillPost"
           :. postBillEndpoint svc
       )
  where
    getBillLines :: BS.BillService -> Int64 -> Handler [Text]
    getBillLines s bid = liftIO $ BS.listBillLines s bid

    postBill :: BS.BillService -> Int64 -> Value -> Handler Value
    postBill s bid input = do
      -- Attempt to validate input using DAL.BillInput and Surypus.Validation
      case (A.fromJSON input :: A.Result BillInput) of
        A.Success billInput -> case validateBillInput billInput of
          Left errs -> do
            let errMsgs = T.intercalate ", " (fmap (\(ValidationError t) -> t) errs)
            throwError err400 {errBody = encode $ object ["error" .= errMsgs]}
          Right _ -> do
            result <- liftIO $ BS.addBillLine s bid input
            case result of
              Right lid -> pure $ object ["line_id" .= lid]
              Left err -> throwError err500 {errBody = encode err}
        A.Error err -> throwError err400 {errBody = encode $ object ["error" .= (T.pack err)]}

    postBillEndpoint :: BS.BillService -> Int64 -> Handler Value
    postBillEndpoint s bid = do
      result <- liftIO $ BS.postBill s bid
      case result of
        Right () -> do
          -- Placeholder: status unknown in placeholder DB layer
          pure $ object ["id" .= bid, "status" .= (0 :: Int)]
        Left err -> throwError err500 {errBody = encode err}

-- | Bills with full permission stack
billPermAPI :: BS.BillService -> API
billPermAPI svc = requireJWT :. requirePerm "BillWrite" :> billAPI svc

server :: BS.BillService -> Server (billPermAPI BS.BillService)
server = billServer
  where
    billServer = serverFor (Proxy :: Proxy (billPermAPI BS.BillService))

app :: BS.BillService -> Application
app svc = serveWithContext (Proxy :: Proxy (billPermAPI BS.BillService)) ctx (server svc)
  where
    ctx = ()

runOnPort :: Int -> BS.BillService -> IO ()
runOnPort port svc = do
  let cfg = setPort port defaultServConfig
  runSettings cfg $ app svc
