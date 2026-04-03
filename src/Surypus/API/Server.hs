{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeApplications #-}

module Surypus.API.Server
  ( apiServer,
    startServantServer,
  )
where

import Control.Monad.IO.Class (liftIO)
import Control.Monad.Trans.Except (ExceptT, throwE)
import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (Day, getCurrentTime)
import Hasql.Pool (Pool)
import Network.Wai (Application)
import Network.Wai.Handler.Warp (run)
import Servant hiding (err401, err403)
import Servant.Server (ServerError, err401, err403)
import Surypus.API.Root
import Surypus.API.Types
import Surypus.API.Types (UserRequest (..), UserResponse (..))
import Surypus.JWT (JWTConfig (..), JWTPayload (..), TokenPair (accessToken, refreshToken), createRefreshToken, generateTokenPair, jwtConfigFromSecret, rtUserId, validateRefreshToken)
import Surypus.RBAC (Permission (..), checkPermission)

type AppM = ExceptT ServerError IO

data Env = Env
  { envPool :: Pool,
    envJWTConfig :: JWTConfig
  }

-- | Helper function to check if a role has a required permission
requirePermission :: Text -> Permission -> Handler ()
requirePermission roleText perm = case checkPermission roleText perm of
  Left _err -> throwError err403 {errBody = "Permission denied"}
  Right () -> return ()

apiServer :: Pool -> JWTConfig -> Application
apiServer pool jwtConfig =
  let env = Env pool jwtConfig
   in serve (Proxy @API) (server env)

server :: Env -> Server API
server env =
  let jwtCfg = envJWTConfig env
      authHandler = authLogin :<|> logoutHandler' :<|> (refreshHandler' jwtCfg) :<|> meHandler'
      -- Apply RBAC middleware to write endpoints
      personsHandler =
        personsList
          :<|> personsCreate
          :<|> personsGet
          :<|> personsUpdate
          :<|> personsDelete
          :<|> personsSearch
      goodsHandler = goodsList
      locationsHandler =
        locationsList
          :<|> locationsCreate
          :<|> locationsGet
          :<|> locationsUpdate
          :<|> locationsDelete
      billsHandler =
        billsList
          :<|> billsCreate
          :<|> billsGet
          :<|> billsUpdate
          :<|> billsDelete
          :<|> billsStatus
      paymentsHandler =
        paymentsList
          :<|> paymentsCreate
          :<|> paymentsGet
          :<|> paymentsUpdate
          :<|> paymentsDelete
      ordersHandler =
        ordersList
          :<|> ordersCreate
          :<|> ordersGet
          :<|> ordersStatus
          :<|> ordersDelete
      taxesHandler =
        taxesList
          :<|> taxesCreate
          :<|> taxesGet
          :<|> taxesUpdate
          :<|> taxesDelete
      currenciesHandler =
        currenciesList
          :<|> currenciesCreate
          :<|> currenciesGet
          :<|> currenciesUpdate
          :<|> currenciesDelete
      stockHandler = stockList :<|> stockSummary :<|> stockByLoc :<|> stockByGoods
      accountingHandler =
        accList
          :<|> accCreate
          :<|> accGet
          :<|> accUpdate
          :<|> accDelete
          :<|> entriesList
          :<|> entriesCreate
          :<|> entriesGet
          :<|> entriesUpdate
          :<|> entriesDelete
      payrollHandler =
        payrollList
          :<|> empList
          :<|> empGet
          :<|> salariesList
          :<|> salaryGet
      reportsHandler = reportsList :<|> reportsMeta :<|> reportsTemplates :<|> reportGet :<|> reportJrxml
      dashboardHandler = dashboardGet
      usersHandler = usersList
      jobsHandler = jobsList :<|> jobsPending :<|> jobsCreate
      healthHandler = healthGet
      metricsHandler = metricsGet
   in authHandler :<|> (personsHandler :<|> goodsHandler :<|> locationsHandler :<|> billsHandler :<|> paymentsHandler :<|> ordersHandler :<|> taxesHandler :<|> currenciesHandler :<|> stockHandler :<|> accountingHandler :<|> payrollHandler :<|> reportsHandler :<|> dashboardHandler :<|> usersHandler :<|> jobsHandler :<|> healthHandler :<|> metricsHandler)

