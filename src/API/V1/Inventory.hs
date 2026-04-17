-- ============================================================================
-- API V1 - Inventory
-- Inventory endpoints and management helpers
-- ============================================================================

module API.V1.Inventory (inventoryAPI) where

import Control.Monad.IO.Class (MonadIO (..))
import DAL.Types (InventoryInput (..))
import Data.Aeson (Value, encode, object, (.=))
import qualified Data.Aeson as A
import Data.Aeson.Types (Result (..))
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Servant
import Service.Auth (HasJWT, requireJWT, requirePerm)
import qualified Service.InventoryService as IS
import Surypus.Validation (ValidationError (..), validateInventoryInput)

-- | Inventory Documents API
inventoryAPI :: IS.InventoryService -> API
inventoryAPI svc =
  "inventory" :> (getAllInv :<|> createInv)
    :<|> "inventory"
      :> capture "id" Int64
      :> (getInv :<|> postInv)
  where
    getAllInv :: Handler [Value]
    getAllInv = do
      result <- liftIO $ IS.listInventoryDocuments svc
      return $ map (\d -> object ["id" .= (1 :: Int64), "type" .= ("document" :: Text)]) result

    createInv :: Value -> Handler Value
    createInv input = do
      case (A.fromJSON input :: Result InventoryInput) of
        A.Success invInput -> case validateInventoryInput invInput of
          Left errs -> do
            let errMsgs = T.intercalate ", " (fmap (\(ValidationError x) -> x) errs)
            throwError err400 {errBody = encode $ object ["error" .= errMsgs]}
          Right _ -> do
            -- Placeholder path: process stock receipt using validated input
            result <- liftIO $ IS.processStockReceipt svc (iiGoodsId invInput) (iiLocationId invInput) (iiQty invInput)
            case result of
              Right rid -> pure $ object ["receipt_id" .= rid]
              Left _ -> throwError err500 {errBody = encode "Inventory processing error"}
        A.Error err -> throwError err400 {errBody = encode $ object ["error" .= (T.pack (show err))]}

    getInv :: Int64 -> Handler Value
    getInv id = do
      result <- liftIO $ IS.getInventoryDocument svc id
      case result of
        Right doc -> return $ object ["id" .= id, "status" .= ("created" :: Text)]
        Left err -> throwError err404

    postInv :: Int64 -> Handler Value
    postInv id = do
      result <- liftIO $ IS.postInventoryDocument svc id
      case result of
        Right () -> return $ object ["status" .= ("posted" :: Text)]
        Left err -> throwError err500 {errBody = encode err}

-- | Inventory with permissions
inventoryPermAPI :: IS.InventoryService -> API
inventoryPermAPI svc = requireJWT :. requirePerm "InventoryWrite" :> inventoryAPI svc

server :: IS.InventoryService -> Server (inventoryPermAPI IS.InventoryService)
server svc = inventoryServer svc
  where
    inventoryServer = serverFor (Proxy :: Proxy (inventoryPermAPI IS.InventoryService))

app :: IS.InventoryService -> Application
app svc = serveWithContext (Proxy :: Proxy (inventoryPermAPI IS.InventoryService)) ctx (server svc)
  where
    ctx = ()

runOnPort :: Int -> IS.InventoryService -> IO ()
runOnPort port svc = do
  let cfg = setPort port defaultServConfig
  runSettings cfg $ app svc
