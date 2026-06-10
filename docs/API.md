# API-спецификация

> REST API Surypus. Все эндпоинты под префиксом `/api/v1/`. Формат — JSON. Аутентификация — JWT Bearer token.

**Base URL:** `https://<host>:443/api/v1`

**Response-формат (единый):**

```json
── Успех
{
  "data": { ... },
  "status": "ok"
}

── Ошибка
{
  "status": "error",
  "message": "Описание ошибки",
  "code": "VALIDATION_ERROR"
}
```

**Пагинация:**

```json
{
  "data": [ ... ],
  "pagination": {
    "page": 1,
    "perPage": 50,
    "total": 234,
    "totalPages": 5
  }
}
```

**Common HTTP status codes:**
- `200` — OK
- `201` — Created
- `400` — Bad Request (Validation Error)
- `401` — Unauthorized
- `403` — Forbidden
- `404` — Not Found
- `409` — Conflict
- `500` — Internal Server Error

---

## 1. Аутентификация

### `POST /api/v1/login`

Вход в систему.

```json
── Request
{ "username": "admin", "password": "..." }

── Response 200
{
  "token": "eyJhbGciOiJSUzI1...",
  "user": { "id": 1, "username": "admin", "tenantId": 1 }
}
```

### `POST /api/v1/register`

Регистрация нового пользователя.

```json
── Request
{ "username": "newuser", "password": "...", "email": "user@example.com" }

── Response 201
{ "id": 2, "username": "newuser", "tenantId": 1 }
```

### `GET /api/v1/auth/me`

Текущий пользователь (по JWT).

```json
── Response 200
{ "id": 1, "username": "admin", "email": "admin@example.com", "tenantId": 1 }
```

---

## 2. Dashboard

### `GET /api/v1/dashboard`

Сводка по системе.

### `GET /api/v1/dashboard/revenue`

Выручка (по периодам).

### `GET /api/v1/dashboard/orders`

Статусы заказов.

### `GET /api/v1/dashboard/stock`

Остатки (общие метрики).

---

## 3. Bills (Счета)

### `GET /api/v1/bills`

Список счетов. Параметры: `?page=1&perPage=50&type=sales&status=posted`.

```json
── Response
{
  "data": [
    {
      "id": 123,
      "code": "INV-2024-001",
      "billType": "PPOPT_SALES",
      "docStatus": "POSTED",
      "docDate": "2024-03-15",
      "personId": 42,
      "locationId": 1,
      "total": 15000.00,
      "taxAmount": 2500.00
    }
  ]
}
```

### `POST /api/v1/bills`

Создание счёта.

```json
── Request
{
  "billType": "PPOPT_SALES",
  "docDate": "2024-03-15",
  "personId": 42,
  "locationId": 1,
  "lines": [
    { "goodsId": 7, "qtty": 10, "price": 1500.00 }
  ]
}
```

### `GET /api/v1/bills/:id`

Детали счёта (с позициями).

### `POST /api/v1/bills/:id/post`

Проведение счёта (списание товаров по FIFO + бухгалтерские проводки).

---

## 4. Goods (Товары)

### `GET /api/v1/goods`

Список товаров. Параметры: `?categoryId=5&search=название`.

```json
── Response
{
  "data": [
    {
      "id": 7,
      "code": "001",
      "name": "Молоко",
      "unitId": 1,
      "categoryId": 5,
      "price": 1500.00
    }
  ]
}
```

---

## 5. Stock (Склад)

### `GET /api/v1/stock`

Остатки на складах.

```json
── Response
{
  "data": [
    {
      "goodsId": 7,
      "locationId": 1,
      "qtty": 150.0,
      "resrvQtty": 10.0
    }
  ]
}
```

---

## 6. Lots (Партии / FIFO-учёт)

### `GET /api/v1/lots`

Все партии. Параметры: `?goodsId=7&locationId=1`.

### `GET /api/v1/lots/:id`

Партия по ID.

### `GET /api/v1/lots/goods/:goodsId`

Партии конкретного товара.

### `GET /api/v1/lots/location/:locationId`

Партии на конкретном складе.

