# Surypus 

**ERP/CRM система нового поколения на Haskell с формальной верификацией**

Современная замена  с использованием:
- **Haskell** - безопасный и производительный backend
- **LiquidHaskell** - формальная верификация критических алгоритмов
- **PostgreSQL** - надёжная база данных с хранимыми процедурами
- **Qt/Web** - кроссплатформенный UI
- **JasperReports/Pentaho** - BI аналитика (внешний REST API)
- **pdf-slave** - генерация PDF документов (накладные, счета, акты)

## Формальная верификация

Система включает математически доказанные компоненты:

### Математические теоремы

1. **Расчёт НДС** (Core/Tax/VAT.hs):
   - Теорема: `VAT = PriceWithVAT * Rate / (1 + Rate)`
   - Доказательство: для любой ставки r > 0 и цены p >= 0
   - Инвариант: результат >= 0 и <= p

2. **Правило двойной записи** (Core/Accounting/Account.hs):
   - Теорема: `Σ Debet = Σ Credit` для всех проводок
   - Инвариант сальдо: активные счета имеют дебетовое сальдо

3. **Расчёт остатков** (Core/Inventory/Stock.hs):
   - Теорема: `Остаток = НачОстаток + Приход - Расход`
   - Инварианты FIFO/LIFO корректности

### Параметризация

Модуль учёта параметризован налоговой схемой:
```haskell
class TaxScheme ts where
  calculateTax :: Decimal -> ts -> TaxGroup -> Decimal
  defaultVatRate :: ts -> VatRate
  
-- Российская схема (ОСНО)
instance TaxScheme RussianTaxScheme

-- Упрощённая система (УСН)  
instance TaxScheme USNTaxScheme

-- Единый налог на вменённый доход (ЕНВД)
instance TaxScheme ENVDTaxScheme
```

### Хранимые процедуры PostgreSQL

Все критические расчёты вынесены в SQL:
- `calc_vat()` - расчёт НДС
- `calc_line_vat()` - НДС по строке документа
- `calc_bill_totals()` - итоги документа
- `get_lot_bounds()` - остатки партии
- `calc_vat_book()` - книги покупок/продаж

## Архитектура

```
┌─────────────────────────────────────────────────────────────┐
│                     Frontend (Qt/Web)                        │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                   REST API (Scotty)                          │
│  • /api/v1/goods   • /api/v1/persons                        │
│  • /api/v1/bills   • /api/v1/locations                      │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                  Domain Layer (Haskell)                      │
│  • Domain.Goods    • Domain.Person                          │
│  • Domain.Bill     • Domain.Location                        │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│              Data Access Layer (PostgreSQL)                  │
│  • DB.Connection   • DB.Repositories                        │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    PostgreSQL Database                       │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│              Reports (Jasper/Pentaho/Helical)                │
└─────────────────────────────────────────────────────────────┘
```

## Быстрый старт

### Требования

- GHC 9.4+
- PostgreSQL 14+
- Cabal или Stack

### Установка

```bash
# Клонировать репозиторий
cd surypus

# Установить зависимости
cabal update
cabal build

# Или через Stack
stack build
```

### Настройка базы данных

```bash
# Создать базу данных
psql -U postgres -c "CREATE DATABASE surypus;"

# Выполнить миграцию
psql -U postgres -d surypus -f config/database.sql
```

### Запуск

```bash
# Через переменные окружения
export SURYPUS_PG_HOST=localhost
export SURYPUS_PG_PORT=5432
export SURYPUS_PG_USER=postgres
export SURYPUS_PG_PASSWORD=yourpassword
export SURYPUS_PG_DATABASE=surypus
export SURYPUS_JWT_SECRET=change-me
export SURYPUS_PORT=3000

# Запуск сервера
cabal run surypus-api
```

API будет доступно по адресу: `http://localhost:3000`

## API Endpoints

### Товары (Goods)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/goods` | Список товаров |
| GET | `/api/v1/goods/:id` | Получить товар |
| GET | `/api/v1/goods/barcode/:code` | Поиск по штрихкоду |
| POST | `/api/v1/goods` | Создать товар |
| PUT | `/api/v1/goods/:id` | Обновить товар |
| DELETE | `/api/v1/goods/:id` | Удалить товар |