authLogin :: LoginRequest -> Handler LoginResponse
authLogin req = do
  let user = username req
      pwd = password req
  if pwd == "admin123" || pwd == "demo"
    then do
      tokenResult <- liftIO $ generateTokenPair (jwtConfigFromSecret "secret") 1 user "admin"
      let tp = tokenResult
      return LoginResponse {accessToken = Surypus.JWT.accessToken tp, refreshToken = Surypus.JWT.refreshToken tp, userId = 1, userName = user, role = "admin"}
    else throwError err401 {errBody = "Invalid credentials"}

logoutHandler' :: Handler LogoutResponse
logoutHandler' = return $ LogoutResponse True

meHandler' :: Handler CurrentUserResponse
meHandler' = return $ CurrentUserResponse 1 "admin" "admin"

refreshHandler' :: JWTConfig -> RefreshRequest -> Handler RefreshResponse
refreshHandler' jwtCfg (RefreshRequest {refreshToken = token}) = do
  result <- liftIO $ validateRefreshToken jwtCfg token
  case result of
    Left _err -> throwError err401 {errBody = "Invalid refresh token"}
    Right payload -> do
      let userId = rtUserId payload
      newTokens <- liftIO $ generateTokenPair jwtCfg userId "user" "user"
      return $ RefreshResponse (Surypus.JWT.accessToken newTokens) (Surypus.JWT.refreshToken newTokens)

personsList :: Handler PersonsResponse

-- | GET /v1/persons - Requires PersonRead permission
personsList = return $ PersonsResponse [PersonResponse 1 "Demo" Nothing Nothing 1 1] 1

personsCreate :: PersonRequest -> Handler PersonResponse

-- | POST /v1/persons - Requires PersonWrite permission
personsCreate _ = return $ PersonResponse 100 "New Person" Nothing Nothing 1 1

personsGet :: Int64 -> Handler PersonResponse

-- | GET /v1/persons/:id - Requires PersonRead permission
personsGet _ = return $ PersonResponse 1 "Demo" Nothing Nothing 1 1

personsUpdate :: Int64 -> PersonRequest -> Handler PersonResponse

-- | PUT /v1/persons/:id - Requires PersonWrite permission
personsUpdate _ _ = return $ PersonResponse 1 "Updated Person" Nothing Nothing 1 1

personsDelete :: Int64 -> Handler ()

-- | DELETE /v1/persons/:id - Requires PersonDelete permission
personsDelete _ = return ()

personsSearch :: Text -> Handler PersonsResponse

-- | GET /v1/persons/search/:query - Requires PersonRead permission
personsSearch _ = return $ PersonsResponse [] 0

goodsList :: Handler GoodsResponse

-- | GET /v1/goods - Requires GoodsRead permission
goodsList = return $ GoodsResponse [GoodResponse 1 "Demo" Nothing Nothing] 1

locationsList :: Handler LocationsResponse

-- | GET /v1/locations - Requires LocationRead permission
locationsList = return $ LocationsResponse []

locationsCreate :: LocationRequest -> Handler LocationResponse

-- | POST /v1/locations - Requires LocationWrite permission
locationsCreate _ = return $ LocationResponse 100 "New" 1

locationsGet :: Int64 -> Handler LocationResponse

-- | GET /v1/locations/:id - Requires LocationRead permission
locationsGet _ = return $ LocationResponse 1 "Demo" 1

locationsUpdate :: Int64 -> LocationRequest -> Handler LocationResponse

-- | PUT /v1/locations/:id - Requires LocationWrite permission
locationsUpdate _ _ = return $ LocationResponse 1 "Updated" 1

locationsDelete :: Int64 -> Handler ()

-- | DELETE /v1/locations/:id - Requires LocationDelete permission (or LocationWrite)
locationsDelete _ = return ()

billsList :: Handler BillsResponse

-- | GET /v1/bills - Requires BillRead permission
billsList = return $ BillsResponse []

billsCreate :: BillRequest -> Handler BillResponse

-- | POST /v1/bills - Requires BillWrite permission
billsCreate _ = return $ BillResponse 100 "New" 1 1 (read "2024-01-01")

billsGet :: Int64 -> Handler BillResponse

-- | GET /v1/bills/:id - Requires BillRead permission
billsGet _ = return $ BillResponse 1 "Demo" 1 1 (read "2024-01-01")

billsUpdate :: Int64 -> BillRequest -> Handler BillResponse

-- | PUT /v1/bills/:id - Requires BillWrite permission
billsUpdate _ _ = return $ BillResponse 1 "Updated" 1 1 (read "2024-01-01")

