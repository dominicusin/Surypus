{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE TypeOperators #-}

module API.Types
  ( module API.Types
  ) where

import Data.Aeson (FromJSON, ToJSON)
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (Day, UTCTime)
import GHC.Generics (Generic)
import qualified Servant.API as Servant

data PersonAPI

data PersonInput = PersonInput
  { piName :: Text,
    piINN :: Maybe Text,
    piKPP :: Maybe Text,
    piPersonType :: Int,
    piStatus :: Int
  }
  deriving (Show, Eq, Generic)

instance FromJSON PersonInput

instance ToJSON PersonInput

data PersonResponse = PersonResponse
  { prId :: Int,
    prName :: Text,
    prINN :: Maybe Text,
    prKPP :: Maybe Text,
    prPersonType :: Int,
    prStatus :: Int
  }
  deriving (Show, Eq, Generic)

instance FromJSON PersonResponse

instance ToJSON PersonResponse

data PaginationParams = PaginationParams
  { ppLimit :: Int,
    ppOffset :: Int
  }
  deriving (Show, Eq, Generic)

instance FromJSON PaginationParams

instance ToJSON PaginationParams

data PageResponse a = PageResponse
  { pageItems :: [a],
    pageTotal :: Int,
    pageLimit :: Int,
    pageOffset :: Int
  }
  deriving (Show, Eq, Generic)

instance (ToJSON a) => ToJSON (PageResponse a)

instance (FromJSON a) => FromJSON (PageResponse a)

data ErrorResponse = ErrorResponse
  { errCode :: Int,
    errMessage :: Text,
    errDetails :: Maybe Text
  }
  deriving (Show, Eq, Generic)

instance ToJSON ErrorResponse

mkErrorResponse :: Int -> Text -> ErrorResponse
mkErrorResponse code msg = ErrorResponse code msg Nothing

mkErrorResponseWithDetails :: Int -> Text -> Text -> ErrorResponse
mkErrorResponseWithDetails code msg details = ErrorResponse code msg (Just details)

err400 :: Text -> ErrorResponse
err400 = mkErrorResponse 400

err404 :: Text -> ErrorResponse
err404 = mkErrorResponse 404

err409 :: Text -> ErrorResponse
err409 = mkErrorResponse 409

mkErrorResponseWithDetails' = mkErrorResponseWithDetails

data LoginRequest = LoginRequest
  { lrUsername :: Text,
    lrPassword :: Text
  }
  deriving (Show, Eq, Generic)

instance FromJSON LoginRequest

data LoginResponse = LoginResponse
  { lAccessToken :: Text,
    lRefreshToken :: Text,
    lExpiresAt :: UTCTime,
    lUserId :: Int,
    lUsername :: Text,
    lRole :: Text
  }
  deriving (Show, Eq, Generic)

instance ToJSON LoginResponse

newtype RefreshRequest = RefreshRequest
  { rrRefreshToken :: Text
  }
  deriving (Show, Eq, Generic)

instance FromJSON RefreshRequest

data RefreshResponse = RefreshResponse
  { rfAccessToken :: Text,
    rfExpiresAt :: UTCTime
  }
  deriving (Show, Eq, Generic)

instance ToJSON RefreshResponse

type PersonsAPI =
  "persons" Servant.:> Servant.Get '[Servant.JSON] (PageResponse PersonResponse)
    Servant.:<|> "persons" Servant.:> Servant.ReqBody '[Servant.JSON] PersonInput Servant.:> Servant.Post '[Servant.JSON] PersonResponse
    Servant.:<|> "persons" Servant.:> Servant.Capture "id" Int Servant.:> Servant.Get '[Servant.JSON] PersonResponse
    Servant.:<|> "persons" Servant.:> Servant.Capture "id" Int Servant.:> Servant.ReqBody '[Servant.JSON] PersonInput Servant.:> Servant.Put '[Servant.JSON] PersonResponse
    Servant.:<|> "persons" Servant.:> Servant.Capture "id" Int Servant.:> Servant.Delete '[Servant.JSON] ()
    Servant.:<|> "persons" Servant.:> "search" Servant.:> Servant.QueryParam "q" Text Servant.:> Servant.Get '[Servant.JSON] (PageResponse PersonResponse)

type AuthAPI =
  "auth" Servant.:> "login" Servant.:> Servant.ReqBody '[Servant.JSON] LoginRequest Servant.:> Servant.Post '[Servant.JSON] LoginResponse
    Servant.:<|> "auth" Servant.:> "refresh" Servant.:> Servant.ReqBody '[Servant.JSON] RefreshRequest Servant.:> Servant.Post '[Servant.JSON] RefreshResponse
    Servant.:<|> "auth" Servant.:> "logout" Servant.:> Servant.Header "Authorization" Text Servant.:> Servant.Post '[Servant.JSON] ()

type HealthAPI =
  "health" Servant.:> Servant.Get '[Servant.JSON] (Either ErrorResponse Text)
    Servant.:<|> "health" Servant.:> "db" Servant.:> Servant.Get '[Servant.JSON] (Either ErrorResponse Text)

type APIv1 =
  "api" Servant.:> "v1" Servant.:> (AuthAPI Servant.:<|> PersonsAPI Servant.:<|> HealthAPI)

type API =
  APIv1
    Servant.:<|> "swagger.json" Servant.:> Servant.Get '[Servant.JSON] Text

-- | Dashboard statistics from DB
data DashboardStats = DashboardStats
  { dsBills :: Int,
    dsOrders :: Int,
    dsGoods :: Int,
    dsPersons :: Int
  }
  deriving (Show, Eq, Generic)

instance ToJSON DashboardStats
instance FromJSON DashboardStats

-- | Dashboard response
data DashboardResponse = DashboardResponse
  { drStats :: Text
  }
  deriving (Show, Eq, Generic)

instance ToJSON DashboardResponse

-- | Order response for API
data OrderResponse = OrderResponse
  { orderId :: Int64,
    orderName :: Text,
    orderStatus :: Int16,
    orderDate :: Day
  }
  deriving (Show, Eq, Generic)

instance ToJSON OrderResponse
instance FromJSON OrderResponse

data OrdersResponse = OrdersResponse [OrderResponse]
  deriving (Show, Eq, Generic)

instance ToJSON OrdersResponse
instance FromJSON OrdersResponse

-- | Payroll types
data SalaryResponse = SalaryResponse
  { srId :: Int64,
    srEmployeeId :: Int64,
    srPeriod :: Text,
    srBaseSalary :: Double,
    srBonus :: Double,
    srPenalty :: Double,
    srTax :: Double,
    srNetSalary :: Double
  }
  deriving (Show, Eq, Generic)

instance ToJSON SalaryResponse
instance FromJSON SalaryResponse

data SalariesResponse = SalariesResponse [SalaryResponse]
  deriving (Show, Eq, Generic)

instance ToJSON SalariesResponse
instance FromJSON SalariesResponse

data PayrollResponse = PayrollResponse [SalaryResponse]
  deriving (Show, Eq, Generic)

instance ToJSON PayrollResponse
instance FromJSON PayrollResponse

data EmployeeResponse = EmployeeResponse
  { erId :: Int64,
    erName :: Text
  }
  deriving (Show, Eq, Generic)

instance ToJSON EmployeeResponse
instance FromJSON EmployeeResponse

data EmployeesResponse = EmployeesResponse [EmployeeResponse]
  deriving (Show, Eq, Generic)

instance ToJSON EmployeesResponse
instance FromJSON EmployeesResponse