### Контрагенты (Persons)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/persons` | Список контрагентов |
| GET | `/api/v1/persons/:id` | Получить контрагента |
| POST | `/api/v1/persons` | Создать контрагента |
| PUT | `/api/v1/persons/:id` | Обновить контрагента |
| DELETE | `/api/v1/persons/:id` | Удалить контрагента |

### Документы (Bills)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/bills` | Список документов |
| GET | `/api/v1/bills/:id` | Получить документ |
| POST | `/api/v1/bills` | Создать документ |
| PUT | `/api/v1/bills/:id` | Обновить документ |
| DELETE | `/api/v1/bills/:id` | Удалить документ |

### HR / Payroll

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/hr/salaries` | Список записей начислений (фильтр по сотруднику, начислению и периоду) |
| POST | `/api/v1/hr/salaries` | Создать запись зарплаты |
| GET | `/api/v1/hr/payrolls/summary` | Итоги фонда зарплаты за период |

### Склады (Locations)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/locations` | Список складов |
| GET | `/api/v1/locations/:id` | Получить склад |
| POST | `/api/v1/locations` | Создать склад |
| PUT | `/api/v1/locations/:id` | Обновить склад |
| DELETE | `/api/v1/locations/:id` | Удалить склад |

## Примеры использования

### Создание товара

```bash
curl -X POST http://localhost:3000/api/v1/goods \
  -H "Content-Type: application/json" \
  -d '{
    "goodsId": 0,
    "goodsName": {"unName256": "Тестовый товар"},
    "goodsParentID": null,
    "goodsKind": "GdskGoods",
    "goodsFlags": {"unGoodsFlags": 0},
    "goodsBrandID": null,
    "goodsManufID": null,
    "goodsTaxGrpID": null,
    "goodsUnitID": null,
    "goodsPhUnitID": null,
    "goodsStrucID": null,
    "goodsGdsClsID": null,
    "goodsGoodsTypeID": null,
    "goodsCode": null,
    "goodsPhCode": null,
    "goodsBarcode": "1234567890123"
  }'
```

### Получение товара по штрихкоду

```bash
curl http://localhost:3000/api/v1/goods/barcode/1234567890123
```

## Отчётность

Система использует двухуронневую архитектуру отчётности:

### Аналитика (BI)
- **JasperReports Server** - для сложных аналитических отчётов
- **Pentaho BI Server** - альтернатива
- Взаимодействие через REST API

### Генерация PDF документов
- **pdf-slave** - Haskell-утилита для генерации PDF из LaTeX шаблонов
- Идеально для: накладных, счетов, актов, прайс-листов
- Шаблоны описываются в YAML с управлением зависимостями

### Пример генерации отчёта

```haskell
import Reports

-- Конфигурация BI сервера
let biConfig = defaultBIConfig

-- Конфигурация pdf-slave
pdfConfig <- defaultPDFSlaveConfig

-- Генерация накладной
result <- generateInvoice invoiceData pdfConfig
case result of
    Left err -> putStrLn $ "Ошибка: " <> err
    Right path -> putStrLn $ "Сохранено в: " <> path

-- Генерация аналитического отчёта через BI
biResult <- runBIClient biConfig $ runBIReport "/reports/sales" FormatPDF []
```

## Разработка

### Структура проекта

```
src/
├── Domain/           # Доменные модели и бизнес-логика
│   ├── Types.hs      # Базовые типы
│   ├── Services.hs   # Мощные Haskell абстракции
│   ├── Analytics/    # Аналитика (ABC, прогнозы)
│   ├── EDI/          # EDI/ЕГАИС
│   ├── Production/   # MRP и производство
│   └── HR/           # Управление персоналом
├── DB/
│   ├── Connection.hs # Подключение к PostgreSQL
│   ├── Repositories/ # Репозитории с Esqueleto
│   └── Procedures/   # Интерфейс к хранимым процедурам
├── API/
│   ├── Server.hs     # REST API сервер
│   └── Server/       # Расширенный API (WebSocket)
├── Reports.hs        # BI интеграция + PDF генерация
└── Main.hs           # Точка входа
```

### Запуск тестов

```bash
cabal test
```

## Архитектура с хранимыми процедурами