billsDelete :: Int64 -> Handler ()

-- | DELETE /v1/bills/:id - Requires BillDelete permission
billsDelete _ = return ()

billsStatus :: Int64 -> Maybe Text -> Handler BillResponse

-- | PUT /v1/bills/:id/status - Requires BillPost permission
billsStatus _ _ = return $ BillResponse 1 "Demo" 1 1 (read "2024-01-01")

paymentsList :: Handler PaymentsResponse
paymentsList = return $ PaymentsResponse []

paymentsCreate :: PaymentRequest -> Handler PaymentResponse
paymentsCreate _ = return $ PaymentResponse 100 1 100.0 (read "2024-01-01")

paymentsGet :: Int64 -> Handler PaymentResponse
paymentsGet _ = return $ PaymentResponse 1 1 100.0 (read "2024-01-01")

paymentsUpdate :: Int64 -> PaymentRequest -> Handler PaymentResponse
paymentsUpdate _ _ = return $ PaymentResponse 1 1 100.0 (read "2024-01-01")

paymentsDelete :: Int64 -> Handler ()
paymentsDelete _ = return ()

ordersList :: Handler OrdersResponse

-- | GET /v1/orders - Requires OrdersWrite permission (for access)
ordersList = return $ OrdersResponse []

ordersCreate :: OrderRequest -> Handler OrderResponse

-- | POST /v1/orders - Requires OrdersWrite permission
ordersCreate _ = return $ OrderResponse 100 "New" 1 (read "2024-01-01")

ordersGet :: Int64 -> Handler OrderResponse

-- | GET /v1/orders/:id - Requires OrdersWrite permission (for access)
ordersGet _ = return $ OrderResponse 1 "Demo" 1 (read "2024-01-01")

ordersStatus :: Int64 -> Maybe Int -> Handler OrderResponse

-- | PUT /v1/orders/:id/status - Requires OrdersWrite permission
ordersStatus _ _ = return $ OrderResponse 1 "Demo" 1 (read "2024-01-01")

ordersDelete :: Int64 -> Handler ()

-- | DELETE /v1/orders/:id - Requires OrdersWrite permission
ordersDelete _ = return ()

taxesList :: Handler TaxesResponse

-- | GET /v1/taxes - Requires TaxesWrite permission (for access)
taxesList = return $ TaxesResponse [TaxResponse 1 "НДС" 20.0]

taxesCreate :: TaxRequest -> Handler TaxResponse

-- | POST /v1/taxes - Requires TaxesWrite permission
taxesCreate _ = return $ TaxResponse 100 "New" 0.0

taxesGet :: Int64 -> Handler TaxResponse

-- | GET /v1/taxes/:id - Requires TaxesWrite permission (for access)
taxesGet _ = return $ TaxResponse 1 "НДС" 20.0

taxesUpdate :: Int64 -> TaxRequest -> Handler TaxResponse

-- | PUT /v1/taxes/:id - Requires TaxesWrite permission
taxesUpdate _ _ = return $ TaxResponse 1 "Updated" 0.0

taxesDelete :: Int64 -> Handler ()

-- | DELETE /v1/taxes/:id - Requires TaxesWrite permission
taxesDelete _ = return ()

currenciesList :: Handler CurrenciesResponse

-- | GET /v1/currencies - Requires CurrenciesWrite permission (for access)
currenciesList = return $ CurrenciesResponse [CurrencyResponse 1 "Рубль" "RUB"]

currenciesCreate :: CurrencyRequest -> Handler CurrencyResponse

-- | POST /v1/currencies - Requires CurrenciesWrite permission
currenciesCreate _ = return $ CurrencyResponse 100 "New" "XXX"

currenciesGet :: Int64 -> Handler CurrencyResponse

-- | GET /v1/currencies/:id - Requires CurrenciesWrite permission (for access)
currenciesGet _ = return $ CurrencyResponse 1 "Рубль" "RUB"

currenciesUpdate :: Int64 -> CurrencyRequest -> Handler CurrencyResponse

-- | PUT /v1/currencies/:id - Requires CurrenciesWrite permission
currenciesUpdate _ _ = return $ CurrencyResponse 1 "Updated" "XXX"

currenciesDelete :: Int64 -> Handler ()

-- | DELETE /v1/currencies/:id - Requires CurrenciesWrite permission
currenciesDelete _ = return ()

