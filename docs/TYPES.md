# Система типов и Haskell-специфика

> Раздел описывает ключевые типы предметной области, управление эффектами (монады), конкурентность и паттерны, специфичные для Haskell в контексте ERP-системы.

---

## 1. Карта типов предметной области

### Финансовые типы

```haskell
── Точные десятичные дроби (избегаем Double для денег!)
newtype Money = Money { unMoney :: Decimal }
  deriving (Eq, Num, Ord)

── Налоговая ставка (проценты: 0..100)
data TaxRate = TaxRate
  { trId    :: Int64
  , trName  :: Text          ── "НДС 20%"
  , trRate  :: Double        ── 20.0
  , trFlags :: Int           ── битовые флаги
  } deriving (Show, Eq)

── Счёт (накладная, заказ)
data BillType
  = PPOPT_GOODSRECEIPT       ── Приход товара
  | PPOPT_SALES              ── Продажа
  | PPOPT_TRANSFER           ── Перемещение
  deriving (Eq, Show)

data DocStatus
  = DRAFT                    ── Черновик
  | POSTED                   ── Проведён
  | CANCELLED                ── Аннулирован
  deriving (Eq, Show)

── Проводка (бухгалтерская запись)
data LedgerEntry = LedgerEntry
  { leId       :: Int64
  , leDocId    :: Int64      ── ссылка на документ-основание
  , leDebit    :: Int64      ── счёт дебета
  , leCredit   :: Int64      ── счёт кредита
  , leAmount   :: Money      ── сумма
  , leDate     :: DocDate    ── дата
  , leDescr    :: Text       ── описание
  }

── Партия товара (FIFO)
data Lot = Lot
  { lotId       :: Int64
  , lotGoodsId  :: GoodsID
  , lotLocationId :: LocationID
  , lotBillId   :: BillID
  , lotDt       :: DocDate
  , lotExpDt    :: Maybe DocDate   ── срок годности
  , lotRest     :: Double          ── остаток (>= 0)
  , lotCost     :: Money           ── себестоимость единицы
  , lotPrice    :: Money           ── цена продажи
  , lotSerial   :: Maybe Text      ── серийный номер
  , lotFlags    :: Int
  }
```

### Инварианты, гарантируемые типами

```haskell
── 1. Остаток партии неотрицателен (CHECK + тип)
──    Свойство: Lot.rest >= 0 всегда

── 2. Сумма проводок сбалансирована
──    forall e :: LedgerEntry . sum(debit) == sum(credit)

── 3. Налог не превышает сумму
──    calcVAT amount rate: 0 <= результат <= amount

── 4. Цена неотрицательна
──    Money: только неотрицательные Decimal
```

### Типы для API (DTO)

```haskell
── Входные данные (FromJSON)
data BillInput = BillInput
  { biBillType   :: BillType
  , biDocDate    :: DocDate
  , biPersonId   :: Int64
  , biLocationId :: Int64
  , biLines      :: [BillLineInput]
  }

── Выходные данные (ToJSON)
data Bill = Bill
  { bId           :: Int64
  , bCode         :: Text
  , bBillType     :: BillType
  , bDocStatus    :: DocStatus
  , bDocDate      :: DocDate
  , bTotal        :: Money
  , bDiscountAmount :: Money
  , bTaxAmount    :: Money
  }
```

### LiquidHaskell-рефайнменты (формальная верификация)

```haskell
{-@ type NonNeg = {v:Double | v >= 0} @-}
{-@ type Percent = {v:Double | 0 <= v && v <= 100} @-}
{-@ type Positive = {v:Double | v > 0} @-}

{-@ calcVAT :: Double -> Percent -> NonNeg @-}
calcVAT :: Double -> Double -> Double
calcVAT amount rate = amount * (rate / 100.0)

── Доказанное свойство: результат всегда неотрицателен
── и не превышает исходной суммы (при rate ∈ [0,100])
```

---

## 2. Управление эффектами (монады)

### Основной стек эффектов

