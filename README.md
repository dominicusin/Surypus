# Surypus ERP/CRM

**Система управления предприятием нового поколения на Haskell с формальной верификацией**

## Возможности

- **Backend**: Haskell (GHC 9.6.6)
- **База данных**: PostgreSQL (30+ таблиц)
- **API**: REST (Scotty, порт 8080)
- **UI**: QML Desktop + Web (Desktop + Mobile/PWA)
- **Отчёты**: PDF-Slave шаблоны (9 типов)
- **Тесты**: Hspec (32+ тестов)
- **CI/CD**: GitHub Actions

## Быстрый старт

### Сборка

```bash
cd Surypus
stack build
```

### Запуск тестов

```bash
stack test
```

### Запуск API сервера

```bash
stack exec surypus
```

Сервер запустится на http://localhost:8080

### Запуск Web UI

Откройте `web/index.html` в браузере

## Структура проекта

```
Surypus/
├── src/
│   ├── Core/              # Бизнес-логика
│   ├── DB/                # Слой БД (Hasql)
│   ├── Domain/            # Доменные модели
│   ├── APIServer.hs       # REST API
│   └── Surypus/           # Ядро системы
├── qml/                   # QML Desktop UI
├── web/                   # Web UI
│   ├── index.html        # Desktop
│   └── mobile.html       # Mobile/PWA
├── config/                # SQL схемы
├── templates/reports/     # PDF-Slave шаблоны
└── test/                  # Тесты
```

## API Endpoints

### Аутентификация

- `POST /api/v1/auth/login` - Вход
- `POST /api/v1/auth/logout` - Выход
- `GET /api/v1/auth/me` - Текущий пользователь

### Контрагенты

- `GET /api/v1/persons` - Список
- `GET /api/v1/persons/:id` - По ID
- `POST /api/v1/persons` - Создать
- `PUT /api/v1/persons/:id` - Обновить
- `DELETE /api/v1/persons/:id` - Удалить

### Товары

- `GET /api/v1/goods` - Список
- `GET /api/v1/goods/:id` - По ID
- `POST /api/v1/goods` - Создать

### Документы

- `GET /api/v1/bills` - Список
- `GET /api/v1/bills/:id` - По ID
- `POST /api/v1/bills` - Создать

### Склады

- `GET /api/v1/locations` - Список
- `POST /api/v1/locations` - Создать

### Бухгалтерия

- `GET /api/v1/accounting/accounts` - План счетов
- `GET /api/v1/accounting/entries` - Проводки

### Зарплата

- `GET /api/v1/payroll/employees` - Сотрудники
- `GET /api/v1/payroll/salary/:id/:period` - Расчёт

### Задачи

- `GET /api/v1/jobs` - Список
- `GET /api/v1/jobs/pending` - Ожидающие

### Отчёты

- `GET /api/v1/reports` - Список
- `GET /api/v1/reports/templates` - Шаблоны
- `POST /api/v1/reports` - Создать

## Схема БД

Основные таблицы:

- `companies` - Организации
- `persons` - Контрагенты
- `goods` - Товары и услуги
- `locations` - Склады
- `stock` - Остатки
- `bills` - Документы
- `bill_items` - Строки документов
- `accounts` - План счетов
- `accounting_entries` - Проводки
- `employees` - Сотрудники
- `payroll` - Зарплата
- `jobs` - Задачи

## Тесты

```bash
stack test
```

Текущий статус: **32 теста проходят**

## Docker

```bash
docker build -t surypus:latest .
docker run -p 8080:8080 surypus:latest
```

## Лицензия

GPL-3

## Авторы

Surypus Team