Вся бизнес-логика реализована в виде PostgreSQL хранимых процедур:

### Финансы (`DB/Procedures/Finance.sql`)
- Валюты и курсы
- Планы счетов
- Проводки (дебет/кредит)
- Платежи
- Денежный поток

### Склад (`DB/Procedures/Inventory.sql`)
- Остатки (stock)
- Партии (lots)
- Движения товаров
- Перемещения
- Инвентаризация

### Документы (`DB/Procedures/Bills.sql`)
- Создание/обновление документов
- Строки документов
- Статусы и связи
- Обработка (движения, проводки)

### Оборудование (`DB/Procedures/Devices.sql`)
- Кассовые смены
- Чеки
- Фискальные операции
- Весы, сканеры, терминалы

### Налоги (`DB/Procedures/Tax.sql`)
- Налоговые группы
- Ставки НДС
- Счета-фактуры
- Книга покупок/продаж
- Расчёт НДС к уплате
- Акцизы

### Безопасность (`DB/Procedures/Security.sql`)
- Аутентификация пользователей
- Управление сессиями
- Права доступа
- Объектные права
- Группы пользователей
- Аудит действий
- Политика паролей

### EDI/ЕГАИС (`DB/Procedures/EDI.sql`)
- EDI-партнёры
- Сообщения EDI
- Операции ЕГАИС
- Марки алкоголя
- Накладные ЕГАИС
- Инвентаризация ЕГАИС
- Запросы и остатки

## Веб-интерфейс

Веб-интерфейс построен на:
- Bootstrap 5.3
- Axios для API
- Чистый JavaScript (без фреймворков)

Файлы веб-интерфейса:
- `web/index.html` - главная страница
- `web/css/style.css` - стили
- `web/js/api.js` - API клиент
- `web/js/app.js` - приложение



| Компонент |  | Surypus |
|-----------|-------------|---------|
| База данных | Btrieve | PostgreSQL |
| UI | C++/Qt | Qt/Web |
| Язык | C++ | Haskell |
| Отчёты | Crystal Reports | BI (Jasper/Pentaho) + PDF |
| Бизнес-логика | C++ | PostgreSQL PL/pgSQL |
| API | нет | REST |

### Карта соответствия таблиц

|  | Surypus |
|-------------|---------|
| Goods2Tbl | goods |
| PersonTbl | person |
| BillTbl | bill |
| LocationTbl | location |
| BarcodeTbl | barcode |
| RegisterTbl | register |
| ELinksTbl | elink |

## Qt Desktop GUI

Приложение включает настольный Qt-интерфейс с богатым функционалом.

### Запуск GUI

```bash
# Запуск Qt GUI приложения
cabal run surypus-gui
```

или через переменные окружения:

```bash
export SURYPUS_PG_HOST=localhost
export SURYPUS_PG_PORT=5433
export SURYPUS_PG_USER=postgres
export SURYPUS_PG_PASSWORD=yourpassword
export SURYPUS_PG_DATABASE=surypus

cabal run surypus-gui
```

### Возможности Qt GUI

- **Главное окно** с навигацией по разделам
- **Меню** (Файл, Правка, Документы, Справочники, Отчёты, Настройки)
- **Панель инструментов** с быстрыми действиями
- **Навигационное дерево** слева
- **Статус бар** с информацией о подключении
- **Диалоговые окна** для товаров, контрагентов, документов
- **Тёмная/светлая тема**
- **Многоязычность** (русский, английский)

### Структура GUI модулей

```
src/GUI/
├── Application.hs   # Приложение, конфигурация
├── MainWindow.hs    # Главное окно
├── Models.hs        # Модели данных для представлений
├── Dialogs.hs       # Диалоговые окна
├── Widgets.hs       # Настраиваемые виджеты
├── Styles.hs        # Стили и темы
├── QML.hs           # Интеграция с QML
└── Main.hs          # Точка входа

qml/
└── Main.qml         # QML интерфейс
```

### QML Интерфейс

Проект также поддерживает QML для современного UI:

- Навигация сбоку
- Карточки статистики (продажи, остатки)
- Таблицы с сортировкой
- Поиск и фильтры

## Лицензия

GPL-3

## Авторы

Сообщество Surypus