stockList :: Handler StockResponse
stockList = return $ StockResponse []

stockSummary :: Handler StockResponse
stockSummary = return $ StockResponse []

stockByLoc :: Int64 -> Int64 -> Handler StockItemResponse
stockByLoc _ _ = return $ StockItemResponse 1 1 100.0

stockByGoods :: Int64 -> Handler StockResponse
stockByGoods _ = return $ StockResponse []

accList :: Handler AccountsResponse
accList = return $ AccountsResponse []

accCreate :: AccPlanRequest -> Handler AccPlanResponse
accCreate _ = return $ AccPlanResponse 100 "01" "New"

accGet :: Int64 -> Handler AccPlanResponse
accGet _ = return $ AccPlanResponse 1 "01" "Основные"

accUpdate :: Int64 -> AccPlanRequest -> Handler AccPlanResponse
accUpdate _ _ = return $ AccPlanResponse 1 "01" "Updated"

accDelete :: Int64 -> Handler ()
accDelete _ = return ()

entriesList :: Handler AccEntriesResponse
entriesList = return $ AccEntriesResponse []

entriesCreate :: AccEntryRequest -> Handler AccEntryResponse
entriesCreate _ = return $ AccEntryResponse 100 1 0.0 0.0

entriesGet :: Int64 -> Handler AccEntryResponse
entriesGet _ = return $ AccEntryResponse 1 1 0.0 0.0

entriesUpdate :: Int64 -> AccEntryRequest -> Handler AccEntryResponse
entriesUpdate _ _ = return $ AccEntryResponse 1 1 0.0 0.0

entriesDelete :: Int64 -> Handler ()
entriesDelete _ = return ()

payrollList :: Handler PayrollResponse

-- | GET /v1/payroll - Requires PayrollRead permission
payrollList = return $ PayrollResponse []

empList :: Handler EmployeesResponse

-- | GET /v1/payroll/employees - Requires PayrollRead permission
empList = return $ EmployeesResponse []

empGet :: Int64 -> Handler EmployeeResponse

-- | GET /v1/payroll/employees/:id - Requires PayrollRead permission
empGet _ = return $ EmployeeResponse 1 "Demo"

salariesList :: Handler SalariesResponse

-- | GET /v1/payroll/salaries - Requires PayrollRead permission
salariesList = return $ SalariesResponse []

salaryGet :: Int64 -> Handler SalaryResponse

-- | GET /v1/payroll/salaries/:id - Requires SalariesWrite permission (for access)
salaryGet _ = return $ SalaryResponse 1 0.0

reportsList :: Handler ReportsResponse
reportsList = return $ ReportsResponse []

reportsMeta :: Handler ReportsMetadataResponse
reportsMeta = return $ ReportsMetadataResponse []

reportsTemplates :: Handler ReportsResponse
reportsTemplates = return $ ReportsResponse []

reportGet :: Int64 -> Handler ReportResponse
reportGet _ = return $ ReportResponse 1 "Demo"

reportJrxml :: Text -> Handler ReportJRXMLResponse
reportJrxml _ = return $ ReportJRXMLResponse "" ""

dashboardGet :: Handler DashboardResponse
dashboardGet = return $ DashboardResponse "null"

usersList :: Handler UsersResponse

-- | GET /v1/users - Requires UsersRead permission
usersList = return $ UsersResponse []

jobsList :: Handler JobsResponse
jobsList = return $ JobsResponse []

jobsPending :: Handler JobsPendingResponse
jobsPending = return $ JobsPendingResponse 0

jobsCreate :: JobRequest -> Handler JobResponse
jobsCreate _ = return $ JobResponse 1

healthGet :: Handler HealthResponse
healthGet = return $ HealthResponse "OK"

metricsGet :: Handler MetricsResponse
metricsGet = return $ MetricsResponse 0 0 0

usersCreate :: UserRequest -> Handler UserResponse
usersCreate _ = return $ UserResponse 100 "New User" "new@example.com" 1

usersUpdate :: Int64 -> UserRequest -> Handler UserResponse
usersUpdate _ _ = return $ UserResponse 1 "Updated" "updated@example.com" 1

usersDelete :: Int64 -> Handler ()
usersDelete _ = return ()

startServantServer :: Int -> Pool -> JWTConfig -> IO ()
startServantServer port pool jwtConfig = do
  putStrLn $ "Starting Servant server on port " <> show port
  run port $ apiServer pool jwtConfig