```json
── Response
{
  "data": [
    {
      "id": 1,
      "goodsId": 7,
      "locationId": 1,
      "billId": 123,
      "dt": "2024-01-10",
      "expDt": "2024-06-10",
      "rest": 50.0,
      "cost": 1200.00,
      "price": 1500.00,
      "serial": "SN-001"
    }
  ]
}
```

---

## 7. Locations (Склады)

### `GET /api/v1/locations`

Список складов/локаций.

```json
── Response
{
  "data": [
    { "id": 1, "code": "MAIN", "name": "Основной склад", "locationType": "warehouse" }
  ]
}
```

---

## 8. Persons (Контрагенты)

### `GET /api/v1/persons`

Список контрагентов. Параметры: `?type=customer&search=ООО`.

```json
── Response
{
  "data": [
    {
      "id": 42,
      "code": "C-001",
      "name": "ООО Ромашка",
      "inn": "7701234567",
      "kpp": "770101001",
      "personType": "legal",
      "status": "active"
    }
  ]
}
```

---

## 9. Payments (Платежи)

### `GET /api/v1/payments`

Список платежей. Параметры: `?billId=123&status=paid`.

---

## 10. Tenants (Мультиарендность)

### `GET /api/v1/tenants`

Список организаций (тенантов).

```json
── Response
{
  "data": [
    { "id": 1, "name": "ООО Ромашка", "slug": "romashka" }
  ]
}
```

### `GET /api/v1/tenants/:id`

Организация по ID.

### `POST /api/v1/tenants`

Создание организации.

```json
── Request
{ "name": "ООО Новая", "slug": "novaya" }
```

---

## 11. Accounting (Бухгалтерия)

### `GET /api/v1/balance`

Оборотно-сальдовая ведомость.

### `GET /api/v1/accounting/entries`

Журнал проводок. Параметры: `?dateFrom=2024-01-01&dateTo=2024-12-31&accountId=90`.

```json
── Response
{
  "data": [
    {
      "id": 1,
      "docId": 123,
      "debit": 90,
      "credit": 41,
      "amount": 15000.00,
      "date": "2024-03-15",
      "descr": "Списание себестоимости"
    }
  ]
}
```

### `POST /api/v1/accounting/entries`

Создание проводки (прямой ввод).

---

## 12. Payroll (Зарплата)

### `GET /api/v1/payroll/employees`

Список сотрудников.

### `GET /api/v1/payroll/employees/:id`

Сотрудник по ID.

### `GET /api/v1/payroll/salaries`

Все начисления.

### `GET /api/v1/payroll/salaries/:empId`

Начисления конкретного сотрудника.

```json
── Response
{
  "data": [
    {
      "employeeId": 1,
      "period": "2024-03",
      "amount": 100000.00,
      "status": "paid"
    }
  ]
}
```

---

## 13. Reports (Отчёты)

### `GET /api/v1/reports/pnl`

Отчёт о прибылях и убытках. Параметры: `?dateFrom=2024-01-01&dateTo=2024-12-31&format=pdf`.

### `GET /api/v1/reports/inventory`

Инвентаризационная ведомость. Параметры: `?locationId=1&format=pdf`.

### `POST /api/v1/reports/export`

Экспорт данных (JSON, CSV).

### `GET /api/v1/reports/download/:filename`

Скачивание сгенерированного PDF-файла.

---

## 14. CRM

### `GET /api/v1/crm/deals`

Список сделок. Параметры: `?stage=negotiation&pipelineId=1`.

### `POST /api/v1/crm/deals`

Создание сделки.

### `GET /api/v1/crm/contacts`

Контакты. Параметры: `?search=Иван`.

### `GET /api/v1/crm/companies`

Компании. Параметры: `?search=ООО`.

### `GET /api/v1/crm/pipeline/forecast`

Прогноз по воронке продаж.

---

## 15. Classifiers (Классификаторы)

16 классификаторов: `oksm`, `okv`, `okei`, `okpd2`, `okved2`, `tnved`, `okato`, `oktmo`, `okof`, `okp`, `okdp`, `okso`, `okun`, `okud`, `okfs`, `oknpo`.

### `GET /api/v1/classifiers/:type`

Данные классификатора. Параметры: `?search=код&page=1`.