```haskell
── Базовый тип для всех операций с БД
type DB a = ReaderT DbContext IO a
──   где DbContext содержит пул соединений, конфиг, метрики

── API-хендлеры (с аутентификацией)
type AuthHandler a = ReaderT AuthContext Handler a
──   где AuthContext содержит пользователя, tenant, права

── Пример: сервис создания счёта
createBill :: AuthContext -> BillInput -> DB (Either ServiceError Bill)
createBill ctx input = do
  ── 1. Валидация (чистая функция)
  case validateBillInput input of
    Left err  -> return $ Left $ ValidationError err
    Right b   -> do
      ── 2. Проверка прав (эффект чтения контекста)
      unless (hasPermission ctx "bill:create") $
        return $ Left Forbidden
      ── 3. Транзакция БД (эффект БД)
      result <- DAL.Bill.create b
      └── права доступа
  ── 4. Постобработка
      return $ case result of
        Left e  -> Left $ DBError e
        Right x -> Right x
```

### Типы ошибок

```haskell
data ServiceError
  = ValidationError Text    ── Ошибка валидации
  | NotFound Text           ── Не найдено
  | Forbidden               ── Нет прав
  | Conflict Text           ── Конфликт (дубликат)
  | DBError DBError         ── Ошибка БД
  | InternalError Text      ── Внутренняя ошибка
```

### Чистые vs эффектные функции

```haskell
── Чистые функции (без IO): в Core/
validateTaxRate :: TaxRate -> Either String TaxRate
calcVAT :: Double -> Double -> Double
fifoCost :: [Lot] -> Double -> (Double, [Lot])

── Эффектные функции (с IO): в Service/
createBill :: AuthContext -> BillInput -> IO (Either ServiceError Bill)
postBill :: AuthContext -> BillID -> IO (Either ServiceError ())
generateReport :: ReportParams -> IO (Either ServiceError FilePath)
```

---

## 3. Конкурентность и параллелизм

### STM (Software Transactional Memory)

```haskell
── Атомарное обновление остатков склада
adjustStock :: GoodsID -> LocationID -> Double -> STM ()
adjustStock gid lid delta = do
  current <- readTVar (stockMap TVar)
  let key = (gid, lid)
      newQtty = M.lookup key current + delta
  when (newQtty < 0) $ retry  ── блокировка, если остаток < 0
  writeTVar (stockMap TVar) $ M.insert key newQtty current

── Использование в IO:
atomically $ adjustStock 42 1 (-5.0)
```

### Async (для параллельных операций)

```haskell
── Параллельная генерация нескольких отчётов
generateReports :: [ReportParams] -> IO [Either ServiceError FilePath]
generateReports params = do
  results <- mapConcurrently generateReport params
  return results

── Тайм-аут для долгих операций
withTimeout :: Int -> IO a -> IO (Maybe a)
withTimeout us action = do
  result <- race (threadDelay us) action
  return $ case result of
    Left _      -> Nothing      ── тайм-аут
    Right val   -> Just val     ── успех
```

### Пул соединений (Database)

```haskell
── Пул PostgreSQL-соединений (Data.Pool)
createPostgresPool :: PGConfig -> IO (Pool Connection)
── max 10 соединений, idle 30 секунд

── Использование в ReaderT
withPool :: Pool Connection -> ReaderT DbContext IO a -> IO a
```

### IORef для кэша в памяти

```haskell
── Кэш сгенерированных PDF-файлов (in-memory)
reportCache :: IORef (Map Text FilePath)
reportCache = unsafePerformIO $ newIORef M.empty

── Атомарное обновление
atomicModifyIORef' reportCache $ M.insert uuid filepath
```

---

## 4. Ключевые библиотеки и их роль

| Библиотека | Роль | Модуль |
|-----------|------|--------|
| **persistent** | ORM-генерация схемы и типов | `DAL.Schema`, `DAL.Queries` |
| **esqueleto** | Типобезопасные JOIN-запросы | `DAL.QueriesORM` |
| **aeson** | JSON-сериализация API | `DAL.Types` (FromJSON/ToJSON) |
| **servant** | Типизированные REST-эндпоинты | `Surypus.API.Server` |
| **warp** | HTTP-сервер | `Surypus.App.Main` |
| **jose** | JWT-токены | `Surypus.JWT` |
| **cryptonite** | Хеширование паролей | `Surypus.API.Auth` |
| **stm** | Software Transactional Memory | `Infrastructure.*` |
| **async** | Параллельные операции | `Surypus.*` |
| **ekg** | Метрики приложения | `Surypus.Metrics` |
| **hedis** | Redis-клиент | `Infrastructure.Redis` |
| **websockets** | WebSocket-поддержка | `Surypus.WebSocket` |
| **Decimal** | Точные финансовые расчёты | `Core.Finance` |
| **QuickCheck** | Property-based testing | `test/` |
| **hspec** | Unit-тесты | `test/` |
| **liquidhaskell** | Формальная верификация | Core-модули |

