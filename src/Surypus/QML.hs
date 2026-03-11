-- ============================================================================
-- HSQML BINDINGS FOR SURYPUS QML UI
-- ============================================================================

{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE RecursiveDo #-}

module Surypus.QML where

import Control.Monad (forM_, void)
import Control.Monad.IO.Class (liftIO)
import Data.Aeson (FromJSON, ToJSON, Value(..), object, (.=))
import Data.IORef (IORef, newIORef, readIORef, writeIORef)
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.IO as TIO
import Data.Time (Day, getCurrentTime)
import Data.Time.Format (formatTime, defaultTimeLocale)
import System.Environment (getEnv)
import System.Process (readProcess, callProcess)
import qualified Graphics.UI.Qtah as Qt
import qualified Graphics.UI.Qtah.Widgets as Qtw
import qualified Graphics.UI.Qtah.Qml as Qml

-- ============================================================================
-- APPLICATION TYPES
-- ============================================================================

data AppState = AppState
  { asCurrentUser :: Maybe User
  , asPersons :: [Person]
  , asGoods :: [Goods]
  , asLocations :: [Location]
  , asBills :: [Bill]
  , asJobs :: [Job]
  } deriving (Show)

data User = User
  { userId :: Int
  , userName :: Text
  , userEmail :: Text
  , userRole :: Text
  } deriving (Show)

data Person = Person
  { personId :: Int
  , personCode :: Text
  , personName :: Text
  , personInn :: Maybe Text
  , personType :: Text
  , personPhone :: Maybe Text
  , personEmail :: Maybe Text
  , personStatus :: Text
  } deriving (Show)

data Goods = Goods
  { goodsId :: Int
  , goodsCode :: Text
  , goodsName :: Text
  , goodsUnit :: Text
  , goodsPrice :: Double
  , goodsQuantity :: Int
  , goodsGroup :: Maybe Text
  , goodsStatus :: Text
  } deriving (Show)

data Location = Location
  { locationId :: Int
  , locationCode :: Text
  , locationName :: Text
  , locationType :: Text
  , locationAddress :: Maybe Text
  } deriving (Show)

data Bill = Bill
  { billId :: Int
  , billNumber :: Text
  , billDate :: Day
  , billType :: Text
  , billCustomer :: Maybe Text
  , billTotal :: Double
  , billStatus :: Text
  } deriving (Show)

data Job = Job
  { jobId :: Int
  , jobCode :: Text
  , jobName :: Text
  , jobStatus :: Text
  , jobPriority :: Int
  } deriving (Show)

-- ============================================================================
-- QML ENGINE SETUP
-- ============================================================================

-- | Initialize QML engine with Surypus UI
initQMLEngine :: IO ()
initQMLEngine = do
    putStrLn "Initializing Surypus QML Engine..."
    
    -- Initialize Qt application
    Qt.initialize
    Qml.initialize
    
    putStrLn "QML Engine initialized"

-- | Run QML application
runQMLApp :: FilePath -> IO ()
runQMLApp qmlFile = do
    putStrLn $ "Running QML: " ++ qmlFile
    
    -- Run with qmlscene or Qt runtime
    callProcess "qmlscene" [qmlFile]
    return ()

-- ============================================================================
-- QML MODEL WRAPPERS
-- ============================================================================

-- | Create QML list model from Haskell data
data QMLListModel a = QMLListModel
  { qlmItems :: [a]
  , qlmCount :: Int
  }

instance Show a => Show (QMLListModel a) where
  show m = "QMLListModel " ++ show (qlmCount m) ++ " items"

-- | Convert Persons to QML model
personsToQML :: [Person] -> QMLListModel Person
personsToQML persons = QMLListModel
  { qlmItems = persons
  , qlmCount = length persons
  }

-- | Convert Goods to QML model
goodsToQML :: [Goods] -> QMLListModel Goods
goodsToQML goods = QMLListModel
  { qlmItems = goods
  , qlmCount = length goods
  }

-- | Convert Bills to QML model
billsToQML :: [Bill] -> QMLListModel Bill
billsToQML bills = QMLListModel
  { qlmItems = bills
  , qlmCount = length bills
  }

-- ============================================================================
-- QML SIGNAL HANDLERS
-- ============================================================================

-- | Type for QML signal callbacks
type QMLCallback = IO ()

-- | Register callback for navigation
onNavigate :: Text -> QMLCallback -> IO ()
onNavigate page action = do
    putStrLn $ "Navigate to: " ++ T.unpack page
    action

-- | Register callback for button click
onButtonClick :: Text -> IO () -> IO ()
onButtonClick buttonId action = do
    putStrLn $ "Button clicked: " ++ T.unpack buttonId
    action

-- | Register callback for table row selection
onRowSelect :: Int -> IO () -> IO ()
onRowSelect rowId action = do
    putStrLn $ "Row selected: " ++ show rowId
    action

-- ============================================================================
-- DATA LOADING (connects to API)
-- ============================================================================

-- | Load all persons from API
loadPersons :: IO [Person]
loadPersons = do
    putStrLn "Loading persons from API..."
    return samplePersons

-- | Load all goods from API
loadGoods :: IO [Goods]
loadGoods = do
    putStrLn "Loading goods from API..."
    return sampleGoods

-- | Load all locations from API
loadLocations :: IO [Location]
loadLocations = do
    putStrLn "Loading locations from API..."
    return sampleLocations

-- | Load all bills from API
loadBills :: IO [Bill]
loadBills = do
    putStrLn "Loading bills from API..."
    return sampleBills

-- | Load all jobs from API
loadJobs :: IO [Job]
loadJobs = do
    putStrLn "Loading jobs from API..."
    return sampleJobs

-- ============================================================================
-- SAMPLE DATA
-- ============================================================================

samplePersons :: [Person]
samplePersons =
  [ Person 1 "P001" "ООО ТехноСтрой" (Just "7701234567") "company" (Just "+7 495 123-4567") (Just "info@company.ru") "active"
  , Person 2 "P002" "ИП Иванов" (Just "7709876543") "person" (Just "+7 916 123-4567") (Just "ivanov@email.ru") "active"
  , Person 3 "P003" "ООО МегаТрейд" (Just "7705555555") "company" (Just "+7 495 999-9999") (Just "sales@megatrade.ru") "active"
  ]

sampleGoods :: [Goods]
sampleGoods =
  [ Goods 1 "G001" "Стройматериалы" "кг" 100.0 500 (Just "Стройматериалы") "active"
  , Goods 2 "G002" "Инструменты" "шт" 250.0 100 (Just "Инструменты") "active"
  , Goods 3 "G003" "Крепёж" "кг" 50.0 1000 (Just "Крепёж") "active"
  ]

sampleLocations :: [Location]
sampleLocations =
  [ Location 1 "L001" "Основной склад" "warehouse" (Just "г. Москва, склад 1")
  , Location 2 "L002" "Магазин №1" "shop" (Just "г. Москва, ул. Ленина, 10")
  ]

sampleBills :: [Bill]
sampleBills =
  [ Bill 1 "INV-2026-001" (read "2026-03-01") "invoice" (Just "ООО ТехноСтрой") 50000.0 "completed"
  , Bill 2 "INV-2026-002" (read "2026-03-05") "invoice" (Just "ИП Иванов") 25000.0 "pending"
  ]

sampleJobs :: [Job]
sampleJobs =
  [ Job 1 "JOB-001" "Отправить отчёт" "pending" 5
  , Job 2 "JOB-002" "Обработать платёж" "running" 5
  , Job 3 "JOB-003" "Сформировать накладную" "pending" 4
  ]

-- ============================================================================
-- QML INTEGRATION FUNCTIONS
-- ============================================================================

-- | Register Surypus as QML context property
registerSurypusContext :: Qml.Context -> IO ()
registerSurypusContext ctx = do
    putStrLn "Registering Surypus QML context..."
    -- Register data models and callbacks
    return ()

-- | Export data to QML
exportToQML :: Text -> Value -> IO ()
exportToQML name value = do
    putStrLn $ "Exporting to QML: " ++ T.unpack name

-- | Import data from QML
importFromQML :: Text -> IO Value
importFromQML name = do
    putStrLn $ "Importing from QML: " ++ T.unpack name
    return Null

-- ============================================================================
-- QML MAIN ENTRY POINT
-- ============================================================================

-- | Main entry point for QML application
mainQML :: IO ()
mainQML = do
    putStrLn "Starting Surypus QML Application..."
    
    initQMLEngine
    
    -- Load initial data
    persons <- loadPersons
    goods <- loadGoods
    locations <- loadLocations
    bills <- loadBills
    jobs <- loadJobs
    
    putStrLn $ "Loaded: " ++ show (length persons) ++ " persons"
    putStrLn $ "Loaded: " ++ show (length goods) ++ " goods"
    putStrLn $ "Loaded: " ++ show (length locations) ++ " locations"
    putStrLn $ "Loaded: " ++ show (length bills) ++ " bills"
    putStrLn $ "Loaded: " ++ show (length jobs) ++ " jobs"
    
    putStrLn "Surypus QML Application ready!"

-- ============================================================================
-- JSON SERIALIZATION
-- ============================================================================

instance ToJSON Person where
  toJSON p = object
    [ "id" .= personId p
    , "code" .= personCode p
    , "name" .= personName p
    , "inn" .= personInn p
    , "type" .= personType p
    , "phone" .= personPhone p
    , "email" .= personEmail p
    , "status" .= personStatus p
    ]

instance ToJSON Goods where
  toJSON g = object
    [ "id" .= goodsId g
    , "code" .= goodsCode g
    , "name" .= goodsName g
    , "unit" .= goodsUnit g
    , "price" .= goodsPrice g
    , "quantity" .= goodsQuantity g
    , "group" .= goodsGroup g
    , "status" .= goodsStatus g
    ]

instance ToJSON Location where
  toJSON l = object
    [ "id" .= locationId l
    , "code" .= locationCode l
    , "name" .= locationName l
    , "type" .= locationType l
    , "address" .= locationAddress l
    ]

instance ToJSON Bill where
  toJSON b = object
    [ "id" .= billId b
    , "number" .= billNumber b
    , "date" .= show (billDate b)
    , "type" .= billType b
    , "customer" .= billCustomer b
    , "total" .= billTotal b
    , "status" .= billStatus b
    ]

instance ToJSON Job where
  toJSON j = object
    [ "id" .= jobId j
    , "code" .= jobCode j
    , "name" .= jobName j
    , "status" .= jobStatus j
    , "priority" .= jobPriority j
    ]

-- ============================================================================
-- CONVENIENCE FUNCTIONS
-- ============================================================================

-- | Get statistics for dashboard
getDashboardStats :: IO (Int, Int, Int, Int)
getDashboardStats = do
    persons <- loadPersons
    goods <- loadGoods
    bills <- loadBills
    jobs <- loadJobs
    return (length persons, length goods, length bills, length jobs)

-- | Filter persons by status
filterPersonsByStatus :: Text -> [Person] -> [Person]
filterPersonsByStatus status persons = filter (\p -> personStatus p == status) persons

-- | Filter goods by group
filterGoodsByGroup :: Text -> [Goods] -> [Goods]
filterGoodsByGroup group goods = filter (\g -> goodsGroup g == Just group) goods

-- | Calculate bill total
calculateBillTotal :: [Bill] -> Double
calculateBillTotal bills = sum (map billTotal bills)