```json
── Response
{
  "data": [
    { "code": "64.1", "name": "Денежное посредничество" }
  ]
}
```

---

## 16. Workflows (Бизнес-процессы)

### `GET /api/v1/workflows`

Список шаблонов процессов.

### `POST /api/v1/workflows/:id/instances`

Создание экземпляра процесса.

### `POST /api/v1/workflows/instances/:id/complete`

Завершение шага процесса.

---

## 17. Infrastructure

### `GET /api/v1/health`

Проверка состояния сервера.

```json
── Response 200
{ "status": "ok", "timestamp": "2024-03-15T10:00:00Z" }
```

### `GET /api/v1/health/db`

Проверка соединения с БД.

### `GET /api/v1/metrics`

Метрики Prometheus/ekg.

---

## 18. GraphQL

### `POST /api/v1/graphql`

GraphQL-эндпоинт.

```json
── Request
{ "query": "{ bills { id code total } }" }
```

---

## 19. Модули (детальная спецификация)

### 19.1. Модуль Bills (Счета)

```json
── BillType
PPOPT_GOODSRECEIPT  ── Приход товара (поступление)
PPOPT_SALES         ── Продажа (расход)
PPOPT_TRANSFER      ── Перемещение между складами
PPOPT_INVENTORY     ── Инвентаризация
PPOPT_ORDER         ── Заказ покупателя/поставщику

── DocStatus
DRAFT     ── Черновик (можно редактировать)
POSTED    ── Проведён (изменения заблокированы)
CANCELLED ── Аннулирован
```

**Бизнес-логика проведения:**
1. Валидация остатков (для расхода)
2. Списание/оприходование по FIFO
3. Генерация бухгалтерских проводок
4. Обновление остатков
5. Фиксация в EventStore

### 19.2. Модуль Accounting (Бухгалтерия)

**Проводки — основа двойной записи:**

```json
{
  "date": "2024-03-15",
  "debit": 90,       ── Счёт 90 "Продажи"
  "credit": 41,      ── Счёт 41 "Товары"
  "amount": 15000.00,
  "description": "Списание себестоимости товара"
}
```

**Инвариант:** сумма дебетов == сумме кредитов для каждого документа.

### 19.3. Модуль Inventory (Склад)

**FIFO-учёт через партии (Lots):**

```
Приход: товар Х, 100 ед. по 10 руб. (партия №1, 01.01)
Приход: товар Х, 100 ед. по 12 руб. (партия №2, 15.01)

Расход: 80 ед. → 80 ед. из партии №1 по 10 руб. (себестоимость = 800 руб.)
Расход: 40 ед. → 20 ед. из партии №1 + 20 из партии №2 (себестоимость = 440 руб.)
```

### 19.4. Модуль Tax (Налоги)

**Ставки:**
- НДС 20% (стандартная)
- НДС 10% (льготная: продукты, детские товары)
- НДС 0% (экспорт)
- Без НДС

**Расчёт:** `VAT = amount * rate / 100`, где `rate ∈ [0, 100]`.

### 19.5. MultiTenancy (Мультиарендность)

- Каждый Tenant — юридическое лицо (ООО, ИП)
- Пользователи привязаны к Tenant через `userTenantId`
- JWT содержит `tenant_id` в claims
- Данные изолированы на уровне запросов (WHERE tenant_id = ?)
- Веб-клиент поддерживает переключение между тенантами

---

## 20. WebSocket

```
── Подключение
wss://<host>/api/v1/ws?token=<jwt>

── Сообщения
{ "event": "stock_updated",  "data": { "goodsId": 7, "qtty": 150 } }
{ "event": "bill_posted",    "data": { "id": 123, "status": "POSTED" } }
{ "event": "dashboard_update", "data": { ... } }
```

---

## 21. Связанные документы

- `docs/engineering/api-conventions.md` — Соглашения по именованию, ошибки, пагинация
- `API_DOCUMENTATION.md` (корень) — Базовая API-документация (286 строк)
- `RBAC.md` (корень) — Маппинг эндпоинтов на права доступа
- `docs/examples/EXAMPLES.md` — Примеры cURL-запросов
