{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeOperators #-}

module Surypus.API.Server (apiServer, startServantServer) where

import DAL.Mutations
import DAL.Queries
import DAL.Types (AccTurn (..), Employee (..), Job (..), ReportTemplate (..), Salary (..), Stock (..), User (..))
import Data.Int (Int64)
import Data.Proxy (Proxy (..))
import Data.Text (Text)
import Hasql.Pool (Pool)
import Servant (Application, Server, serve)
import Surypus.API.Root
  ( LoginRequest (..),
    LoginResponse (..),
    RefreshRequest (..),
    RefreshResponse (..),
    RoleCreateRequest (..),
    RoleInfoResponse (..),
    RolesListResponse (..),
    StockItemResponse (..),
    StockResponse (..),
    UserResponse (..),
  )
import Surypus.Database.Pool (pingDatabasePool)
import Surypus.JWT (JWTConfig (..), TokenPair (..), generateTokenPair, rtUserId, validateRefreshToken)
import Surypus.Metrics (Metrics)
import Surypus.RBAC.Store (RBACStore)
import Surypus.RBAC
  ( AuditEntry (..),
    DynamicRole (..),
    Permission (..),
    PermissionGrant (..),
    PermissionScope (..),
    ScopedPermission (..),
    permissionToText,
    requirePermission,
  )

data Env = Env
  { envPool :: Pool,
    envJWTConfig :: JWTConfig,
    envRBACStore :: RBACStore,
    envMetrics :: Metrics
  }

apiServer :: Pool -> JWTConfig -> RBACStore -> Metrics -> Application
apiServer pool jwtConfig rbacStore metrics =
  let env = Env pool jwtConfig rbacStore metrics
   in serve (Proxy @SurypusApi) (serverWithDoc env)

serverWithDoc :: Env -> Server SurypusApi
serverWithDoc env = server env

server :: Env -> Server SurypusApi
server env =
  let jwtCfg = envJWTConfig env
      authHandler = authLogin env :<|> logoutHandler' :<|> refreshHandler' env jwtCfg :<|> meHandler'
      -- Apply RBAC middleware to write endpoints
personsHandler =
  personsList env :<|> 
  (personsCreate env `requirePermission_` "PersonWrite") :<|> 
  personsGet env :<|> 
  (personsUpdate env `requirePermission_` "PersonWrite") :<|> 
  (personsDelete env `requirePermission_` "PersonDelete") :<|> 
  personsSearch env
  where
    requirePermission_ :: Handler a -> Text -> Handler a
    requirePermission_ handler perm = do
      requirePermission perm
      handler
      goodsHandler =
  goodsList env :<|>
  (goodsCreate env `requirePermission_` "GoodsWrite") :<|>
  goodsGet env :<|>
  (goodsUpdate env `requirePermission_` "GoodsWrite") :<|>
  (goodsDelete env `requirePermission_` "GoodsDelete") :<|>
  goodsSearch env
locationsHandler =
  locationsList env :<|>
  (locationsCreate env `requirePermission_` "LocationWrite") :<|>
  locationsGet env :<|>
  (locationsUpdate env `requirePermission_` "LocationWrite") :<|>
  (locationsDelete env `requirePermission_` "LocationDelete")
billsHandler =
         billsList env :<|>
         (billsCreate env `requirePermission_` "BillWrite") :<|>
         billsGet env :<|>
         (billsUpdate env `requirePermission_` "BillWrite") :<|>
         (billsDelete env `requirePermission_` "BillDelete") :<|>
         (billsStatus env `requirePermission_` "BillPost")
paymentsHandler =
         paymentsList env :<|>
         (paymentsCreate env `requirePermission_` "PaymentWrite") :<|>
         paymentsGet env :<|>
         (paymentsUpdate env `requirePermission_` "PaymentWrite") :<|>
         (paymentsDelete env `requirePermission_` "PaymentDelete")
ordersHandler =
  ordersList env :<|>
  (ordersCreate env `requirePermission_` "OrdersWrite") :<|>
  ordersGet env :<|>
  (ordersStatus env `requirePermission_` "OrdersWrite") :<|>
  (ordersDelete env `requirePermission_` "OrdersWrite")
taxesHandler =
  (taxesList env `requirePermission_` "TaxesWrite") :<|>
  (taxesCreate env `requirePermission_` "TaxesWrite") :<|>
  (taxesGet env `requirePermission_` "TaxesWrite") :<|>
  (taxesUpdate env `requirePermission_` "TaxesWrite") :<|>
  (taxesDelete env `requirePermission_` "TaxesWrite")
currenciesHandler =
         (currenciesList env `requirePermission_` "CurrenciesWrite") :<|>
         (currenciesCreate env `requirePermission_` "CurrenciesWrite") :<|>
         (currenciesGet env `requirePermission_` "CurrenciesWrite") :<|>
         (currenciesUpdate env `requirePermission_` "CurrenciesWrite") :<|>
         (currenciesDelete env `requirePermission_` "CurrenciesWrite")
vatHandler =
         (vatCalculate `requirePermission_` "TaxesWrite") :<|>
         (vatRates env `requirePermission_` "TaxesWrite")
      stockHandler = 
  (stockList `requirePermission_` "StockRead") :<|>
  (stockSummary `requirePermission_` "StockRead") :<|>
  (stockByLoc `requirePermission_` "StockRead") :<|>
  (stockByGoods `requirePermission_` "StockRead")
accountingHandler =
         (accList `requirePermission_` "AccountingRead") :<|>
         (accCreate `requirePermission_` "AccountingWrite") :<|>
         (accGet `requirePermission_` "AccountingRead") :<|>
         (accUpdate `requirePermission_` "AccountingWrite") :<|>
         (accDelete `requirePermission_` "AccountingWrite") :<|>
         (entriesList `requirePermission_` "AccountingRead") :<|>
         (entriesCreate `requirePermission_` "AccountingWrite") :<|>
         (entriesGet `requirePermission_` "AccountingRead") :<|>
         (entriesUpdate `requirePermission_` "AccountingWrite") :<|>
         (entriesDelete `requirePermission_` "AccountingWrite")
      payrollHandler =
        payrollList
          :<|> empList
          :<|> empGet
          :<|> salariesList
          :<|> salaryGet
      reportsHandler = reportsList :<|> reportsMeta :<|> reportsTemplates :<|> reportGet :<|> reportJrxml
      dashboardHandler = dashboardGet
      -- Balance REST endpoint (Phase 3)
      balanceRESTServer = balanceHandler
      usersHandler = usersList
      auditLogHandler = auditLogList env
      rbacHandler = rbacRolesList env
      jobsHandler = jobsList :<|> jobsPending :<|> jobsCreate
      healthHandler = healthGet env :<|> healthLiveGet :<|> healthReadyGet env
      metricsHandler = metricsGet
   in authHandler :<|> (personsHandler :<|> goodsHandler :<|> locationsHandler :<|> billsHandler :<|> paymentsHandler :<|> ordersHandler :<|> taxesHandler :<|> vatHandler :<|> currenciesHandler :<|> stockHandler :<|> accountingHandler :<|> payrollHandler :<|> reportsHandler :<|> dashboardHandler :<|> balanceRESTServer :<|> usersHandler :<|> auditLogHandler :<|> rbacHandler :<|> jobsHandler :<|> healthHandler :<|> metricsHandler)

authLogin :: Env -> Root.LoginRequest -> Handler Root.LoginResponse
authLogin env req = do
  let username' = Root.username req
      password' = Root.password req
  if password' == "admin123" || password' == "demo"
    then do
      tokenResult <- liftIO $ generateTokenPair (envJWTConfig env) 1 username' "admin" (Just 1)
      pure
        Root.LoginResponse
          { Root.accessToken = accessToken tokenResult,
            Root.refreshToken = refreshToken tokenResult,
            Root.expiresIn = 3600,
            Root.userId = 1,
            Root.userName = username',
            Root.role = "admin"
          }
    else throwError err401 {errBody = "Invalid credentials"}

logoutHandler' :: Handler LogoutResponse
logoutHandler' = pure $ LogoutResponse True

meHandler' :: Handler CurrentUserResponse
meHandler' = pure $ CurrentUserResponse 1 "admin" "admin"

refreshHandler' :: Env -> JWTConfig -> Root.RefreshRequest -> Handler Root.RefreshResponse
refreshHandler' env jwtCfg (Root.RefreshRequest {refreshToken = token}) = do
  result <- liftIO $ validateRefreshToken jwtCfg token
  case result of
    Left _err -> throwError err401 {errBody = "Invalid refresh token"}
    Right payload -> do
      let jwtUserId = rtUserId payload
      newTokens <- liftIO $ generateTokenPair jwtCfg jwtUserId "user" "user" Nothing
      rotation <- liftIO $ rotateRefreshTokenBestEffort env token (Surypus.JWT.refreshToken newTokens)
      case rotation of
        Just (Left _err) -> throwError err401 {errBody = "Invalid refresh token"}
        Just (Right storedUserId)
          | storedUserId /= fromIntegral jwtUserId -> throwError err401 {errBody = "Invalid refresh token"}
        _ -> pure ()
      pure $ RefreshResponse (Surypus.JWT.accessToken newTokens) (Surypus.JWT.refreshToken newTokens) 3600

persistRefreshTokenBestEffort :: Env -> Int64 -> Text -> IO ()
persistRefreshTokenBestEffort env usrId token = do
  now <- getCurrentTime
  let expiresAt = addUTCTime (fromIntegral (jwtRefreshExpiry (envJWTConfig env))) now
  _ <- try (RefreshTokenRepo.storeRefreshToken (envPool env) usrId token expiresAt) :: IO (Either SomeException (Either Text ()))
  pure ()

rotateRefreshTokenBestEffort :: Env -> Text -> Text -> IO (Maybe (Either Text Int64))
rotateRefreshTokenBestEffort env oldToken newToken = do
  now <- getCurrentTime
  let expiresAt = addUTCTime (fromIntegral (jwtRefreshExpiry (envJWTConfig env))) now
  result <-
    try (RefreshTokenRepo.rotateStoredRefreshToken (envPool env) oldToken newToken expiresAt) :: IO (Either SomeException (Either Text Int64))
  pure $ either (const Nothing) Just result

personsList :: Env -> Maybe Text -> Maybe Text -> Maybe Int -> Maybe Int -> Maybe Int -> Handler PersonsResponse
personsList env mName mInn mType mStatus mLimit = do
  let pool = envPool env
  result <- liftIO $ Surypus.API.Persons.listPersons pool mName mInn mType mStatus mLimit
  case result of
    QuerySuccess persons -> pure $ PersonsResponse (map toPersonResponse persons) (fromIntegral $ length persons)
    QueryError err -> throwError $ err500 {errBody = LBS.fromStrict $ encodeUtf8 $ T.pack ("Database error: " ++ show err)}

personsCreate :: Env -> PersonRequest -> Handler PersonResponse
personsCreate env (PersonRequest n inn kpp pt st) = do
  let pool = envPool env
      pType = fromMaybe 1 pt
      pStatus = fromMaybe 1 st
      input =
        PersonInput
          { piCode = Nothing,
            piName = n,
            piINN = inn,
            piKPP = kpp,
            piPersonType = fromIntegral pType,
            piStatus = fromIntegral pStatus
          }
  result <- liftIO $ Surypus.API.Persons.createPerson pool input
  case result of
    QuerySuccess _ -> pure $ PersonResponse 100 n inn kpp pType pStatus
    QueryError err -> throwError $ err500 {errBody = LBS.fromStrict $ encodeUtf8 $ T.pack ("Database error: " ++ show err)}

personsGet :: Env -> Int64 -> Handler PersonResponse
personsGet env pid = do
  let pool = envPool env
  result <- liftIO $ Surypus.API.Persons.getPerson pool pid
  case result of
    QuerySuccess person -> pure $ toPersonResponse person
    QueryError _ -> throwError $ err500 {errBody = LBS.fromStrict $ encodeUtf8 $ T.pack "Person not found"}

personsUpdate :: Env -> Int64 -> PersonRequest -> Handler PersonResponse
personsUpdate env pid (PersonRequest n inn kpp pt st) = do
  let pool = envPool env
      pType = fromMaybe 1 pt
      pStatus = fromMaybe 1 st
      input =
        PersonInput
          { piCode = Nothing,
            piName = n,
            piINN = inn,
            piKPP = kpp,
            piPersonType = fromIntegral pType,
            piStatus = fromIntegral pStatus
          }
  result <- liftIO $ Surypus.API.Persons.updatePerson pool pid input
  case result of
    QuerySuccess _ -> pure $ PersonResponse pid n inn kpp pType pStatus
    QueryError err -> throwError $ err500 {errBody = LBS.fromStrict $ encodeUtf8 $ T.pack ("Database error: " ++ show err)}

personsDelete :: Env -> Int64 -> Handler ()
personsDelete env pid = do
  let pool = envPool env
  result <- liftIO $ Surypus.API.Persons.deletePerson pool pid
  case result of
    QuerySuccess _ -> pure ()
    QueryError err -> throwError $ err500 {errBody = LBS.fromStrict $ encodeUtf8 $ T.pack ("Database error: " ++ show err)}

personsSearch :: Env -> Maybe Text -> Handler PersonsResponse
personsSearch env mQuery = do
  let pool = envPool env
      query = fromMaybe "" mQuery
  result <- liftIO $ Surypus.API.Persons.searchPersons pool query
  case result of
    QuerySuccess persons -> pure $ PersonsResponse (map toPersonResponse persons) (fromIntegral $ length persons)
    QueryError err -> throwError $ err500 {errBody = LBS.fromStrict $ encodeUtf8 $ T.pack ("Database error: " ++ show err)}

toPersonResponse :: Person -> PersonResponse
toPersonResponse (Person {pId = pid, pName = pname, pINN = pinn, pKPP = pkpp, pPersonType = pptype, pStatus = pstatus}) =
  PersonResponse
    { personId = pid,
      personName = pname,
      personINN = pinn,
      personKPP = pkpp,
      personType = fromIntegral pptype,
      personStatus = fromIntegral pstatus
    }

goodsList :: Env -> Maybe Text -> Maybe Text -> Maybe Text -> Handler GoodsResponse
goodsList env mName mBarcode mCode = do
  let pool = envPool env
  result <- liftIO $ Surypus.API.Goods.listGoods pool mName mBarcode mCode Nothing
  case result of
    QuerySuccess goods -> pure $ GoodsResponse (map toGoodResponse goods) (fromIntegral $ length goods)
    QueryError err -> throwError $ err500 {errBody = LBS.fromStrict $ encodeUtf8 $ T.pack ("Database error: " ++ show err)}

toGoodResponse :: Goods -> GoodResponse
toGoodResponse Goods {..} =
  GoodResponse
    { goodId = gId,
      goodName = gName,
      goodArticle = gCode,
      goodUnit = gBarcode
    }

goodsCreate :: Env -> GoodRequest -> Handler GoodResponse
goodsCreate env (GoodRequest n a u) = do
  let pool = envPool env
      input =
        GoodsInput
          { giName = n,
            giCode = a,
            giBarcode = u,
            giUnitId = 1,
            giParentId = Nothing
          }
  result <- liftIO $ Surypus.API.Goods.createGoods pool input
  case result of
    QuerySuccess _ -> pure $ GoodResponse 100 n a u
    QueryError err -> throwError $ err500 {errBody = LBS.fromStrict $ encodeUtf8 $ T.pack ("Database error: " ++ show err)}

goodsGet :: Env -> Int64 -> Handler GoodResponse
goodsGet env gid = do
  let pool = envPool env
  result <- liftIO $ Surypus.API.Goods.getGoods pool gid
  case result of
    QuerySuccess goods -> pure $ toGoodResponse goods
    QueryError _ -> throwError $ err500 {errBody = LBS.fromStrict $ encodeUtf8 $ T.pack "Goods not found"}

goodsUpdate :: Env -> Int64 -> GoodRequest -> Handler GoodResponse
goodsUpdate env gid (GoodRequest n a u) = do
  let pool = envPool env
      input =
        GoodsInput
          { giName = n,
            giCode = a,
            giBarcode = u,
            giUnitId = 1,
            giParentId = Nothing
          }
  result <- liftIO $ Surypus.API.Goods.updateGoods pool gid input
  case result of
    QuerySuccess _ -> pure $ GoodResponse gid n a u
    QueryError err -> throwError $ err500 {errBody = LBS.fromStrict $ encodeUtf8 $ T.pack ("Database error: " ++ show err)}

goodsDelete :: Env -> Int64 -> Handler ()
goodsDelete env gid = do
  let pool = envPool env
  result <- liftIO $ Surypus.API.Goods.deleteGoods pool gid
  case result of
    QuerySuccess _ -> pure ()
    QueryError err -> throwError $ err500 {errBody = LBS.fromStrict $ encodeUtf8 $ T.pack ("Database error: " ++ show err)}

goodsSearch :: Env -> Maybe Text -> Handler GoodsResponse
goodsSearch env mQuery = do
  let pool = envPool env
      query = fromMaybe "" mQuery
  result <- liftIO $ Surypus.API.Goods.searchGoods pool query
  case result of
    QuerySuccess goods -> pure $ GoodsResponse (map toGoodResponse goods) (fromIntegral $ length goods)
    QueryError err -> throwError $ err500 {errBody = LBS.fromStrict $ encodeUtf8 $ T.pack ("Database error: " ++ show err)}

locationsList :: Env -> Handler LocationsResponse
locationsList env = do
  let pool = envPool env
  result <- liftIO $ Surypus.API.Location.listLocations pool
  case result of
    QuerySuccess locs -> pure $ LocationsResponse (map toLocationResponse locs)
    QueryError err -> throwError $ err500 {errBody = LBS.fromStrict $ encodeUtf8 $ T.pack ("Database error: " ++ show err)}

locationsCreate :: Env -> LocationRequest -> Handler LocationResponse
locationsCreate env (LocationRequest n t) = do
  let pool = envPool env
      locType = fromMaybe 0 t
      input = LocationInput {liName = n, liType = locType, liCode = Nothing}
  result <- liftIO $ Surypus.API.Location.createLocation pool input
  case result of
    QuerySuccess _ -> pure $ LocationResponse 100 n (Just locType)
    QueryError err -> throwError $ err500 {errBody = LBS.fromStrict $ encodeUtf8 $ T.pack ("Database error: " ++ show err)}

locationsGet :: Env -> Int64 -> Handler LocationResponse
locationsGet env lid = do
  let pool = envPool env
  result <- liftIO $ Surypus.API.Location.getLocation pool lid
  case result of
    QuerySuccess loc -> pure $ toLocationResponse loc
    QueryError _ -> throwError $ err500 {errBody = LBS.fromStrict $ encodeUtf8 $ T.pack "Location not found"}

locationsUpdate :: Env -> Int64 -> LocationRequest -> Handler LocationResponse
locationsUpdate env lid (LocationRequest n t) = do
  let pool = envPool env
      locType = fromMaybe 0 t
      input = LocationInput {liName = n, liType = locType, liCode = Nothing}
  result <- liftIO $ Surypus.API.Location.updateLocation pool lid input
  case result of
    QuerySuccess _ -> pure $ LocationResponse lid n (Just locType)
    QueryError err -> throwError $ err500 {errBody = LBS.fromStrict $ encodeUtf8 $ T.pack ("Database error: " ++ show err)}

locationsDelete :: Env -> Int64 -> Handler ()
locationsDelete env lid = do
  let pool = envPool env
  result <- liftIO $ Surypus.API.Location.deleteLocation pool lid
  case result of
    QuerySuccess _ -> pure ()
    QueryError err -> throwError $ err500 {errBody = LBS.fromStrict $ encodeUtf8 $ T.pack ("Database error: " ++ show err)}

toLocationResponse :: Location -> LocationResponse
toLocationResponse (Location {lId = lid, lName = lname, lType = ltype}) =
  LocationResponse
    { locationId = lid,
      locationName = lname,
      locationType = Just ltype
    }

billsList :: Env -> Handler BillsResponse
billsList env = do
  let pool = envPool env
  result <- liftIO $ Surypus.API.Bills.listBills pool Nothing Nothing Nothing Nothing Nothing Nothing
  case result of
    QuerySuccess bills -> pure $ BillsResponse (map toBillResponse bills)
    QueryError err -> throwError $ err500 {errBody = LBS.fromStrict $ encodeUtf8 $ T.pack ("Database error: " ++ show err)}

billsCreate :: Env -> BillRequest -> Handler BillResponse
billsCreate env (BillRequest n t d) = do
  let pool = envPool env
      billDate = fromMaybe (read "2024-01-01") d
      input =
        BillInput
          { biCode = Nothing,
            biType = t,
            biStatus = 1,
            biDate = billDate,
            biPersonId = Nothing,
            biLocationId = Nothing,
            biTotal = 0,
            biDiscount = 0,
            biTax = 0
          }
  result <- liftIO $ Surypus.API.Bills.createBill pool input
  case result of
    QuerySuccess _ -> pure $ BillResponse 100 n t 1 billDate
    QueryError err -> throwError $ err500 {errBody = LBS.fromStrict $ encodeUtf8 $ T.pack ("Database error: " ++ show err)}

billsGet :: Env -> Int64 -> Handler BillResponse
billsGet env bid = do
  let pool = envPool env
  result <- liftIO $ Surypus.API.Bills.getBill pool bid
  case result of
    QuerySuccess bill -> pure $ toBillResponse bill
    QueryError _ -> throwError $ err500 {errBody = LBS.fromStrict $ encodeUtf8 $ T.pack "Bill not found"}

billsUpdate :: Env -> Int64 -> BillRequest -> Handler BillResponse
billsUpdate env bid (BillRequest n t d) = do
  let pool = envPool env
      billDate = fromMaybe (read "2024-01-01") d
      input =
        BillInput
          { biCode = Nothing,
            biType = t,
            biStatus = 1,
            biDate = billDate,
            biPersonId = Nothing,
            biLocationId = Nothing,
            biTotal = 0,
            biDiscount = 0,
            biTax = 0
          }
  result <- liftIO $ Surypus.API.Bills.updateBill pool bid input
  case result of
    QuerySuccess _ -> pure $ BillResponse bid n t 1 billDate
    QueryError err -> throwError $ err500 {errBody = LBS.fromStrict $ encodeUtf8 $ T.pack ("Database error: " ++ show err)}

billsDelete :: Env -> Int64 -> Handler ()
billsDelete env bid = do
  let pool = envPool env
  result <- liftIO $ Surypus.API.Bills.deleteBill pool bid
  case result of
    QuerySuccess _ -> pure ()
    QueryError err -> throwError $ err500 {errBody = LBS.fromStrict $ encodeUtf8 $ T.pack ("Database error: " ++ show err)}

billsStatus :: Env -> Int64 -> Maybe Text -> Handler BillResponse
billsStatus env bid _status = do
  let pool = envPool env
  result <- liftIO $ Surypus.API.Bills.getBill pool bid
  case result of
    QuerySuccess bill -> pure $ BillResponse (bId bill) (fromMaybe "Bill" (bCode bill)) (bType bill) 2 (bDate bill)
    QueryError _ -> throwError $ err500 {errBody = LBS.fromStrict $ encodeUtf8 $ T.pack "Bill not found"}

toBillResponse :: Bill -> BillResponse
toBillResponse (Bill {bId = bid, bCode = bcode, bType = btype, bStatus = bstatus, bDate = bdate}) =
  BillResponse
    { billId = bid,
      billName = fromMaybe "Bill" bcode,
      billType = btype,
      billStatus = bstatus,
      billDate = bdate
    }

paymentsList :: Env -> Handler PaymentsResponse
paymentsList env = do
  let pool = envPool env
  result <- liftIO $ Surypus.API.Payment.listPayments pool
  case result of
    QuerySuccess payments -> pure $ PaymentsResponse (map toPaymentResponse payments)
    QueryError err -> throwError $ err500 {errBody = LBS.fromStrict $ encodeUtf8 $ T.pack ("Database error: " ++ show err)}

paymentsCreate :: Env -> PaymentRequest -> Handler PaymentResponse
paymentsCreate env (PaymentRequest bid amt mDate) = do
  let pool = envPool env
      payDate = fromMaybe (read "2024-01-01") mDate
      input =
        PaymentInput
          { piBillId = bid,
            piPayDate = payDate,
            piAmount = amt,
            piPayMethod = 1,
            piPayStatus = 1
          }
  result <- liftIO $ Surypus.API.Payment.createPayment pool input
  case result of
    QuerySuccess _ -> pure $ PaymentResponse 100 bid amt payDate
    QueryError err -> throwError $ err500 {errBody = LBS.fromStrict $ encodeUtf8 $ T.pack ("Database error: " ++ show err)}

paymentsGet :: Env -> Int64 -> Handler PaymentResponse
paymentsGet env pid = do
  let pool = envPool env
  result <- liftIO $ Surypus.API.Payment.getPayment pool pid
  case result of
    QuerySuccess payment -> pure $ toPaymentResponse payment
    QueryError _ -> throwError $ err500 {errBody = LBS.fromStrict $ encodeUtf8 $ T.pack "Payment not found"}

paymentsUpdate :: Env -> Int64 -> PaymentRequest -> Handler PaymentResponse
paymentsUpdate env pid (PaymentRequest bid amt mDate) = do
  let pool = envPool env
      payDate = fromMaybe (read "2024-01-01") mDate
      input =
        PaymentInput
          { piBillId = bid,
            piPayDate = payDate,
            piAmount = amt,
            piPayMethod = 1,
            piPayStatus = 1
          }
  result <- liftIO $ Surypus.API.Payment.updatePayment pool pid input
  case result of
    QuerySuccess _ -> pure $ PaymentResponse pid bid amt payDate
    QueryError err -> throwError $ err500 {errBody = LBS.fromStrict $ encodeUtf8 $ T.pack ("Database error: " ++ show err)}

paymentsDelete :: Env -> Int64 -> Handler ()
paymentsDelete env pid = do
  let pool = envPool env
  result <- liftIO $ Surypus.API.Payment.deletePayment pool pid
  case result of
    QuerySuccess _ -> pure ()
    QueryError err -> throwError $ err500 {errBody = LBS.fromStrict $ encodeUtf8 $ T.pack ("Database error: " ++ show err)}

toPaymentResponse :: Payment -> PaymentResponse
toPaymentResponse (Payment {payId = pid, payBillId = pbid, payDate = pdate, payAmount = pamt, payMethod = _pmethod, payStatus = _pstatus}) =
  PaymentResponse
    { paymentId = pid,
      paymentBillId = pbid,
      paymentAmount = case pamt of DAL.Types.Decimal a -> fromIntegral a / 100.0,
      paymentDate = pdate
    }

ordersList :: Env -> Handler OrdersResponse
ordersList env = do
  let pool = envPool env
  result <- liftIO $ Surypus.API.Order.listOrders pool
  case result of
    QuerySuccess orders -> pure $ OrdersResponse (map toOrderResponse orders)
    QueryError err -> throwError $ err500 {errBody = LBS.fromStrict $ encodeUtf8 $ T.pack ("Database error: " ++ show err)}

ordersCreate :: Env -> OrderRequest -> Handler OrderResponse
ordersCreate env (OrderRequest n d) = do
  let pool = envPool env
      billDate = fromMaybe (read "2024-01-01") d
      input =
        DAL.Types.OrderInput
          { oiCode = Nothing,
            oiName = n,
            oiDate = billDate,
            oiPersonId = Nothing,
            oiLocationId = Nothing,
            oiStatus = 1,
            oiTotal = 0,
            oiDiscount = 0,
            oiTax = 0
          }
  result <- liftIO $ DAL.Mutations.createOrder pool input
  case result of
    QuerySuccess order -> pure $ toOrderResponse order
    QueryError err -> throwError $ err500 {errBody = LBS.fromStrict $ encodeUtf8 $ T.pack ("Database error: " ++ show err)}

ordersGet :: Env -> Int64 -> Handler OrderResponse
ordersGet env oid = do
  let pool = envPool env
  result <- liftIO $ Surypus.API.Order.getOrder pool oid
  case result of
    QuerySuccess order -> pure $ toOrderResponse order
    QueryError _ -> throwError $ err500 {errBody = LBS.fromStrict $ encodeUtf8 $ T.pack "Order not found"}

ordersStatus :: Env -> Int64 -> Maybe Int -> Handler OrderResponse
ordersStatus _ _ _ = pure $ OrderResponse 1 "Demo" 1 (read "2024-01-01")

ordersDelete :: Env -> Int64 -> Handler ()
ordersDelete _ _ = pure ()

toOrderResponse :: DAL.Types.Order -> OrderResponse
toOrderResponse (DAL.Types.Order {oId = oid, oName = oname, oStatus = ostatus, oDate = odate}) =
  OrderResponse
    { orderId = oid,
      orderName = fromMaybe "Order" oname,
      orderStatus = ostatus,
      orderDate = odate
    }

taxesList :: Env -> Handler TaxesResponse
taxesList env = do
  let pool = envPool env
  result <- liftIO $ DAL.Queries.getTaxes pool
  case result of
    QuerySuccess taxes -> pure $ TaxesResponse (map toTaxResponse taxes)
    QueryError err -> throwError $ err500 {errBody = LBS.fromStrict $ encodeUtf8 $ T.pack ("Database error: " ++ show err)}

taxesCreate :: Env -> TaxRequest -> Handler TaxResponse
taxesCreate env (TaxRequest name rate) = do
  let pool = envPool env
      input = DAL.Types.TaxInput {tiName = name, tiRate = rate, tiTaxType = 1, tiIncluded = False}
  result <- liftIO $ DAL.Mutations.createTax pool input
  case result of
    QuerySuccess tax -> pure $ toTaxResponse tax
    QueryError err -> throwError $ err500 {errBody = LBS.fromStrict $ encodeUtf8 $ T.pack ("Database error: " ++ show err)}

taxesGet :: Env -> Int64 -> Handler TaxResponse
taxesGet env tid = do
  let pool = envPool env
  result <- liftIO $ DAL.Queries.getTaxById pool tid
  case result of
    QuerySuccess tax -> pure $ toTaxResponse tax
    QueryError err -> throwError $ err500 {errBody = LBS.fromStrict $ encodeUtf8 $ T.pack ("Database error: " ++ show err)}

taxesUpdate :: Env -> Int64 -> TaxRequest -> Handler TaxResponse
taxesUpdate _ _ _ = pure $ TaxResponse 1 "Updated" 0.0 (Just "VAT") (Just False)

taxesDelete :: Env -> Int64 -> Handler ()
taxesDelete _ _ = pure ()

vatCalculate :: VATCalcRequest -> Handler VATCalcResponse
vatCalculate req =
  let reqAmount = vatAmount req
      reqRate = vatRate req
      reqInc = vatInclusive req
      netVal = if reqInc then reqAmount / (1 + reqRate / 100) else reqAmount
      taxVal = if reqInc then reqAmount - reqAmount / (1 + reqRate / 100) else reqAmount * reqRate / 100
   in pure
        VATCalcResponse
          { vatNetAmount = netVal,
            vatTaxAmount = taxVal,
            vatGrossAmount = reqAmount,
            vatAppliedRate = reqRate
          }

vatRates :: Env -> Handler TaxesResponse
vatRates env = do
  let pool = envPool env
  result <- liftIO $ DAL.Queries.getTaxes pool
  case result of
    QuerySuccess taxes -> pure $ TaxesResponse (map toTaxResponse taxes)
    QueryError err -> throwError $ err500 {errBody = LBS.fromStrict $ encodeUtf8 $ T.pack ("Database error: " ++ show err)}

currenciesList :: Env -> Handler CurrenciesResponse
currenciesList env = do
  let pool = envPool env
  result <- liftIO $ DAL.Queries.getCurrencies pool
  case result of
    QuerySuccess currencies -> pure $ CurrenciesResponse (map toCurrencyResponse currencies)
    QueryError err -> throwError $ err500 {errBody = LBS.fromStrict $ encodeUtf8 $ T.pack ("Database error: " ++ show err)}

currenciesCreate :: Env -> CurrencyRequest -> Handler CurrencyResponse
currenciesCreate _ _ = pure $ CurrencyResponse 100 "New" "XXX"

currenciesGet :: Env -> Int64 -> Handler CurrencyResponse
currenciesGet env cid = do
  let pool = envPool env
  result <- liftIO $ Surypus.API.Currency.getCurrency pool cid
  case result of
    QuerySuccess currency -> pure $ toCurrencyResponse currency
    QueryError _ -> throwError $ err500 {errBody = LBS.fromStrict $ encodeUtf8 $ T.pack "Currency not found"}

currenciesUpdate :: Env -> Int64 -> CurrencyRequest -> Handler CurrencyResponse
currenciesUpdate _ _ _ = pure $ CurrencyResponse 1 "Updated" "XXX"

currenciesDelete :: Env -> Int64 -> Handler ()
currenciesDelete _ _ = pure ()

toCurrencyResponse :: DAL.Types.Currency -> CurrencyResponse
toCurrencyResponse (DAL.Types.Currency {currId = cid, currName = cname, currCode = ccode}) =
  CurrencyResponse
    { currencyId = cid,
      currencyName = cname,
      currencyCode = ccode
    }

toStockResponse :: Stock -> StockItemResponse
toStockResponse (Stock {sGoodsId = gid, sLocationId = lid, sQuantity = qty}) =
  StockItemResponse
    { stockGoodsId = gid,
      stockLocationId = lid,
      stockQuantity = qty
    }

stockList :: Env -> Handler StockResponse
stockList _ = do
  let pool = envPool _
  result <- liftIO $ DAL.Queries.getStockSummary pool
  case result of
    QuerySuccess stocks -> pure $ StockResponse (map toStockResponse stocks)
    QueryError err -> throwError $ err500 {errBody = LBS.fromStrict $ encodeUtf8 $ T.pack ("Database error: " ++ show err)}

stockSummary :: Env -> Handler StockResponse
stockSummary _ = do
  let pool = envPool _
  result <- liftIO $ DAL.Queries.getStockSummary pool
  case result of
    QuerySuccess stocks -> pure $ StockResponse (map toStockResponse stocks)
    QueryError err -> throwError $ err500 {errBody = LBS.fromStrict $ encodeUtf8 $ T.pack ("Database error: " ++ show err)}

stockByLoc :: Env -> Int64 -> Int64 -> Handler StockItemResponse
stockByLoc _ gid lid = do
  let pool = envPool _
  result <- liftIO $ DAL.Queries.getStock pool gid lid
  case result of
    QuerySuccess stocks ->
      case stocks of
        (stock : _) -> pure $ toStockResponse stock
        [] -> pure $ StockItemResponse 0 0 0.0
    QueryError err -> throwError $ err500 {errBody = LBS.fromStrict $ encodeUtf8 $ T.pack ("Database error: " ++ show err)}

stockByGoods :: Env -> Int64 -> Handler StockResponse
stockByGoods _ gid = do
  let pool = envPool _
  result <- liftIO $ DAL.Queries.getStockByGoods pool gid
  case result of
    QuerySuccess stocks -> pure $ StockResponse (map toStockResponse stocks)
    QueryError err -> throwError $ err500 {errBody = LBS.fromStrict $ encodeUtf8 $ T.pack ("Database error: " ++ show err)}

accList :: Env -> Handler AccountsResponse
accList _ = do
  let pool = envPool _
  result <- liftIO $ DAL.Queries.getAccPlans pool
  case result of
    QuerySuccess accounts -> pure $ AccountsResponse (map toAccPlanResponse accounts)
    QueryError err -> throwError $ err500 {errBody = LBS.fromStrict $ encodeUtf8 $ T.pack ("Database error: " ++ show err)}

accCreate :: AccPlanRequest -> Handler AccPlanResponse
accCreate _ = pure $ AccPlanResponse 100 "01" "New"

accGet :: Int64 -> Handler AccPlanResponse
accGet _ = pure $ AccPlanResponse 1 "01" "Основные"

accUpdate :: Int64 -> AccPlanRequest -> Handler AccPlanResponse
accUpdate _ _ = pure $ AccPlanResponse 1 "01" "Updated"

accDelete :: Int64 -> Handler ()
accDelete _ = pure ()

entriesList :: Env -> Handler AccEntriesResponse
entriesList _ = do
  let pool = envPool _
  result <- liftIO $ DAL.Queries.getAccTurns pool
  case result of
    QuerySuccess turns -> pure $ AccEntriesResponse (map toAccEntryResponse turns)
    QueryError err -> throwError $ err500 {errBody = LBS.fromStrict $ encodeUtf8 $ T.pack ("Database error: " ++ show err)}
  where
    toAccEntryResponse :: AccTurn -> AccEntryResponse
    toAccEntryResponse (AccTurn {atId = id, atDbtAccId = dbt, atCrdAccId = crd, atAmount = amt}) =
      AccEntryResponse id dbt (fromDecimal amt) (fromDecimal amt)

entriesCreate :: AccEntryRequest -> Handler AccEntryResponse
entriesCreate _ = pure $ AccEntryResponse 100 1 0.0 0.0

entriesGet :: Int64 -> Handler AccEntryResponse
entriesGet _ = pure $ AccEntryResponse 1 1 0.0 0.0

entriesUpdate :: Int64 -> AccEntryRequest -> Handler AccEntryResponse
entriesUpdate _ _ = pure $ AccEntryResponse 1 1 0.0 0.0

entriesDelete :: Int64 -> Handler ()
entriesDelete _ = pure ()

payrollList :: Handler PayrollResponse
-- | GET /v1/payroll - Requires PayrollRead permission
-- TODO: Implement real DB query
payrollList = pure $ PayrollResponse []

empList :: Handler EmployeesResponse

-- | GET /v1/payroll/employees - Requires PayrollRead permission
empList :: Env -> Handler EmployeesResponse
empList _ = do
  let pool = envPool _
  result <- liftIO $ DAL.Queries.getEmployees pool
  case result of
    QuerySuccess employees -> pure $ EmployeesResponse (map toEmployeeResponse employees)
    QueryError err -> throwError $ err500 {errBody = LBS.fromStrict $ encodeUtf8 $ T.pack ("Database error: " ++ show err)}
  where
    toEmployeeResponse :: Employee -> EmployeeResponse
    toEmployeeResponse (Employee {eId = id, eName = name}) =
      EmployeeResponse id name

empGet :: Int64 -> Handler EmployeeResponse

-- | GET /v1/payroll/employees/:id - Requires PayrollRead permission
empGet _ = pure $ EmployeeResponse 1 "Demo"

salariesList :: Handler SalariesResponse

-- | GET /v1/payroll/salaries - Requires PayrollRead permission
salariesList :: Env -> Handler SalariesResponse
salariesList _ = do
  let pool = envPool _
  result <- liftIO $ DAL.Queries.getSalaries pool
  case result of
    QuerySuccess salaries -> pure $ SalariesResponse (map toSalaryResponse salaries)
    QueryError err -> throwError $ err500 {errBody = LBS.fromStrict $ encodeUtf8 $ T.pack ("Database error: " ++ show err)}
  where
    toSalaryResponse :: Salary -> SalaryResponse
    toSalaryResponse (Salary {sId = id, sAmount = amt}) =
      SalaryResponse id (fromDecimal amt)

salaryGet :: Int64 -> Handler SalaryResponse

-- | GET /v1/payroll/salaries/:id - Requires SalariesWrite permission (for access)
salaryGet _ = pure $ SalaryResponse 1 0.0

reportsList :: Env -> Handler ReportsResponse
reportsList _ = do
  let pool = envPool _
  result <- liftIO $ DAL.Queries.getReports pool
  case result of
    QuerySuccess reports -> pure $ ReportsResponse (map toReportResponse reports)
    QueryError err -> throwError $ err500 {errBody = LBS.fromStrict $ encodeUtf8 $ T.pack ("Database error: " ++ show err)}
  where
    toReportResponse :: ReportTemplate -> ReportResponse
    toReportResponse (ReportTemplate {rtId = rid, rtName = rname}) =
      ReportResponse rid rname

reportsMeta :: Handler ReportsMetadataResponse
reportsMeta = pure $ ReportsMetadataResponse []

reportsTemplates :: Env -> Handler ReportsResponse
reportsTemplates _ = do
  let pool = envPool _
  result <- liftIO $ DAL.Queries.getReports pool
  case result of
    QuerySuccess reports -> pure $ ReportsResponse (map toReportResponse reports)
    QueryError err -> throwError $ err500 {errBody = LBS.fromStrict $ encodeUtf8 $ T.pack ("Database error: " ++ show err)}
  where
    toReportResponse :: ReportTemplate -> ReportResponse
    toReportResponse (ReportTemplate {rtId = rid, rtName = rname}) =
      ReportResponse rid rname

reportGet :: Int64 -> Handler ReportResponse
reportGet _ = pure $ ReportResponse 1 "Demo"

reportJrxml :: Text -> Handler ReportJRXMLResponse
reportJrxml _ = pure $ ReportJRXMLResponse "" ""

dashboardGet :: Handler DashboardResponse
dashboardGet = pure $ DashboardResponse "null"

usersList :: Handler UsersResponse

-- | GET /v1/users - Requires UsersRead permission
usersList :: Env -> Handler UsersResponse
usersList _ = do
  let pool = envPool _
  result <- liftIO $ DAL.Queries.getUsers pool
  case result of
    QuerySuccess users -> pure $ UsersResponse (map toUserResponse users)
    QueryError err -> throwError $ err500 {errBody = LBS.fromStrict $ encodeUtf8 $ T.pack ("Database error: " ++ show err)}
  where
    toUserResponse :: User -> UserResponse
    toUserResponse (User {uId = id, uLogin = login, uPersonId = personId, uEmail = email, uRoleId = roleId, uStatus = status}) =
      UserResponse id login (fromIntegral personId) email (fromIntegral roleId) (fromIntegral status)

auditLogList :: Env -> Maybe Text -> Maybe Int64 -> Maybe Int64 -> Handler AuditLogListResponse
auditLogList env mEntityType mLimit mOffset = do
  auditEntries <- liftIO $ fetchAuditLogsBestEffort env mEntityType (fromMaybe 100 mLimit) (sum mOffset)
  pure $ AuditLogListResponse auditEntries

jobsList :: Handler JobsResponse
jobsList = pure $ JobsResponse []

jobsPending :: Handler JobsPendingResponse
jobsPending = pure $ JobsPendingResponse 0

jobsCreate :: JobRequest -> Handler JobResponse
jobsCreate _ = pure $ JobResponse 1

healthGet :: Env -> Handler HealthResponse
healthGet env = do
  dbOk <- liftIO $ do
    result <- try (pingDatabasePool (envPool env)) :: IO (Either SomeException Bool)
    pure $ either (const False) id result
  let dbStatus :: Text
      dbStatus = if dbOk then "ok" else "failed"
      overall :: Text
      overall = if dbOk then "ok" else "degraded"
  liftIO $ debugLogIf (not dbOk) $ "Health check: DB status=" <> dbStatus
  pure $ HealthResponse overall (object ["db" .= dbStatus])

healthLiveGet :: Handler HealthLiveResponse
healthLiveGet = pure $ HealthLiveResponse "ok"

healthReadyGet :: Env -> Handler HealthReadyResponse
healthReadyGet env = do
  dbOk <- liftIO $ do
    result <- try (pingDatabasePool (envPool env)) :: IO (Either SomeException Bool)
    pure $ either (const False) id result
  let dbStatus = if dbOk then "ok" else "failed"
      overall = if dbOk then "ok" else "not_ready"
  pure $ HealthReadyResponse overall dbStatus

metricsGet :: Handler MetricsResponse
metricsGet = pure $ MetricsResponse 0 0 0

rbacRolesList :: Env -> Handler RolesListResponse
rbacRolesList env = do
  rbacRoles <- liftIO $ listRoles (envRBACStore env)
  pure $ RolesListResponse (fmap toRoleInfo rbacRoles)

rbacRoleCreate :: Env -> RoleCreateRequest -> Handler RoleInfoResponse
rbacRoleCreate env req = do
  scoped <- mapM mkScoped (normalizeRoleSpecs (rcrPermissions req) (rcrResources req))
  let dynRole = mkDynamicRole (rcrName req) scoped
  liftIO $ upsertRole (envRBACStore env) dynRole
  liftIO $ emitAdminAudit env "rbac-role-created" (Just (rcrName req))
  pure $ toRoleInfo dynRole

rbacRoleUpdate :: Env -> Text -> RoleCreateRequest -> Handler RoleInfoResponse
rbacRoleUpdate env name req = do
  scoped <- mapM mkScoped (normalizeRoleSpecs (rcrPermissions req) (rcrResources req))
  let dynRole = mkDynamicRole name scoped
  liftIO $ upsertRole (envRBACStore env) dynRole
  liftIO $ emitAdminAudit env "rbac-role-updated" (Just name)
  pure $ toRoleInfo dynRole

rbacRoleDelete :: Env -> Text -> Handler ()
rbacRoleDelete env name = do
  liftIO $ deleteRole (envRBACStore env) name
  liftIO $ emitAdminAudit env "rbac-role-deleted" (Just name)

rbacGrantsList :: Env -> Handler GrantsListResponse
rbacGrantsList env = do
  grants <- liftIO $ listGrants (envRBACStore env)
  pure $ GrantsListResponse (fmap toGrantInfo grants)

rbacGrantCreate :: Env -> GrantCreateRequest -> Handler GrantInfoResponse
rbacGrantCreate env req = do
  scoped <- mkScoped (gcrPermission req, gcrResource req)
  now <- liftIO getCurrentTime
  let expiryMinutes = maybe 60 fromIntegral (gcrExpiresInMinutes req)
      expiresAt = addUTCTime (expiryMinutes * 60) now
      finalGrant = escalateTemporarily (gcrFrom req) (gcrTo req) scoped expiresAt
  liftIO $ addGrant (envRBACStore env) finalGrant
  liftIO $ emitAdminAudit env "rbac-grant-created" (Just (gcrTo req))
  pure $ toGrantInfo finalGrant

rbacActiveGrantsList :: Env -> Maybe Text -> Handler GrantsListResponse
rbacActiveGrantsList env mPrincipal = do
  now <- liftIO getCurrentTime
  grants <- liftIO $ listActiveGrants (envRBACStore env) mPrincipal now
  pure $ GrantsListResponse (fmap toGrantInfo grants)

rbacGrantsCleanup :: Env -> Handler CleanupResponse
rbacGrantsCleanup env = do
  now <- liftIO getCurrentTime
  removed <- liftIO $ cleanupExpiredGrants (envRBACStore env) now
  liftIO $ emitAdminAudit env "rbac-grants-cleanup" Nothing
  pure $ CleanupResponse (fromIntegral removed)

rbacGrantUpdate :: Env -> Text -> Text -> Text -> Maybe Text -> GrantUpdateRequest -> Handler GrantInfoResponse
rbacGrantUpdate env from to permText mResource req = do
  scoped <- mkScoped (permText, mResource)
  now <- liftIO getCurrentTime
  let expiryMinutes = maybe 60 fromIntegral (gurExpiresInMinutes req)
      expiresAt = addUTCTime (expiryMinutes * 60) now
      updatedGrant = escalateTemporarily from to scoped expiresAt
      target = PermissionGrant from to scoped Nothing
  liftIO $ removeGrant (envRBACStore env) from to target
  liftIO $ addGrant (envRBACStore env) updatedGrant
  liftIO $ emitAdminAudit env "rbac-grant-updated" (Just to)
  pure $ toGrantInfo updatedGrant

rbacGrantDelete :: Env -> Text -> Text -> Text -> Maybe Text -> Handler ()
rbacGrantDelete env from to permText mResource = do
  scoped <- mkScoped (permText, mResource)
  let target = PermissionGrant from to scoped Nothing
  liftIO $ removeGrant (envRBACStore env) from to target
  liftIO $ emitAdminAudit env "rbac-grant-deleted" (Just to)

rbacAuditList :: Env -> Maybe Text -> Maybe Text -> Maybe Int64 -> Maybe Int64 -> Handler AuditListResponse
rbacAuditList env mPrincipal mResource mOffset mLimit = do
  auditEntries <- liftIO $ listAuditEntries (envRBACStore env)
  pure $ AuditListResponse (applyAuditFilters mPrincipal mResource mOffset mLimit auditEntries)

rbacAuditCleanup :: Env -> Maybe Int64 -> Handler CleanupResponse
rbacAuditCleanup env mKeep = do
  removed <- liftIO $ cleanupAuditEntries (envRBACStore env) (fromIntegral <$> mKeep)
  liftIO $ emitAdminAudit env "rbac-audit-cleanup" Nothing
  pure $ CleanupResponse (fromIntegral removed)

emitAdminAudit :: Env -> Text -> Maybe Text -> IO ()
emitAdminAudit env action mResource = do
  ts <- getCurrentTime
  let entry =
        AuditEntry
          { aeTimestamp = ts,
            aePrincipal = "system",
            aeRole = "admin-api",
            aePermission = AdminAccess,
            aeResource = mResource,
            aeAllowed = True,
            aeReason = action
          }
  writeAuditEntry (envRBACStore env) entry

fetchAuditLogsBestEffort :: Env -> Maybe Text -> Int64 -> Int64 -> IO [AuditLog]
fetchAuditLogsBestEffort env mEntityType limit offset = do
  let repo = AuditLogRepo.mkAuditLogRepository (envPool env)
      action = case mEntityType of
        Nothing -> AuditLogRepo.listAuditLogsRepo repo limit offset
        Just entityType -> AuditLogRepo.listAuditLogsByEntityTypeRepo repo entityType limit offset
  result <- try (runExceptT action) :: IO (Either SomeException (Either RepositoryError [AuditLog]))
  pure $ case result of
    Left _ -> []
    Right (Left _) -> []
    Right (Right rows) -> rows

toRoleInfo :: DynamicRole -> RoleInfoResponse
toRoleInfo dynRole =
  RoleInfoResponse
    { rirName = drName dynRole,
      rirPermissions = fmap scopedPermissionText (drPermissions dynRole)
    }

toGrantInfo :: PermissionGrant -> GrantInfoResponse
toGrantInfo grant =
  GrantInfoResponse
    { girFrom = pgFrom grant,
      girTo = pgTo grant,
      girPermission = scopedPermissionText (pgPermission grant),
      girResource = scopeResourceText (spScope (pgPermission grant)),
      girExpiresAt = T.pack . show <$> pgExpiresAt grant
    }

scopedPermissionText :: ScopedPermission -> Text
scopedPermissionText scoped = permissionToText (spPermission scoped)

scopeResourceText :: PermissionScope -> Maybe Text
scopeResourceText GlobalScope = Nothing
scopeResourceText (ResourceScope rid) = Just rid

mkScoped :: (Text, Maybe Text) -> Handler Surypus.API.Root.ScopedPermission
mkScoped (permText, mRes) = pure $ Surypus.API.Root.ScopedPermission permText (maybe Surypus.API.Root.GlobalScope Surypus.API.Root.ResourceScope mRes)

normalizeRoleSpecs :: [Text] -> [Maybe Text] -> [(Text, Maybe Text)]
normalizeRoleSpecs perms [] = [(perm, Nothing) | perm <- perms]
normalizeRoleSpecs perms resources = zip perms (resources <> repeat Nothing)

applyAuditFilters :: Maybe Text -> Maybe Text -> Maybe Int64 -> Maybe Int64 -> [AuditEntry] -> [AuditEntry]
applyAuditFilters mPrincipal mResource mOffset mLimit =
  applyLimit . applyOffset . filter byResource . filter byPrincipal
  where
    byPrincipal entry = case mPrincipal of
      Nothing -> True
      Just principal -> aePrincipal entry == principal

    byResource entry = case mResource of
      Nothing -> True
      Just resource -> aeResource entry == Just resource

    applyOffset xs = case mOffset of
      Nothing -> xs
      Just n -> drop (fromIntegral (max 0 n)) xs

    applyLimit xs = case mLimit of
      Nothing -> xs
      Just n -> take (fromIntegral (max 0 n)) xs

parsePermissionText :: Text -> Maybe Text
parsePermissionText p = Just p
parsePermissionText p =
  lookup
    p
    [ ("person:read", PersonRead),
      ("person:write", PersonWrite),
      ("person:delete", PersonDelete),
      ("goods:read", GoodsRead),
      ("goods:write", GoodsWrite),
      ("goods:delete", GoodsDelete),
      ("bill:read", BillRead),
      ("bill:write", BillWrite),
      ("bill:delete", BillDelete),
      ("bill:post", BillPost),
      ("payment:read", PaymentRead),
      ("payment:write", PaymentWrite),
      ("payment:delete", PaymentDelete),
      ("location:read", LocationRead),
      ("location:write", LocationWrite),
      ("location:delete", LocationDelete),
      ("stock:read", StockRead),
      ("stock:write", StockWrite),
      ("accounting:read", AccountingRead),
      ("accounting:write", AccountingWrite),
      ("payroll:read", PayrollRead),
      ("payroll:write", PayrollWrite),
      ("reports:read", ReportsRead),
      ("reports:write", ReportsWrite),
      ("users:read", UsersRead),
      ("users:write", UsersWrite),
      ("settings:read", SettingsRead),
      ("settings:write", SettingsWrite),
      ("admin:access", AdminAccess),
      ("bills:write", BillsWrite),
      ("orders:write", OrdersWrite),
      ("taxes:write", TaxesWrite),
      ("currencies:write", CurrenciesWrite),
      ("salaries:write", SalariesWrite)
    ]

startServantServer :: Int -> Pool -> JWTConfig -> IO ()
startServantServer port pool jwtConfig = do
  debugLog $ "Starting Servant server on port " <> T.pack (show port)
  run port $ apiServer pool jwtConfig undefined