---

## 5. Модульная структура (ключевые слои)

```
── Доменный слой (чистая бизнес-логика, без IO)
Core/
├── Tax.hs          ── расчёты налогов
├── Goods.hs        ── товары, категории, единицы
├── Accounting.hs   ── план счетов, проводки
├── Inventory.hs    ── FIFO, остатки
├── Person.hs       ── контрагенты
├── Document.hs     ── документы, регистры
└── Services/
    └── Accounting.hs  ── сервисный слой

── Слой данных (IO + Database)
DAL/
├── Schema.hs       ── Persistent-сущности (43 шт.)
├── Types.hs        ── Domain-типы + JSON
├── Conversion.hs   ── Entity → Domain
├── QueriesORM.hs   ── Esqueleto-запросы
├── EventStore.hs   ── Event Sourcing storage
├── Procedures.hs   ── Хранимые процедуры
└── Mutations.hs    ── RAW SQL мутации

── API-слой (HTTP + Auth)
Surypus.API/
├── Server.hs       ── Определение всех маршрутов
├── Auth.hs         ── Логин/регистрация
├── Bills.hs        ── Счета
├── Accounting.hs   ── Бухгалтерия
├── Payroll.hs      ── Зарплата
├── Reports.hs      ── Отчёты (PDF)
└── ... (26 хендлеров)
```

---

## 6. Паттерны и идиомы

### Pattern 1: Entity → Domain Type → JSON

```haskell
── 1. Persistent генерирует Entity (с префиксом)
──    BillEntity { billId, billCode, ... }

── 2. Domain-тип в DAL/Types.hs
data Bill = Bill { bId :: Int64, bCode :: Text, ... }

── 3. Конверсия в DAL/Conversion.hs
billFromEntity :: BillEntity -> Bill
billFromEntity be = Bill
  { bId   = billId be
  , bCode = billCode be
  , ...
  }

── 4. JSON-сериализация в DAL/Types.hs
instance ToJSON Bill where
  toJSON Bill{..} = object
    [ "id"   .= bId
    , "code" .= bCode
    ]
```

### Pattern 2: Service-функция (оркестрация)

```haskell
createBill :: AuthContext -> BillInput -> IO (Either ServiceError Bill)
createBill ctx input =
  runReaderT (createBillDB ctx input) =<< ask
  where
    createBillDB ctx input = do
      validate
      checkPermission
      result <- DAL.Bill.create
      postprocess result
```

### Pattern 3: Resource-паттерн (bracket)

```haskell
── Безопасная работа с ресурсами
withDbPool :: PGConfig -> (Pool Connection -> IO a) -> IO a
withDbPool config = bracket
  (createPool config)     ── acquire
  destroyPool             ── release
```

### Pattern 4: Event-события (Event Sourcing)

```haskell
data InventoryEvent
  = GoodsReceived { goodsId, locationId, qtty, cost }
  | GoodsShipped  { goodsId, locationId, qtty, cost }
  | LotCreated    { lot }
  deriving (Generic, ToJSON, FromJSON)

── Аппенд-только лог
appendEvent :: EventStore -> InventoryEvent -> IO ()
readEvents :: EventStore -> AggregateID -> IO [InventoryEvent]
```

### Pattern 5: НOM-паттерн (ReaderT design pattern)

```haskell
── Вместо передачи параметров через аргументы,
── используем ReaderT для конфигурации и контекста

data Env = Env
  { envPool      :: Pool Connection
  , envConfig    :: Config
  , envMetrics   :: MetricsStore
  }

type App = ReaderT Env IO

── Все функции в ReaderT имеют доступ к Env
getBill :: BillID -> App (Maybe Bill)
getBill bid = do
  pool <- asks envPool
  liftIO $ runQuery pool $ selectBill bid
```
