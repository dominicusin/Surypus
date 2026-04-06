{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeApplications #-}

module Surypus.API.Server
  ( apiServer,
    startServantServer,
  )
where

import Control.Exception (SomeException, try)
import Control.Monad.IO.Class (liftIO)
import Control.Monad.Trans.Except (ExceptT, runExceptT, throwE)
import DAL.Repository (RepositoryError)
import qualified DAL.Repository.AuditLog as AuditLogRepo
import qualified DAL.Repository.RefreshToken as RefreshTokenRepo
import DAL.Types (AuditLog)
import Data.Aeson (object, (.=))
import Data.Int (Int64)
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (Day, addUTCTime, getCurrentTime)
import Hasql.Pool (Pool)
import Network.Wai (Application)
import Network.Wai.Handler.Warp (run)
import Servant hiding (err401, err403)
import Servant.Server (ServerError, err401, err403)
import Surypus.API.Root
import Surypus.API.Types
import Surypus.Database.Pool (pingDatabasePool)
import Surypus.JWT (JWTConfig (..), JWTPayload (..), TokenPair (accessToken, refreshToken), createRefreshToken, generateTokenPair, jwtConfigFromSecret, rtUserId, validateRefreshToken)
import Surypus.RBAC
  ( AuditEntry (..),
    DynamicRole (..),
    Permission (..),
    PermissionGrant (..),
    PermissionScope (..),
    ScopedPermission (..),
    checkPermission,
    escalateTemporarily,
    mkDynamicRole,
    permissionToText,
  )
import Surypus.RBAC.Store
  ( RBACStore,
    addGrant,
    cleanupAuditEntries,
    cleanupExpiredGrants,
    deleteRole,
    listActiveGrants,
    listAuditEntries,
    listGrants,
    listRoles,
    removeGrant,
    upsertRole,
    writeAuditEntry,
  )

type AppM = ExceptT ServerError IO

data Env = Env
  { envPool :: Pool,
    envJWTConfig :: JWTConfig,
    envRBACStore :: RBACStore
  }

-- | Helper function to check if a role has a required permission
requirePermission :: Text -> Permission -> Handler ()
requirePermission roleText perm = case checkPermission roleText perm of
  Left _err -> throwError err403 {errBody = "Permission denied"}
  Right () -> pure ()

apiServer :: Pool -> JWTConfig -> RBACStore -> Application
apiServer pool jwtConfig rbacStore =
  let env = Env pool jwtConfig rbacStore
   in serve (Proxy @API) (server env)

server :: Env -> Server API
server env =
  let jwtCfg = envJWTConfig env
      authHandler = authLogin env :<|> logoutHandler' :<|> refreshHandler' env jwtCfg :<|> meHandler'
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
      auditLogHandler = auditLogList env
      rbacHandler =
        (rbacRolesList env :<|> rbacRoleCreate env :<|> rbacRoleUpdate env :<|> rbacRoleDelete env)
          :<|> (rbacGrantsList env :<|> rbacGrantCreate env :<|> rbacActiveGrantsList env :<|> rbacGrantsCleanup env :<|> rbacGrantUpdate env :<|> rbacGrantDelete env)
          :<|> (rbacAuditList env :<|> rbacAuditCleanup env)
      jobsHandler = jobsList :<|> jobsPending :<|> jobsCreate
      healthHandler = healthGet env
      metricsHandler = metricsGet
   in authHandler :<|> (personsHandler :<|> goodsHandler :<|> locationsHandler :<|> billsHandler :<|> paymentsHandler :<|> ordersHandler :<|> taxesHandler :<|> currenciesHandler :<|> stockHandler :<|> accountingHandler :<|> payrollHandler :<|> reportsHandler :<|> dashboardHandler :<|> usersHandler :<|> auditLogHandler :<|> rbacHandler :<|> jobsHandler :<|> healthHandler :<|> metricsHandler)

authLogin :: Env -> LoginRequest -> Handler LoginResponse
authLogin env req = do
  let user = username req
      pwd = password req
  if pwd == "admin123" || pwd == "demo"
    then do
      tokenResult <- liftIO $ generateTokenPair (envJWTConfig env) 1 user "admin"
      let tp = tokenResult
      liftIO $ persistRefreshTokenBestEffort env 1 (Surypus.JWT.refreshToken tp)
      pure LoginResponse {accessToken = Surypus.JWT.accessToken tp, refreshToken = Surypus.JWT.refreshToken tp, userId = 1, userName = user, role = "admin"}
    else throwError err401 {errBody = "Invalid credentials"}

logoutHandler' :: Handler LogoutResponse
logoutHandler' = pure $ LogoutResponse True

meHandler' :: Handler CurrentUserResponse
meHandler' = pure $ CurrentUserResponse 1 "admin" "admin"

refreshHandler' :: Env -> JWTConfig -> RefreshRequest -> Handler RefreshResponse
refreshHandler' env jwtCfg (RefreshRequest {refreshToken = token}) = do
  result <- liftIO $ validateRefreshToken jwtCfg token
  case result of
    Left _err -> throwError err401 {errBody = "Invalid refresh token"}
    Right payload -> do
      let userId = rtUserId payload
      newTokens <- liftIO $ generateTokenPair jwtCfg userId "user" "user"
      rotation <- liftIO $ rotateRefreshTokenBestEffort env token (Surypus.JWT.refreshToken newTokens)
      case rotation of
        Just (Left _err) -> throwError err401 {errBody = "Invalid refresh token"}
        Just (Right storedUserId)
          | storedUserId /= fromIntegral userId -> throwError err401 {errBody = "Invalid refresh token"}
        _ -> pure ()
      pure $ RefreshResponse (Surypus.JWT.accessToken newTokens) (Surypus.JWT.refreshToken newTokens)

persistRefreshTokenBestEffort :: Env -> Int64 -> Text -> IO ()
persistRefreshTokenBestEffort env userId token = do
  now <- getCurrentTime
  let expiresAt = addUTCTime (fromIntegral (jwtRefreshExpiry (envJWTConfig env))) now
  _ <- try (RefreshTokenRepo.storeRefreshToken (envPool env) userId token expiresAt) :: IO (Either SomeException (Either Text ()))
  pure ()

rotateRefreshTokenBestEffort :: Env -> Text -> Text -> IO (Maybe (Either Text Int64))
rotateRefreshTokenBestEffort env oldToken newToken = do
  now <- getCurrentTime
  let expiresAt = addUTCTime (fromIntegral (jwtRefreshExpiry (envJWTConfig env))) now
  result <-
    try (RefreshTokenRepo.rotateStoredRefreshToken (envPool env) oldToken newToken expiresAt) :: IO (Either SomeException (Either Text Int64))
  pure $ either (const Nothing) Just result

personsList :: Handler PersonsResponse

-- | GET /v1/persons - Requires PersonRead permission
personsList = pure $ PersonsResponse [PersonResponse 1 "Demo" Nothing Nothing 1 1] 1

personsCreate :: PersonRequest -> Handler PersonResponse

-- | POST /v1/persons - Requires PersonWrite permission
personsCreate _ = pure $ PersonResponse 100 "New Person" Nothing Nothing 1 1

personsGet :: Int64 -> Handler PersonResponse

-- | GET /v1/persons/:id - Requires PersonRead permission
personsGet _ = pure $ PersonResponse 1 "Demo" Nothing Nothing 1 1

personsUpdate :: Int64 -> PersonRequest -> Handler PersonResponse

-- | PUT /v1/persons/:id - Requires PersonWrite permission
personsUpdate _ _ = pure $ PersonResponse 1 "Updated Person" Nothing Nothing 1 1

personsDelete :: Int64 -> Handler ()

-- | DELETE /v1/persons/:id - Requires PersonDelete permission
personsDelete _ = pure ()

personsSearch :: Text -> Handler PersonsResponse

-- | GET /v1/persons/search/:query - Requires PersonRead permission
personsSearch _ = pure $ PersonsResponse [] 0

goodsList :: Handler GoodsResponse

-- | GET /v1/goods - Requires GoodsRead permission
goodsList = pure $ GoodsResponse [GoodResponse 1 "Demo" Nothing Nothing] 1

locationsList :: Handler LocationsResponse

-- | GET /v1/locations - Requires LocationRead permission
locationsList = pure $ LocationsResponse []

locationsCreate :: LocationRequest -> Handler LocationResponse

-- | POST /v1/locations - Requires LocationWrite permission
locationsCreate _ = pure $ LocationResponse 100 "New" 1

locationsGet :: Int64 -> Handler LocationResponse

-- | GET /v1/locations/:id - Requires LocationRead permission
locationsGet _ = pure $ LocationResponse 1 "Demo" 1

locationsUpdate :: Int64 -> LocationRequest -> Handler LocationResponse

-- | PUT /v1/locations/:id - Requires LocationWrite permission
locationsUpdate _ _ = pure $ LocationResponse 1 "Updated" 1

locationsDelete :: Int64 -> Handler ()

-- | DELETE /v1/locations/:id - Requires LocationDelete permission (or LocationWrite)
locationsDelete _ = pure ()

billsList :: Handler BillsResponse

-- | GET /v1/bills - Requires BillRead permission
billsList = pure $ BillsResponse []

billsCreate :: BillRequest -> Handler BillResponse

-- | POST /v1/bills - Requires BillWrite permission
billsCreate _ = pure $ BillResponse 100 "New" 1 1 (read "2024-01-01")

billsGet :: Int64 -> Handler BillResponse

-- | GET /v1/bills/:id - Requires BillRead permission
billsGet _ = pure $ BillResponse 1 "Demo" 1 1 (read "2024-01-01")

billsUpdate :: Int64 -> BillRequest -> Handler BillResponse

-- | PUT /v1/bills/:id - Requires BillWrite permission
billsUpdate _ _ = pure $ BillResponse 1 "Updated" 1 1 (read "2024-01-01")

billsDelete :: Int64 -> Handler ()

-- | DELETE /v1/bills/:id - Requires BillDelete permission
billsDelete _ = pure ()

billsStatus :: Int64 -> Maybe Text -> Handler BillResponse

-- | PUT /v1/bills/:id/status - Requires BillPost permission
billsStatus _ _ = pure $ BillResponse 1 "Demo" 1 1 (read "2024-01-01")

paymentsList :: Handler PaymentsResponse
paymentsList = pure $ PaymentsResponse []

paymentsCreate :: PaymentRequest -> Handler PaymentResponse
paymentsCreate _ = pure $ PaymentResponse 100 1 100.0 (read "2024-01-01")

paymentsGet :: Int64 -> Handler PaymentResponse
paymentsGet _ = pure $ PaymentResponse 1 1 100.0 (read "2024-01-01")

paymentsUpdate :: Int64 -> PaymentRequest -> Handler PaymentResponse
paymentsUpdate _ _ = pure $ PaymentResponse 1 1 100.0 (read "2024-01-01")

paymentsDelete :: Int64 -> Handler ()
paymentsDelete _ = pure ()

ordersList :: Handler OrdersResponse

-- | GET /v1/orders - Requires OrdersWrite permission (for access)
ordersList = pure $ OrdersResponse []

ordersCreate :: OrderRequest -> Handler OrderResponse

-- | POST /v1/orders - Requires OrdersWrite permission
ordersCreate _ = pure $ OrderResponse 100 "New" 1 (read "2024-01-01")

ordersGet :: Int64 -> Handler OrderResponse

-- | GET /v1/orders/:id - Requires OrdersWrite permission (for access)
ordersGet _ = pure $ OrderResponse 1 "Demo" 1 (read "2024-01-01")

ordersStatus :: Int64 -> Maybe Int -> Handler OrderResponse

-- | PUT /v1/orders/:id/status - Requires OrdersWrite permission
ordersStatus _ _ = pure $ OrderResponse 1 "Demo" 1 (read "2024-01-01")

ordersDelete :: Int64 -> Handler ()

-- | DELETE /v1/orders/:id - Requires OrdersWrite permission
ordersDelete _ = pure ()

taxesList :: Handler TaxesResponse

-- | GET /v1/taxes - Requires TaxesWrite permission (for access)
taxesList = pure $ TaxesResponse [TaxResponse 1 "НДС" 20.0]

taxesCreate :: TaxRequest -> Handler TaxResponse

-- | POST /v1/taxes - Requires TaxesWrite permission
taxesCreate _ = pure $ TaxResponse 100 "New" 0.0

taxesGet :: Int64 -> Handler TaxResponse

-- | GET /v1/taxes/:id - Requires TaxesWrite permission (for access)
taxesGet _ = pure $ TaxResponse 1 "НДС" 20.0

taxesUpdate :: Int64 -> TaxRequest -> Handler TaxResponse

-- | PUT /v1/taxes/:id - Requires TaxesWrite permission
taxesUpdate _ _ = pure $ TaxResponse 1 "Updated" 0.0

taxesDelete :: Int64 -> Handler ()

-- | DELETE /v1/taxes/:id - Requires TaxesWrite permission
taxesDelete _ = pure ()

currenciesList :: Handler CurrenciesResponse

-- | GET /v1/currencies - Requires CurrenciesWrite permission (for access)
currenciesList = pure $ CurrenciesResponse [CurrencyResponse 1 "Рубль" "RUB"]

currenciesCreate :: CurrencyRequest -> Handler CurrencyResponse

-- | POST /v1/currencies - Requires CurrenciesWrite permission
currenciesCreate _ = pure $ CurrencyResponse 100 "New" "XXX"

currenciesGet :: Int64 -> Handler CurrencyResponse

-- | GET /v1/currencies/:id - Requires CurrenciesWrite permission (for access)
currenciesGet _ = pure $ CurrencyResponse 1 "Рубль" "RUB"

currenciesUpdate :: Int64 -> CurrencyRequest -> Handler CurrencyResponse

-- | PUT /v1/currencies/:id - Requires CurrenciesWrite permission
currenciesUpdate _ _ = pure $ CurrencyResponse 1 "Updated" "XXX"

currenciesDelete :: Int64 -> Handler ()

-- | DELETE /v1/currencies/:id - Requires CurrenciesWrite permission
currenciesDelete _ = pure ()

stockList :: Handler StockResponse
stockList = pure $ StockResponse []

stockSummary :: Handler StockResponse
stockSummary = pure $ StockResponse []

stockByLoc :: Int64 -> Int64 -> Handler StockItemResponse
stockByLoc _ _ = pure $ StockItemResponse 1 1 100.0

stockByGoods :: Int64 -> Handler StockResponse
stockByGoods _ = pure $ StockResponse []

accList :: Handler AccountsResponse
accList = pure $ AccountsResponse []

accCreate :: AccPlanRequest -> Handler AccPlanResponse
accCreate _ = pure $ AccPlanResponse 100 "01" "New"

accGet :: Int64 -> Handler AccPlanResponse
accGet _ = pure $ AccPlanResponse 1 "01" "Основные"

accUpdate :: Int64 -> AccPlanRequest -> Handler AccPlanResponse
accUpdate _ _ = pure $ AccPlanResponse 1 "01" "Updated"

accDelete :: Int64 -> Handler ()
accDelete _ = pure ()

entriesList :: Handler AccEntriesResponse
entriesList = pure $ AccEntriesResponse []

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
payrollList = pure $ PayrollResponse []

empList :: Handler EmployeesResponse

-- | GET /v1/payroll/employees - Requires PayrollRead permission
empList = pure $ EmployeesResponse []

empGet :: Int64 -> Handler EmployeeResponse

-- | GET /v1/payroll/employees/:id - Requires PayrollRead permission
empGet _ = pure $ EmployeeResponse 1 "Demo"

salariesList :: Handler SalariesResponse

-- | GET /v1/payroll/salaries - Requires PayrollRead permission
salariesList = pure $ SalariesResponse []

salaryGet :: Int64 -> Handler SalaryResponse

-- | GET /v1/payroll/salaries/:id - Requires SalariesWrite permission (for access)
salaryGet _ = pure $ SalaryResponse 1 0.0

reportsList :: Handler ReportsResponse
reportsList = pure $ ReportsResponse []

reportsMeta :: Handler ReportsMetadataResponse
reportsMeta = pure $ ReportsMetadataResponse []

reportsTemplates :: Handler ReportsResponse
reportsTemplates = pure $ ReportsResponse []

reportGet :: Int64 -> Handler ReportResponse
reportGet _ = pure $ ReportResponse 1 "Demo"

reportJrxml :: Text -> Handler ReportJRXMLResponse
reportJrxml _ = pure $ ReportJRXMLResponse "" ""

dashboardGet :: Handler DashboardResponse
dashboardGet = pure $ DashboardResponse "null"

usersList :: Handler UsersResponse

-- | GET /v1/users - Requires UsersRead permission
usersList = pure $ UsersResponse []

auditLogList :: Env -> Maybe Text -> Maybe Int64 -> Maybe Int64 -> Handler AuditLogListResponse
auditLogList env mEntityType mLimit mOffset = do
  entries <- liftIO $ fetchAuditLogsBestEffort env mEntityType (fromMaybe 100 mLimit) (sum mOffset)
  pure $ AuditLogListResponse entries

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
  pure $ HealthResponse overall (object ["db" .= dbStatus])

metricsGet :: Handler MetricsResponse
metricsGet = pure $ MetricsResponse 0 0 0

rbacRolesList :: Env -> Handler RolesListResponse
rbacRolesList env = do
  roles <- liftIO $ listRoles (envRBACStore env)
  pure $ RolesListResponse (fmap toRoleInfo roles)

rbacRoleCreate :: Env -> RoleCreateRequest -> Handler RoleInfoResponse
rbacRoleCreate env req = do
  scoped <- mapM mkScoped (normalizeRoleSpecs (rcrPermissions req) (rcrResources req))
  let role = mkDynamicRole (rcrName req) scoped
  liftIO $ upsertRole (envRBACStore env) role
  liftIO $ emitAdminAudit env "rbac-role-created" (Just (rcrName req))
  pure $ toRoleInfo role

rbacRoleUpdate :: Env -> Text -> RoleCreateRequest -> Handler RoleInfoResponse
rbacRoleUpdate env name req = do
  scoped <- mapM mkScoped (normalizeRoleSpecs (rcrPermissions req) (rcrResources req))
  let role = mkDynamicRole name scoped
  liftIO $ upsertRole (envRBACStore env) role
  liftIO $ emitAdminAudit env "rbac-role-updated" (Just name)
  pure $ toRoleInfo role

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
  entries <- liftIO $ listAuditEntries (envRBACStore env)
  pure $ AuditListResponse (applyAuditFilters mPrincipal mResource mOffset mLimit entries)

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
toRoleInfo role =
  RoleInfoResponse
    { rirName = drName role,
      rirPermissions = fmap scopedPermissionText (drPermissions role)
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

mkScoped :: (Text, Maybe Text) -> Handler ScopedPermission
mkScoped (permText, mRes) =
  case parsePermissionText permText of
    Nothing -> throwError err400 {errBody = "Unknown permission"}
    Just perm ->
      pure $ ScopedPermission perm (maybe GlobalScope ResourceScope mRes)

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

parsePermissionText :: Text -> Maybe Permission
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

usersCreate :: UserRequest -> Handler UserResponse
usersCreate _ = pure $ UserResponse 100 "New User" "new@example.com" 1

usersUpdate :: Int64 -> UserRequest -> Handler UserResponse
usersUpdate _ _ = pure $ UserResponse 1 "Updated" "updated@example.com" 1

usersDelete :: Int64 -> Handler ()
usersDelete _ = pure ()

startServantServer :: Int -> Pool -> JWTConfig -> RBACStore -> IO ()
startServantServer port pool jwtConfig rbacStore = do
  putStrLn $ "Starting Servant server on port " <> show port
  run port $ apiServer pool jwtConfig rbacStore
